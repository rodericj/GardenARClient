//
//  ARViewContainer.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 8/8/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import ARKit
import Combine
import RealityKit

final class ARViewContainer: NSObject, UIViewRepresentable {
    let store: Store<ViewModel>
    let sceneDelegate: ARSessionDelegate
    var sceneObserver: Cancellable!
    var anchorStateChangeObserver: Cancellable!
    let arView = ARView(frame: .zero)
    private var disposables = Set<AnyCancellable>()

    init(sceneDelegate: ARSessionDelegate, store: Store<ViewModel>) {
        self.sceneDelegate = sceneDelegate
        self.store = store
        self.store.value.arView = arView
    }

    func makeUIView(context: Context) -> ARView {
        #if !targetEnvironment(simulator)
        arView.session.delegate = self
        tapGestureSetup()
        setupObservers(arView: arView)
        #endif
        arView.addCoaching()
        return arView
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        print("We've been asked to dismantle our arView")
    }
    // MARK: - Gesture recognizer callbacks
    func updateUIView(_ uiView: ARView, context: Context) {}

    func setupObservers(arView: ARView) {

        // When an anchor is added, we need to trigger the lookAtCamera notification which is set to repeat
        arView.scene.publisher(for: SceneEvents.AnchoredStateChanged.self)
            .subscribe(on: RunLoop.main)
            .filter { $0.isAnchored }
            .filter { $0.anchor.name == Scene.AnchorCollection.signAnchorNameIdentifier }
            .map { $0.anchor }
            .sink { plantSignAnchorWrapper in
                print("Anchor State Changed to isAnchored true. This means we have a new anchor")
                // TODO ok unrelated actually I think when we re-load a new arView we need to move this thing over perhaps

                // Get the previously loaded scene. This contains the notifications and the original entity which we've cloned
                guard let scene = self.store.value.loadedPlantSignScene else {
                    print("we must not have a scene yet")
                    return
                }

                guard let originalSignEntity = scene.plantSignEntityToAttach else {
                    print("This is the origina entity. use this as the key for the overrides")
                    return
                }
                let notifications = scene.notifications
                let overrides = [originalSignEntity.name: plantSignAnchorWrapper]
                notifications.lookAtCamera.post(overrides: overrides)
        }.store(in: &disposables)
    }

    fileprivate func addNewAnchor(_ sender: UITapGestureRecognizer) {
           // Get the user's tap screen location.
           guard let arView = store.value.arView else {
               return
           }
           let touchLocation = sender.location(in: arView)

           // do nothing if we are in the adding sign state
           guard !store.value.isAddingSign else {
               addSign(at: touchLocation, on: arView)
               return
           }

          checkForCollisions(at: touchLocation, on: arView)
       }

    func tapGestureSetup() {
           let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedOnARView))
           assert(store.value.arView != nil)
           store.value.arView?.addGestureRecognizer(tapGesture)
       }

       /// Tap gesture input handler.
       /// - Tag: TapHandler
       @objc
       func tappedOnARView(_ sender: UITapGestureRecognizer) {
           addNewAnchor(sender)
       }

       private func addSign(at touchLocation: CGPoint, on arView: ARView) {
           // Cast a ray to check for its intersection with any planes.
           #if !targetEnvironment(simulator)

           let raycastResultsArray = arView.raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .any)
           guard let raycastResult = raycastResultsArray.first else {
               // TODO messageLabel.displayMessage("No surface detected, try getting closer.", duration: 2.0)
               print("No surface detected, try getting closer.")
               return
           }
           store.value.showingAlert = .createMarker("Name this plant", arView, raycastResult)
           #endif
       }

       private func checkForCollisions(at touchLocation: CGPoint, on arView: ARView) {
           let hits = arView.hitTest(touchLocation)
           hits.map { $0.entity.findRoot() }
               .map { $0.findEntity(named: "PlantSignEntityToAttach") }
               .compactMap { $0 }
               .forEach { entity in
                   print("we have tapped on \(entity.anchor?.anchorIdentifier)")
                   store.value.isShowingPlantInfo = true
                   store.value.isShowingModalInfoCollectionFlow = true
           }
       }
}

extension ARViewContainer: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchors
            .filter { $0.name?.hasPrefix("RemoteUUID-") ?? false }
            .forEach { newlyAddedARKitAnchor in
                guard let remoteID = newlyAddedARKitAnchor.name?.components(separatedBy: "RemoteUUID-").last,
                    let remoteUUID = UUID(uuidString: remoteID) else {
                        fatalError("We've already verified that the name has the RemoteUUID- prefix. This should be impossible")
                }
                // Check if there are any pending anchor entity's in the lookup.
                print("thisAnchor \(newlyAddedARKitAnchor)")
                guard let anchorEntityContainingSignEntityAndStringTuple = store.value.pendingAnchorEntityLookup[newlyAddedARKitAnchor] else {
                    addAnchorFromARAnchor(arAnchor: newlyAddedARKitAnchor, with: remoteUUID)
                    return
                }
                let anchorEntity = anchorEntityContainingSignEntityAndStringTuple.anchorEntity
                let plantName = anchorEntityContainingSignEntityAndStringTuple.plantName
                sendAnchorToServer(arAnchor: newlyAddedARKitAnchor, with: remoteUUID, anchorEntity: anchorEntity, plantName: plantName)
        }
    }

     private func sendAnchorToServer(arAnchor: ARAnchor, with remoteUUID: UUID, anchorEntity: AnchorEntity, plantName: String) {

            // 8. Need to get the world map then verify that this new thing is on there.
            // 8a. At this point we actually need to wait until we get a signal that the anchors have changed. To the delegate!
            #if !targetEnvironment(simulator)
            store.value.arView?.session.getCurrentWorldMap { (map, getWorldMapError) in

                if let error = getWorldMapError {
                    // TODO we need to inform the user that they need to capture more of the world. In an optimal scenario we would know ahead of time if we have enough of the world to do this. Perhaps we check before they attempt their first one.
                    print("🔴 Error fetching the world map. \(error)")
                    return
                }
                guard let map = map else {
                    print("🔴 Couldn't fetch the world map, but no error.")
                    return
                }

                do {
                    try self.processFetchedWorldMap(map: map, plantName: plantName, anchorUUID: remoteUUID, anchorEntityContainingSignEntity: anchorEntity)
                } catch {
                    print("Unable to process the FetchedWorldMap \(error)")
                }

            }
            #endif
        }
        private func addAnchorFromARAnchor(arAnchor: ARAnchor, with remoteUUID: UUID) {
            // At this point we know that we have an ARAnchor object with no ARView (RealityKit) Anchor. This means that we
            // are getting this from the network and we need to render it in RealityKit.
            guard let originalSignEntityScene = store.value.loadedPlantSignScene else {
                print("no plant sign scene has been loaded")
                return
            }
            guard let plantSignEntityToAttach = originalSignEntityScene.plantSignEntityToAttach?.clone(recursive: true) else {
                print("No plantSignScene was loaded")
                return
            }

            // Look up the entity in the view model
            let selectedSpaceInfo = store.value.selectedSpace
            guard case let SelectedSpaceInfoIsSet.space(selectedSpace) = selectedSpaceInfo else {
                print("There is no selected space")
                return
            }
            guard let selectedSpaceAnchor = selectedSpace.anchors?.first(where: { $0.id == remoteUUID }) else {
                print("There was no anchor with this remoteUUID: \(remoteUUID) in our anchors array. We may need to consider some cleanup here. What it means is that the world that we had saved before had an anchor that never made it to the server.")
                return
            }

            plantSignEntityToAttach.name = selectedSpaceAnchor.title
            plantSignEntityToAttach.updatePlantSignName(name: selectedSpaceAnchor.title)

            // 4. Add the newly loaded plantSign to the anchor
            #if !targetEnvironment(simulator)

            let anchorEntity = AnchorEntity(anchor: arAnchor)
            anchorEntity.name = Scene.AnchorCollection.signAnchorNameIdentifier
            anchorEntity.addChild(plantSignEntityToAttach)
            //                // 5. add an occlusion plane to the anchor for when the sign is down below
            //                anchorEntity.addOcclusionBox()

            // 6. Set the sign text
            //plantSignScene.plantSignAnchor?.updatePlantSignName(name: plantName ?? "Name should have come in on the anchor")
            print("// 7. From didAdd in the Delegate: add the anchor to the arView.")
            self.store.value.arView?.scene.anchors.append(anchorEntity)

            let notifications = originalSignEntityScene.notifications
            let overrides = [originalSignEntityScene.name: plantSignEntityToAttach]
    //        notifications.lookAtCamera.post(overrides: overrides)

            #endif
        }

        /**
         *  Save the map to a data representation, send it to the view model
         * - Parameter map: The world map which should be sent to the server
         * - Parameter plantName: The name of the anchor we're sending to the view model
         * - Parameter anchorEntity: In the case of an error we will need to remove this anchor
         */
        private func processFetchedWorldMap(map: ARWorldMap, plantName: String, anchorUUID: UUID, anchorEntityContainingSignEntity: AnchorEntity) throws {
            if let worldData = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
                do {
                    try self.addAnchor(anchorName: plantName, anchorID: anchorUUID, worldData: worldData)
                } catch {
                    self.store.value.arView?.scene.removeAnchor(anchorEntityContainingSignEntity)
                    print("Unable to add anchor to the server \(error)")
                }
            } else {
                self.store.value.arView?.scene.removeAnchor(anchorEntityContainingSignEntity)
                print("no map data")
            }
            // If we have an error we need to remove the anchor
            // TODO we may want to handle the error case outside of this method. There are other scenarios where we may want to remove the anchor
        }

        private func addAnchor(anchorName: String, anchorID: UUID, worldData: Data) throws {
            guard case let SelectedSpaceInfoIsSet.space(currentSelectedSpace) = store.value.selectedSpace else {
                throw ViewModelError.noSpaceSelected
            }
            print("ViewModel:AddAnchor We have a space selected, so send the anchor \(anchorID) \(anchorName) to the network client")
            var cancellable: AnyCancellable?
            cancellable = try store.update(space: currentSelectedSpace,
                                           anchorID: anchorID,
                                           anchorName: anchorName,
                                           worldMapData: worldData).sink(receiveCompletion: { error in

                                           }, receiveValue: { anchor in
                                            print("ViewModel:AddAnchor just saved this anchor \(anchor) with id: \(anchor.id?.uuidString ?? "No ID set for this anchor")")
                                            guard case var SelectedSpaceInfoIsSet.space(currentSelectedSpace) = self.store.value.selectedSpace else {
                                                print("we have no selected space")
                                                return
                                            }
                                            currentSelectedSpace.anchors?.append(anchor)
                                            cancellable?.cancel()
                                           })
        }
}
