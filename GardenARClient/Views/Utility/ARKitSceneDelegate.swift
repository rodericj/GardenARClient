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

class ARDelegate: NSObject, ARSessionDelegate, ARSCNViewDelegate {
    var visibleSigns = Set<Entity>()
    var hiddenSigns = Set<Entity>()
    static let unnamedAnchorName = "NewUnnamedAnchor"
    let store: Store<ViewModel>

    let networkClient: NetworkClient
    init(store: Store<ViewModel>, networkClient: NetworkClient) {
        self.store = store
        self.networkClient = networkClient

    }

    func loadScene() {
        // TODO in the effort to move the ARView out of the model, I think we need to make this not async. Let's see how it goes.
        PlantSigns.loadSignSceneAsync { result in
            switch result {
            // this plantEntity holds is the entity we will add to the AnchorEntity
            case .success(let plantSignScene):
                self.store.value.loadedPlantSignScene = plantSignScene
                self.store.value.arView?.scene.addAnchor(plantSignScene)
            case .failure(let fetchModelError):
                fatalError("🔴 Error loading plant signs async: \(fetchModelError)")
            }
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
extension ARViewContainer {
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
