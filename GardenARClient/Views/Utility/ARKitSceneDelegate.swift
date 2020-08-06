//
//  ARKitSceneDelegate.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/16/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
import ARKit
import RealityKit
import SwiftUI
import Combine

enum AnchorError: Error {
    case noUniqueIdentifier(String)
}

extension Scene.AnchorCollection {
    static let signAnchorNameIdentifier = "AnchorEntity For A Plant Sign"
}

class ARDelegate: NSObject, ARSessionDelegate, HasOptionalARView, ARSCNViewDelegate {
    func updateWithEntity(entity: HasAnchoring) {
        store.value.arView?.scene.addAnchor(entity)
    }

    var visibleSigns = Set<Entity>()
    var hiddenSigns = Set<Entity>()
    static let unnamedAnchorName = "NewUnnamedAnchor"
    let store: Store<ViewModel>
    private var disposables = Set<AnyCancellable>()

    let networkClient: NetworkClient
    init(store: Store<ViewModel>, networkClient: NetworkClient) {
        self.store = store
        self.networkClient = networkClient

    }

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


        arView.scene.publisher(for: SceneEvents.Update.self)
            .throttle(for: .seconds(3), scheduler: RunLoop.main, latest: true)
            .subscribe(on: RunLoop.main).sink { update in
                print("\nupdate after a throttle \(update.deltaTime)")
                guard let scene = self.store.value.loadedPlantSignScene else {
                    print("we must not have a scene yet")
                    return
                }

                // TODO get PlantSignExtraTop, PlantSignExtraMiddle, PlantSignExtraBottom
                guard let originalSignEntity = scene.plantSignEntityToAttach else {
                    print("This is the origina entity. use this as the key for the overrides")
                    return
                }
                let notifications = scene.notifications
                update
                    .scene
                    .anchors
                    .filter { $0.name == Scene.AnchorCollection.signAnchorNameIdentifier }
                    .compactMap { $0 as? AnchorEntity }
                    .forEach({ plantSignAnchorWrapper in

                        guard case let AnchoringComponent.Target.world(transform) = plantSignAnchorWrapper.anchoring.target else {
                                                           print("this anchor does not have a world based transform")
                                                           return
                                                       }
                        let theDistance = distance(transform.columns.3, arView.cameraTransform.matrix.columns.3)
                        print(" The current camera distance is: \(theDistance)")

                        let overrides = [originalSignEntity.name: plantSignAnchorWrapper]
                        if theDistance < 1 {
                            print(" close, show it")
//                             notifications.near.post(overrides: overrides)
                        } else if theDistance > 2 {
                            print(" far, hide it")
//                             notifications.far.post(overrides: overrides)
                        }
                    })

        }.store(in: &disposables)
    }
    

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
}

extension Entity {
    func findRoot() -> Entity {
        guard let parent = parent else {
            return self
        }
        return parent.findRoot()
    }
}

// ARKit to RealityKit helpers
extension ARDelegate {
    func sendAnchorToServer(arAnchor: ARAnchor, with remoteUUID: UUID, anchorEntity: AnchorEntity, plantName: String) {

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
    func addAnchorFromARAnchor(arAnchor: ARAnchor, with remoteUUID: UUID) {
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
}
// Tap things
extension ARDelegate {
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
        guard let scene = store.value.loadedPlantSignScene else {
            print("we must not have a scene yet")
            return
        }

        guard let originalSignEntity = scene.plantSignEntityToAttach else {
            print("This is the origina entity. use this as the key for the overrides")
            return
        }
        hits.map {
            $0.entity.findRoot()
        }
        .map { entity -> Entity? in
            let found = entity.findEntity(named: "PlantSignEntityToAttach")
            return found
        }
        .compactMap { optinalEntity in
            return optinalEntity
        }
        .forEach { entity in
            let overrides = [originalSignEntity.name: entity]
            let notifications = scene.notifications
            notifications.parsedTap.post(overrides: overrides)
            store.value.isShowingPlantInfo = true
        }
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
}
// private funcs
extension ARDelegate {

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

    func addAnchor(anchorName: String, anchorID: UUID, worldData: Data) throws {
        guard case let SelectedSpaceInfoIsSet.space(currentSelectedSpace) = store.value.selectedSpace else {
            throw ViewModelError.noSpaceSelected
        }
        print("ViewModel:AddAnchor We have a space selected, so send the anchor \(anchorID) \(anchorName) to the network client")
        var cancellable: AnyCancellable?
        cancellable = try networkClient.update(space: currentSelectedSpace,
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

extension Entity {

    func updatePlantSignName(name: String) {
        if let textEntity = findEntity(named: "simpBld_text") {
            print(textEntity)
            //                    plantSignEntity.removeChild(textEntity)
            print(textEntity.components)
            let textMesh = MeshResource.generateText(name,
                                                     extrusionDepth: 0,
                                                     font: .systemFont(ofSize: 0.05),
                                                     containerFrame: CGRect(origin: CGPoint(x: 0, y: -0.09), size: CGSize(width: 0.22, height: 15.24/100)),
                                                     alignment: .center,
                                                     lineBreakMode: .byWordWrapping)
            textEntity.components[ModelComponent]?.mesh = textMesh
        }
    }
    func addOcclusionBox() {
          let boxSize: Float = 0.5

          let boxMesh = MeshResource.generateBox(size: boxSize)
          let material = OcclusionMaterial()
          let occlusionPlane = ModelEntity(mesh: boxMesh, materials: [material])
          occlusionPlane.position.y = -boxSize / 2
          addChild(occlusionPlane)
      }
}

extension SCNVector3 {
    static func distanceFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> Float {
        let x0 = vector1.x
        let x1 = vector2.x
        let y0 = vector1.y
        let y1 = vector2.y
        let z0 = vector1.z
        let z1 = vector2.z

        return sqrtf(powf(x1-x0, 2) + powf(y1-y0, 2) + powf(z1-z0, 2))
    }
}
