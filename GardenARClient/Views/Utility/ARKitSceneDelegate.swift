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
    case noUniqueIdentifier
}

class ARDelegate: NSObject, ARSessionDelegate, HasOptionalARView {
    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func setupListeners() {

        viewModel.$anchors.sink { anchors in
            print("new anchors")
            anchors.forEach { anchor in
                print("anchor: \(anchor.id!) \(anchor.title)")
                if let foundHasAnchor = self.arView?.scene.anchors.first(where: { someAnchor -> Bool in
                    someAnchor.anchorIdentifier == anchor.id
                }), let entity = foundHasAnchor as? AnchorEntity {
                    print("Found it in the scene. Now set the titlehome")
                    entity.updatePlantSignName(name: anchor.title)
                }
            }
        }.store(in: &disposables)
        viewModel.$selectedWorld.sink { worldInfo in
            // TODO clean up the ar session, load this world if possible. There is sample code for this
            print("In the ARDelegate the view model has changed")
            guard let data = worldInfo?.data,
                let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
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

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("ARDelegate object \(self)")
        anchors.filter {$0.name == "NewUnnamedAnchor" }.forEach { sessionAnchor in
            print("This is the sphere anchor thing. Add some entity to the thing.")
            ModelEntity.loadAsync(named: "PlantSigns")
                .sink(receiveCompletion: { result in
                    switch result {
                    case .finished:
                        print("successfuly loaded plant sign async")
                    case .failure(let error):
                        print("error loading plant signs async: \(error)")
                    }
                }) { plantSignEntity in
                    print(plantSignEntity)
                    let anchorEntity = AnchorEntity(anchor: sessionAnchor)
                    self.addEntity(anchorEntity: anchorEntity, plantSignEntity: plantSignEntity)
                    self.showAlert(anchorEntity: anchorEntity, session: session, sessionAnchor: sessionAnchor)
            }.store(in: &disposables)
        }
    }
}

// private funcs
extension ARDelegate {
    private func showAlert(anchorEntity: AnchorEntity, session: ARSession, sessionAnchor: ARAnchor) {
        UIView.creationAlert(title: "Name this plant", placeholder: "Banana Squash") { plantName in
            print("plant name \(plantName). Kick off the network request")
            // TODO change the name of the anchor here:
//            sessionAnchor.name = plantName
                session.getCurrentWorldMap { (map, error) in
                    do {
                        try self.processFetchedWorldMap(map: map, error: error, plantName: plantName, anchorEntity: anchorEntity)
                    } catch {
                        print("failed to process fetched world map \(error)")
                    }
                }
            // TODO I need to move all of this code into an object that has access to the view model not an extension of the View
        }
    }

    private func addEntity(anchorEntity: AnchorEntity, plantSignEntity: Entity) {
        anchorEntity.updatePlantSignName(name: "New Plant")
        anchorEntity.addChild(plantSignEntity)
        self.arView?.scene.addAnchor(anchorEntity)
        anchorEntity.addOcclusionPlane()
    }

    private func processFetchedWorldMap(map: ARWorldMap?, error: Error?, plantName: String, anchorEntity: AnchorEntity) throws {
        guard let anchorID = anchorEntity.anchorIdentifier else {
            throw AnchorError.noUniqueIdentifier
        }
        if let map = map,
            let worldData = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
            do {
                try self.viewModel.addAnchor(anchorName: plantName, anchorID: anchorID, worldData: worldData)
            } catch {
                print("Unable to add anchor to the server \(error)")
            }
        } else {
            print("no map data")
        }
        // If we have an error we need to remove the anchor
        if let error = error {
            print("error fetching current world map \(error)")
            self.arView?.scene.removeAnchor(anchorEntity)
        }
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
