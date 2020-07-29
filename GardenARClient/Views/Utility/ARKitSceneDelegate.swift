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

class ARDelegate: NSObject, ARSessionDelegate, HasOptionalARView, ARSCNViewDelegate {
    func updateWithEntity(entity: HasAnchoring) {
        viewModel.arView?.scene.addAnchor(entity)
    }

    var visibleSigns = Set<Entity>()
    var hiddenSigns = Set<Entity>()
    static let unnamedAnchorName = "NewUnnamedAnchor"
    let viewModel: ViewModel
    private var disposables = Set<AnyCancellable>()

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }


    func setupListeners() {

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            self.shouldUpdateSigns = true
        }

        viewModel.$anchors.sink { anchors in
            print("new anchors from the viewModel.$anchor's stream")
            anchors.forEach { anchor in
                print("anchor: \(anchor.id?.uuidString ?? "anchor with no id seems unlikely") \(anchor.title)")
            }
        }.store(in: &disposables)
        viewModel.$selectedSpace.sink { spaceInfo in
            print("🌎 In the ARDelegate the view model has changed")
            guard let data = spaceInfo?.data else {
                print("🌎 This is likely a new space with no data saved on the server. Probably fine. But we _may_ be fetching the space data now")
                return
            }
            guard let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                print("🌎 Error loading the world map from the data. Something is pretty wrong here")
                return
            }
            let worldConfiguration = ARWorldTrackingConfiguration()
            worldConfiguration.initialWorldMap = worldMap
            guard let arView = self.viewModel.arView else {
                print("🌎 There is no arView to set the world. This is a problem")
                return
            }
            print("The scene itself before run is \(arView.scene.id)")
            print("🌎 starting new session with world data from the network")
            #if !targetEnvironment(simulator)

            arView.session.run(worldConfiguration, options: [.resetTracking, .removeExistingAnchors])
            #endif
            print("The scene itself after run is \(arView.scene.id)")
            guard let scene = self.viewModel.loadedPlantSignScene else {
                print("weird, we haven't loaded the scene yet")
                return
            }
            arView.scene.addAnchor(scene)
        }.store(in: &disposables)
    }


    var shouldUpdateSigns = false
    var timer: Timer?

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        if !shouldUpdateSigns {
            return
        }
        shouldUpdateSigns = false

        viewModel.arView?.scene
            .anchors
            .filter { $0.name == viewModel.signAnchorNameIdentifier }
            .compactMap { $0 as? AnchorEntity }
            .forEach { plantSignAnchorWrapper in
                guard let scene = viewModel.loadedPlantSignScene else {
                    print("we must not have a scene yet")
                    return
                }

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
                        //                    print("send notification that we are more than 2 meters away. So like hide the extra stuff i guess")
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

        anchors.forEach { thisAnchor in
            if let _ = thisAnchor as? AREnvironmentProbeAnchor {
                return
            }
            return // TODO Ok this is me defaulting to NOT add entities from the network. obvoiusly i can't leave this here
            let a = 1
            // Check if there are any pending anchor entity's in the lookup. This may not be necessary anymore
            guard let anchorEntity = viewModel.pendingAnchorEntityLookup[thisAnchor] else {

                print("this anchor is not tied to a pending reality kit anchor entity which means it came from the network probably")
                guard let plantSignEntityToAttach = viewModel.loadedPlantSignScene?.plantSignEntityToAttach?.clone(recursive: true) else {
                    print("No plantSignScene was loaded")
                    return
                }
//                print("I think this is what we want to add to the anchors: \(plantSignScene.plantSignAnchorToAttach)")
//                guard let plantSignEntity = plantSignScene.plantSignAnchor else {
//                    print("🔴 Plant sign entitty did not exist")
//                    return
//                }
                if let plantName = thisAnchor.name {
                    plantSignEntityToAttach.name = plantName
                }
                // 4. Add the newly loaded plantSign to the anchor
                let anchorEntity = AnchorEntity(anchor: thisAnchor)
                anchorEntity.addChild(plantSignEntityToAttach)
//
//
//                // 5. add an occlusion plane to the anchor for when the sign is down below
//                anchorEntity.addOcclusionBox()

                // 6. Set the sign text
                //plantSignScene.plantSignAnchor?.updatePlantSignName(name: plantName ?? "Name should have come in on the anchor")

                // TODO this part might be a bit odd. We are adding it to the arView's scene AND session. I think this isn't correct. I think we need to move one to another place
                print("// 7. add the anchor to the arView")
                self.viewModel.arView?.scene.anchors.append(anchorEntity)

                return
            }
            print("we found a match \(anchorEntity.name)")
            guard let plantName = thisAnchor.name else {
                print("We need to name this anchor")
                return 
            }
            // 8. Need to get the world map then verify that this new thing is on there.
            // 8a. At this point we actually need to wait until we get a signal that the anchors have changed. To the delegate!
            viewModel.arView?.session.getCurrentWorldMap { (map, getWorldMapError) in

                if let error = getWorldMapError {
                    print("🔴 Error fetching the world map. \(error)")
                    return
                }
                guard let map = map else {
                    print("🔴 Couldn't fetch the world map, but no error.")
                    return
                }

                do {
                    try self.processFetchedWorldMap(map: map, plantName: plantName, anchorEntity: anchorEntity)
                } catch {
                    print("Unable to process the FetchedWorldMap \(error)")
                }

            }

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


// Tap things
extension ARDelegate {
    func tapGestureSetup() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedOnARView))
        assert(viewModel.arView != nil)
        viewModel.arView?.addGestureRecognizer(tapGesture)
    }

    /// Tap gesture input handler.
    /// - Tag: TapHandler
    @objc
    func tappedOnARView(_ sender: UITapGestureRecognizer) {
        // Create a new sticky note at the tap location.
        addNewAnchor(sender)
    }

    fileprivate func addNewAnchor(_ sender: UITapGestureRecognizer) {
        // Get the user's tap screen location.
        guard let arView = viewModel.arView else {
            return
        }
        let touchLocation = sender.location(in: arView)

        // Cast a ray to check for its intersection with any planes.
        #if !targetEnvironment(simulator)

        let raycastResultsArray = arView.raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .any)
        guard let raycastResult = raycastResultsArray.first else {
            //                messageLabel.displayMessage("No surface detected, try getting closer.", duration: 2.0)
            print("No surface detected, try getting closer.")
            return
        }

        print("the raycast results \(raycastResultsArray)")

//        https://github.com/maxxfrazer/FocusEntity.git


        // TODO if we didn't collide with one of our own, then move forward, otherwise bail.
        // TODO at this point i think we can capture the tap, show the alert, send it to the server, then add it to the arview
        viewModel.showingAlert = .createMarker("Name this plant", arView, raycastResult)
        #endif

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
    private func processFetchedWorldMap(map: ARWorldMap, plantName: String, anchorEntity: AnchorEntity) throws {
        guard let anchorID = anchorEntity.anchorIdentifier
            else {
                self.viewModel.arView?.scene.removeAnchor(anchorEntity)
            throw AnchorError.noUniqueIdentifier("We attempted to archive the world but the anchorEntity did not have an anchorIdentifier. It's optional but should be set when added to the session.")
        }
        if let worldData = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
            do {
                try self.viewModel.addAnchor(anchorName: plantName, anchorID: anchorID, worldData: worldData)
            } catch {
                self.viewModel.arView?.scene.removeAnchor(anchorEntity)
                print("Unable to add anchor to the server \(error)")
            }
        } else {
            self.viewModel.arView?.scene.removeAnchor(anchorEntity)
            print("no map data")
        }
        // If we have an error we need to remove the anchor
        // TODO we may want to handle the error case outside of this method. There are other scenarios where we may want to remove the anchor
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
