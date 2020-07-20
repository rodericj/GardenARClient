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

class ARDelegate: NSObject, ARSessionDelegate, HasOptionalARView {
    static let unnamedAnchorName = "NewUnnamedAnchor"
    let viewModel: ViewModel

    var pendingAddedAnchors: Set<ARAnchor> = []
    var temporaryAnchorsToRemove: Set<ARAnchor> = []

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func setupListeners() {

        viewModel.$anchors.sink { anchors in
            print("new anchors")
            anchors.forEach { anchor in
                print("anchor: \(anchor.id!) \(anchor.title)")
            }
        }.store(in: &disposables)
        viewModel.$selectedWorld.sink { worldInfo in
            // TODO clean up the ar session, load this world if possible. There is sample code for this
            print("In the ARDelegate the view model has changed")
            guard let data = worldInfo?.data else {
                print("This is likely a new world with no data saved on the server. Probably fine. But we _may_ be fetching the world data now")
                return
            }
            guard let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                print("Error loading the world map from the data. Something is pretty wrong here")
                return
            }
            let worldConfiguration = ARWorldTrackingConfiguration()
            worldConfiguration.initialWorldMap = worldMap
            self.arView?.session.run(worldConfiguration, options: [.resetTracking, .removeExistingAnchors])
        }.store(in: &disposables)
    }
    var arView: ARView?
    private var disposables = Set<AnyCancellable>()

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        anchors.filter {$0.name == ARDelegate.unnamedAnchorName }.forEach { temporarySessionAnchor in
            print("Removed the unnamed anchor. We might be able to send now")
            temporaryAnchorsToRemove.remove(temporarySessionAnchor)
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("ARDelegate object \(self)")

        // Handle the new "NewUnnamedAnchor" which gets added from SwiftUI
        anchors.filter {$0.name == ARDelegate.unnamedAnchorName }.forEach { temporarySessionAnchor in
            print("This is an anchor in the session: \(temporarySessionAnchor.name ?? "No name set for this temporary session anchor"). \(temporarySessionAnchor.identifier) \(temporarySessionAnchor.sessionIdentifier?.uuidString ?? "No session Identifier set for this temporary session anchor")")
            UIView.creationAlert(title: "Name this plant", placeholder: "Banana Squash") { plantName in
                self.temporaryAnchorsToRemove.insert(temporarySessionAnchor)
                session.remove(anchor: temporarySessionAnchor)
                let newNamedAnchor = ARAnchor(name: plantName, transform: temporarySessionAnchor.transform)
                self.pendingAddedAnchors.insert(newNamedAnchor)
                print("new named anchor \(plantName) \(newNamedAnchor.identifier)")
                session.add(anchor: newNamedAnchor)
            }
        }

        // Handle the new "named anchor" which gets added from an unnamed anchor above
        anchors.filter { $0.name != nil && $0.name != ARDelegate.unnamedAnchorName }.forEach { newNamedAnchor in
            print("Anchor got added named: \(newNamedAnchor.name ?? "Unnamed") with anchor identifier: \(newNamedAnchor.identifier). Let's remove it from the pending set and send it if it's empty")
            pendingAddedAnchors.remove(newNamedAnchor)

            if pendingAddedAnchors.isEmpty {
                print("Good, we should check temporary removals")
                if temporaryAnchorsToRemove.isEmpty {
                    print("both temporary sets are now empty. Send the payload")
                    session.getCurrentWorldMap { (map, getWorldMapError) in
                        if let error = getWorldMapError {
                            print("🔴 Error fetching the world map. \(error)")
                            return
                        }
                        guard let map = map else {
                            print("🔴 Couldn't fetch the world map, but no error.")
                            return
                        }
                        print("We got the map. here are the anchors \(map.anchors.map { $0.name })")
                        guard let pendingAnchorName = newNamedAnchor.name else {
                            fatalError("The anchor we sent has no name")
                        }
                        let anchorEntity = AnchorEntity(anchor: newNamedAnchor)
                        ModelEntity.loadAsync(named: "PlantSigns")
                            .sink(receiveCompletion: { result in
                                switch result {
                                case .finished:
                                    print("successfuly loaded plant sign async")
                                case .failure(let fetchModelError):
                                    print("🔴 Error loading plant signs async: \(fetchModelError)")
                                }
                            }) { plantSignEntity in
                                print(plantSignEntity)
                                self.addEntity(anchorEntity: anchorEntity, plantSignEntity: plantSignEntity, name: pendingAnchorName)
                                // we need to have this processFetchedWorldMap in this completion block, but it's a non throwing?
                                do {
                                    try self.processFetchedWorldMap(map: map, plantName: pendingAnchorName, anchorEntity: anchorEntity)
                                } catch {
                                    print("Unable to process the FetchedWorldMap \(error)")
                                }
                        }
                        .store(in: &self.disposables)
                    }
                }
            } else {
                fatalError("Problem here. We removed one and we had more than one pending")
            }

        }
        anchors.forEach { print("Anchor got added \($0.name ?? "Unnamed") \($0.identifier)") }
    }
}

// private funcs
extension ARDelegate {
    /**
     * Given an anchor entity and a plant sign entity and a name, add the plant sign to the anchor, add an occlusion plane, update the anchor entity's name
     * - Parameter anchorEntity: The anchor entity which we will be adding to our arview
     * - Parameter plantSignEntity: The RealityKit Composer output that looks like a nice blue sign
     * - Parameter name: The title which will be placed on the plantSignEntity
     */
    private func addEntity(anchorEntity: AnchorEntity, plantSignEntity: Entity, name: String) {
        anchorEntity.addChild(plantSignEntity)
        self.arView?.scene.addAnchor(anchorEntity)
        anchorEntity.addOcclusionPlane()
        print("add entity. set the name to \(name)")
        anchorEntity.updatePlantSignName(name: name)
    }

    /**
     *  Save the map to a data representation, send it to the view model
     * - Parameter map: The world map which should be sent to the server
     * - Parameter error: An error that may have occured when fetching the world map
     * - Parameter plantName: The name of the anchor we're sending to the view model
     * - Parameter anchorEntity: In the case of an error we will need to remove this anchor
     */
    private func processFetchedWorldMap(map: ARWorldMap, plantName: String, anchorEntity: AnchorEntity) throws {
        guard let anchorID = anchorEntity.anchorIdentifier else {
            self.arView?.scene.removeAnchor(anchorEntity)
            throw AnchorError.noUniqueIdentifier("We attempted to archive the world but the anchorEntity did not have an anchorIdentifier. It's optional but should be set when added to the session.")
        }
        if let worldData = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
            do {
                try self.viewModel.addAnchor(anchorName: plantName, anchorID: anchorID, worldData: worldData)
            } catch {
                self.arView?.scene.removeAnchor(anchorEntity)
                print("Unable to add anchor to the server \(error)")
            }
        } else {
            self.arView?.scene.removeAnchor(anchorEntity)
            print("no map data")
        }
        // If we have an error we need to remove the anchor
        // TODO we may want to handle the error case outside of this method. There are other scenarios where we may want to remove the anchor
    }
}

extension AnchorEntity {
    fileprivate func updatePlantSignName(name: String) {
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
    func addOcclusionPlane() {
          let boxSize: Float = 0.5

          let boxMesh = MeshResource.generateBox(size: boxSize)
          let material = OcclusionMaterial()
          let occlusionPlane = ModelEntity(mesh: boxMesh, materials: [material])
          occlusionPlane.position.y = -boxSize / 2
          addChild(occlusionPlane)
      }
}
