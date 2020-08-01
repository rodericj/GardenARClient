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

extension ViewModel {

    func loadScene() {

           PlantSigns.loadSignSceneAsync { result in
               switch result {
               // this plantEntity holds is the entity we will add to the AnchorEntity
               case .success(let plantSignScene):
                   self.loadedPlantSignScene = plantSignScene
                   self.arView?.scene.addAnchor(plantSignScene)
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

class ViewModel: ObservableObject, Identifiable {
    private let networkClient: NetworkFetching
    private var disposables = Set<AnyCancellable>()


    var arView: ARView?
    @Published var isShowingPlantInfo: Bool = false
    @Published var isAddingSign: Bool = false
    @Published var alertViewOutput: String = ""
    @Published var showingAlert: AlertType = .none
    @Published var spaces: [SpaceInfo] = []
    @Published var selectedSpace: SpaceInfo? = nil {
        didSet {
            if oldValue != selectedSpace {
                anchors = selectedSpace?.anchors ?? []
            } else {
                print("The selectedSpace was set but it's the same as it was before")
            }
        }
    }

    @Published var anchors: [Anchor] = []
    var loadedPlantSignScene: PlantSigns.SignScene?


    let signAnchorNameIdentifier = "This Is the anchor Entity you are looking for. We added the plantSignScene to this"
    var pendingAnchorEntityLookup: [ARAnchor : (AnchorEntity, String)] = [:]
    var pendingAnchorEntitySet =  Set<AnchorEntity>()
    init(networkClient: NetworkFetching) {
        self.networkClient = networkClient


        $alertViewOutput.sink { string in
            switch self.showingAlert {
            case .createSpace(_):
                try? self.makeSpace(named: string)
            case .createMarker(_, let arView, let raycastResult):
                #if !targetEnvironment(simulator)

                // This is us adding the full scene to the
                guard let clonedPlantSign = self.loadedPlantSignScene?.plantSignEntityToAttach?.clone(recursive: true) else {
                    print("no plant sign entity")
                    return
                }
                guard let raycastResult = raycastResult else { return }

                let anchorEntity = AnchorEntity(world: raycastResult.worldTransform)
                anchorEntity.name = self.signAnchorNameIdentifier
                let collisionEntity = PlantSignCollisionEntity(plantSignEntity: clonedPlantSign)
                collisionEntity.addChild(clonedPlantSign)
                anchorEntity.addChild(collisionEntity)

                collisionEntity.generateCollisionShapes(recursive: true)
                
                // 5. add an occlusion plane to the anchor for when the sign is down below
//                anchorEntity.addOcclusionBox()

                // 6. Set the sign text
                clonedPlantSign.updatePlantSignName(name: string)

                print("// 7. add the anchor to the arView")
                arView.scene.addAnchor(anchorEntity)
                let arKitAnchor = ARAnchor(name: "RemoteUUID-\(UUID().uuidString)", transform: raycastResult.worldTransform)
                self.pendingAnchorEntityLookup[arKitAnchor] = (anchorEntity, string)
                arView.session.add(anchor: arKitAnchor)
                #endif

                // Set us back to the not isAddingSign state
                self.isAddingSign = false

            case .none:
                print("no-op")
            }
        }.store(in: &disposables)
    }


    func saveTheWorld() {
        #if !targetEnvironment(simulator)

        arView?.session.getCurrentWorldMap { (map, getWorldMapError) in

            if let error = getWorldMapError {
                print("🔴 Error fetching the world map. \(error)")
                return
            }
            guard let map = map else {
                print("🔴 Couldn't fetch the world map, but no error.")
                return
            }

            print(map.anchors)
//            do {
//                try self.processFetchedWorldMap(map: map, plantName: plantName, anchorEntity: anchorEntity)
//            } catch {
//                print("Unable to process the FetchedWorldMap \(error)")
//            }

        }
        #endif
    }
    func deleteSpace(at offsets: IndexSet) {
        try? offsets.map { spaces[$0].id }.forEach { uuid in
            try networkClient
                .deleteSpace(uuid: uuid )
                .sink(receiveCompletion: { error in
                    print("error deleting \(error)")
                }, receiveValue: { succeeded in
                    self.getSpaces()
                }).store(in: &disposables)
        }
    }

    func makeSpace(named name: String) throws {
        try networkClient.makeSpace(named: name)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    print("finished making space")
                case .failure(let errorWithLocalizedDescription):
                    print("🔴 Error in fetching \(errorWithLocalizedDescription.localizedDescription)")
                }
            }, receiveValue: { newSpaceInfo in
                print("the new space was created") 
                self.selectedSpace = newSpaceInfo
                self.getSpaces()
            }).store(in: &disposables)
    }

    func addAnchor(anchorName: String, anchorID: UUID, worldData: Data) throws {
        guard let currentSelectedSpace = selectedSpace else {
            throw ViewModelError.noSpaceSelected
        }
        print("ViewModel:AddAnchor We have a space selected, so send the anchor \(anchorID) \(anchorName) to the network client")
        try networkClient.update(space: currentSelectedSpace,
                                 anchorID: anchorID,
                                 anchorName: anchorName,
                                 worldMapData: worldData).sink(receiveCompletion: { error in

                                 }, receiveValue: { anchor in
                                    print("ViewModel:AddAnchor just saved this anchor \(anchor) with id: \(anchor.id?.uuidString ?? "No ID set for this anchor")")
                                    self.selectedSpace?.anchors?.append(anchor)
                                 }).store(in: &disposables)
    }

    func get(space: SpaceInfo) {
        networkClient.getSpace(uuid: space.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                switch result {

                case .finished:
                    print("got a space")
                case .failure(let error):
                    print("🔴 Error fetching single space \(error)")
                }
            }) { space in
                print("ViewModel got a new space \(space)")

                guard let indexOfOldSpace = self.spaces.firstIndex(where: { querySpace -> Bool in
                    querySpace.id == space.id
                }) else {
                    self.spaces.append(space)
                    return
                }
                self.spaces.append(space)
                // Handle the case where selected space was the one we are fetching
                if self.selectedSpace == self.spaces[indexOfOldSpace] {
                    self.selectedSpace = space
                }
                self.spaces.remove(at: indexOfOldSpace)
        }.store(in: &disposables)
    }
    func getSpaces() {
        networkClient.getSpaces
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] value in
                    guard let self = self else { return }
                    switch value {
                    case .failure:
                        self.spaces = []
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] spaces in
                    guard let self = self else { return }
                    if let selected = self.selectedSpace {
                        self.anchors = selected.anchors ?? []
                    }
                    self.spaces = spaces
            })
            .store(in: &disposables)
    }
}

