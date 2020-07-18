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

class ARDelegate: NSObject, ARSessionDelegate, HasOptionalARView {
    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func setupListeners() {
        viewModel.$selectedWorld.sink { worldInfo in
            print("In the ARDelegate the view model has changed")
        }.store(in: &disposables)
    }
    var arView: ARView?
    private var disposables = Set<AnyCancellable>()

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("ARDelegate object \(self)")
        anchors.filter {$0.name == "NewUnnamedAnchor" }.forEach { anchor in
            print("This is the sphere anchor thing. Add some entity to the thing.")
            ModelEntity.loadAsync(named: "PlantSigns")
                .sink(receiveCompletion: { error in
                    print("error loading plant signs async: \(error)")
                }) { plantSignEntity in
                    print(plantSignEntity)
//                    guard let plantSignEntity = try? ModelEntity.load(named: "PlantSigns") else { return }
                    let anchorEntity = AnchorEntity(anchor: anchor)
                    anchorEntity.updatePlantSignName(name: "New Plant")
                    anchorEntity.addChild(plantSignEntity)
                    self.arView?.scene.addAnchor(anchorEntity)
                    anchorEntity.addOcclusionPlane()

                    UIView.creationAlert(title: "Name this plant", placeholder: "Banana Squash") { plantName in
                        print("plant name \(plantName). Kick off the network request")
                        session.getCurrentWorldMap { (map, error) in
                            if let map = map,
                                let worldData = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
                                do {
                                    try self.viewModel.addAnchor(anchorName: plantName, worldData: worldData)
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
                        // TODO I need to move all of this code into an object that has access to the view model not an extension of the View
                    }
            }.store(in: &disposables)
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
