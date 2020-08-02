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
    static let signAnchorNameIdentifier = "This Is the anchor Entity you are looking for. We added the plantSignScene to this"
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
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        store.value.arView?.scene
            .anchors
            .filter { $0.name == Scene.AnchorCollection.signAnchorNameIdentifier }
            .compactMap { $0 as? AnchorEntity }
            .forEach { plantSignAnchorWrapper in
                guard let scene = store.value.loadedPlantSignScene else {
                    print("we must not have a scene yet")
                    return
                }

                // TODO get PlantSignExtraTop, PlantSignExtraMiddle, PlantSignExtraBottom
                guard let originalSignEntity = scene.plantSignEntityToAttach else {
                    print("This is the origina entity. use this as the key for the overrides")
                    return
                }
                plantSignAnchorWrapper.children.filter { entity in
                    return entity.name == "PlantSignEntityToAttach"
                }.forEach { entity in

                    // get the plant sign's anchoring's targets's world transform to determine the distance from the camera
                    guard case let AnchoringComponent.Target.world(transform) = plantSignAnchorWrapper.anchoring.target else {
                        print("this anchor does not have a world based transform")
                       return
                    }
                    let theDistance = distance(transform.columns.3, frame.camera.transform.columns.3)
                    let notifications = scene.notifications

                    // ok actually the thing we want is not anchorWeAreCheckingForDistance, it's the child
                    let overrides = [originalSignEntity.name: entity]
                    //print("overrides \(overrides.keys)")
                    if theDistance > 2 {
                        print("send notification that we are more than 2 meters away. So like hide the extra stuff i guess")
                        notifications.far.post(overrides: overrides)
                    }
                    if theDistance < 1 {
                        // show it
                        if !visibleSigns.contains(entity) {
                            print("close, show it")
                            visibleSigns.insert(entity)
                            hiddenSigns.remove(entity)
                            notifications.near.post(overrides: overrides)
                        }
                    } else {
                        if visibleSigns.contains(entity) {
                            visibleSigns.remove(entity)
                            hiddenSigns.insert(entity)
                            print("far, hide it")
                            notifications.far.post(overrides: overrides)
                        }
                    }
                }
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        print("ARDelegate object didAdd \(anchors.count) anchors")

        anchors
            .filter { $0.name?.hasPrefix("RemoteUUID-") ?? false }
            .forEach { newlyAddedARKitAnchor in

                // Check if there are any pending anchor entity's in the lookup. This may not be necessary anymore
                print("thisAnchor \(newlyAddedARKitAnchor)")
                guard let anchorEntityContainingSignEntityAndStringTuple = store.value.pendingAnchorEntityLookup[newlyAddedARKitAnchor] else {

                    print("this anchor is not tied to a pending reality kit anchor entity which means it came from the network probably")
                    guard let plantSignEntityToAttach = store.value.loadedPlantSignScene?.plantSignEntityToAttach?.clone(recursive: true) else {
                        print("No plantSignScene was loaded")
                        return
                    }
                    if let plantName = newlyAddedARKitAnchor.name {
                        plantSignEntityToAttach.name = plantName
                    }
                    // 4. Add the newly loaded plantSign to the anchor
                    #if !targetEnvironment(simulator)

                    let anchorEntity = AnchorEntity(anchor: newlyAddedARKitAnchor)
                    anchorEntity.addChild(plantSignEntityToAttach)
                    //                // 5. add an occlusion plane to the anchor for when the sign is down below
                    //                anchorEntity.addOcclusionBox()

                    // 6. Set the sign text
                    //plantSignScene.plantSignAnchor?.updatePlantSignName(name: plantName ?? "Name should have come in on the anchor")

                    // TODO this part might be a bit odd. We are adding it to the arView's scene AND session. I think this isn't correct. I think we need to move one to another place
                    print("// 7. add the anchor to the arView")
                    self.store.value.arView?.scene.anchors.append(anchorEntity)
                    #endif

                    return
                }
                print("we found a match \(anchorEntityContainingSignEntityAndStringTuple.0.name)")
                let plantName = anchorEntityContainingSignEntityAndStringTuple.1
                // 8. Need to get the world map then verify that this new thing is on there.
                // 8a. At this point we actually need to wait until we get a signal that the anchors have changed. To the delegate!
                #if !targetEnvironment(simulator)
                store.value.arView?.session.getCurrentWorldMap { (map, getWorldMapError) in

                    if let error = getWorldMapError {
                        print("🔴 Error fetching the world map. \(error)")
                        return
                    }
                    guard let map = map else {
                        print("🔴 Couldn't fetch the world map, but no error.")
                        return
                    }

                    do {
                        // TODO we need ot pass the REMOTEUUID here over to the server
                        try self.processFetchedWorldMap(map: map, plantName: plantName, anchorEntityContainingSignEntity: anchorEntityContainingSignEntityAndStringTuple.0)
                    } catch {
                        print("Unable to process the FetchedWorldMap \(error)")
                    }

                }
                #endif
        }

        // Handle the new "named anchor" which gets added from an unnamed anchor above
//        anchors.filter { $0.name != nil && $0.name != ARDelegate.unnamedAnchorName }.forEach { newNamedAnchor in
//            print("Anchor got added named: \(newNamedAnchor.name ?? "Unnamed") with anchor identifier: \(newNamedAnchor.identifier). Let's remove it from the pending set and send it if it's empty")
//            pendingAddedAnchors.remove(newNamedAnchor)
//
//            if pendingAddedAnchors.isEmpty {
//                print("Good, we should check temporary removals")
//                if temporaryAnchorsToRemove.isEmpty {
//                    print("both temporary sets are now empty. Send the payload")
//                    session.getCurrentWorldMap { (map, getWorldMapError) in
//                        if let error = getWorldMapError {
//                            print("🔴 Error fetching the world map. \(error)")
//                            return
//                        }
//                        guard let map = map else {
//                            print("🔴 Couldn't fetch the world map, but no error.")
//                            return
//                        }
//                        print("We got the map. here are the anchors \(map.anchors.map { $0.name })")
//                        guard let pendingAnchorName = newNamedAnchor.name else {
//                            fatalError("The anchor we sent has no name")
//                        }
//                        #if !targetEnvironment(simulator)
//                        let anchorEntity = AnchorEntity(anchor: newNamedAnchor)
//                        #endif
//                    }
//                }
//            } else {
//                fatalError("Problem here. We removed one and we had more than one pending")
//            }
//
//        }
//        anchors.forEach { print("Anchor got added \($0.name ?? "Unnamed") \($0.identifier)") }
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
            //                messageLabel.displayMessage("No surface detected, try getting closer.", duration: 2.0)
            print("No surface detected, try getting closer.")
            return
        }

        print("the raycast results \(raycastResultsArray)")

        // TODO if we didn't collide with one of our own, then move forward, otherwise bail.
        // TODO at this point i think we can capture the tap, show the alert, send it to the server, then add it to the arview
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
    private func processFetchedWorldMap(map: ARWorldMap, plantName: String, anchorEntityContainingSignEntity: AnchorEntity) throws {
        guard let anchorID = anchorEntityContainingSignEntity.anchorIdentifier
            else {
                self.store.value.arView?.scene.removeAnchor(anchorEntityContainingSignEntity)
            throw AnchorError.noUniqueIdentifier("We attempted to archive the world but the anchorEntity did not have an anchorIdentifier. It's optional but should be set when added to the session.")
        }
        if let worldData = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
            do {
                try self.addAnchor(anchorName: plantName, anchorID: anchorID, worldData: worldData)
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
        guard let currentSelectedSpace = store.value.selectedSpace else {
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
                                                self.store.value.selectedSpace?.anchors?.append(anchor)
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
