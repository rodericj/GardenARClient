//
//  ViewModel.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
import Combine
import ARKit
import RealityKit
import SwiftUI
enum ViewModelError: Error {
    case noSpaceSelected
}

enum DataOrLoading {
    case loading
    case spaces([SpaceInfo])
}

enum AlertModel: Equatable {
    case notShowing
    case showing(String)
}

extension ARDelegate {

    func loadScene() {
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

class PlantSignCollisionEntity: Entity, HasCollision {
    var cancellable: Cancellable?

    init(plantSignEntity: Entity) {
        super.init()
        self.addChild(plantSignEntity)
        self.components[CollisionComponent] = CollisionComponent(
          shapes: [.generateBox(size: [1,1,1])],
          mode: .trigger,
          filter: .sensor
        )
    }

    required init() {
        fatalError("init() has not been implemented")
    }
}

enum SelectedSpaceInfoIsSet: Equatable {
    case none
    case space(SpaceInfo)

    var title: String {
        get {
            switch self {
            case .none:
                return "Fetching..."
            case .space(let spaceInfo):
                return spaceInfo.title
            }
        }
    }
}

enum SpaceInfoFetch {
    case fetching
    case fetched([SpaceInfo])
    case failed(Error)
    var all: [SpaceInfo] {
        get {
            switch self {
            case .fetching:
                return []
            case .fetched(let spaceInfos):
                return spaceInfos
            case .failed:
                return []
            }
        }
    }

    var isFetching: Bool {
        get {
            switch self {
            case .fetching:
                return true
            case .fetched(_), .failed:
                return false
            }
        }
    }
}

struct ViewModel {
    var arView: ARView?
    var isShowingPlantInfo: Bool = false
    var isAddingSign: Bool = false
    var isShowingSpaceSelectionView: Bool = true
    var shouldShowAddSignButton: Bool {
        get {
            selectedSpace != .none && !isShowingPlantInfo && !isShowingSpaceSelectionView
        }
    }
    var showingAlert: AlertType = .none
    var spaces: SpaceInfoFetch = .fetching {
        didSet {
            isShowingSpaceSelectionView = selectedSpace == .none
            print("spaces \(spaces)")
        }
    }
    var selectedSpace: SelectedSpaceInfoIsSet = .none {
        didSet {
            if oldValue != selectedSpace {
                gotSelectedSpace()
            }
            if selectedSpace == .none {
                isShowingSpaceSelectionView = true
            }
        }
    }

    var loadedPlantSignScene: PlantSigns.SignScene?

    var pendingAnchorEntityLookup: [ARAnchor : (anchorEntity: AnchorEntity, plantName: String)] = [:]

    private func gotSelectedSpace() {
        print("🌎 We updated our selected space. Let's consider updating the arView's world configuration")
        guard case SelectedSpaceInfoIsSet.space(let spaceInfo) = selectedSpace else {
            return
        }
        guard let data = spaceInfo.data else {
            print("🌎 This is likely a new space with no data saved on the server. Probably fine. But we _may_ be fetching the space data now")
            return
        }
        guard let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            print("🌎 Error loading the world map from the data. Something is pretty wrong here")
            return
        }
        let worldConfiguration = ARWorldTrackingConfiguration()
        worldConfiguration.initialWorldMap = worldMap
        guard let arView = arView else {
            print("🌎 There is no arView to set the world. This is a problem")
            return
        }
        print("The scene itself before run is \(arView.scene.id)")
        print("🌎 starting new session with world data from the network")
        #if !targetEnvironment(simulator)

        arView.session.run(worldConfiguration, options: [.resetTracking, .removeExistingAnchors])
        #endif
        print("The scene itself after run is \(arView.scene.id)")
        guard let scene = loadedPlantSignScene else {
            print("weird, we haven't loaded the scene yet")
            return
        }
        arView.scene.addAnchor(scene)
    }
}
