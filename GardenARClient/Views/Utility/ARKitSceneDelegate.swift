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

extension Entity {
    func findRoot() -> Entity {
        guard let parent = parent else {
            return self
        }
        return parent.findRoot()
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
