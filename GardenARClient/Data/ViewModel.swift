//
//  ViewModel.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
import Combine

protocol HasWorlds {
    var worlds: [WorldInfo] { get }
    var selectedWorld: WorldInfo? { get }
}

enum ViewModelError: Error {
    case noWorldSelected
}
enum DataOrLoading {
    case loading
    case worlds([WorldInfo])
}

class ViewModel: ObservableObject, Identifiable, HasWorlds {
    private let networkClient: NetworkFetching
    private var disposables = Set<AnyCancellable>()

    @Published var worlds: [WorldInfo] = []
    @Published var selectedWorld: WorldInfo? = nil {
        didSet {
            if oldValue != selectedWorld {
                anchors = selectedWorld?.anchors ?? []
            } else {
                print("The selectedWorld was set but it's the same as it was before")
            }
        }
    }

    @Published var anchors: [Anchor] = []

    init(networkClient: NetworkFetching) {
      self.networkClient = networkClient
    }

    func deleteWorld(at offsets: IndexSet) {
        try? offsets.map { worlds[$0].id }.forEach { uuid in
            try networkClient
                .deleteWorld(uuid: uuid )
                .sink(receiveCompletion: { error in
                    print("error deleting \(error)")
                }, receiveValue: { succeeded in
                    self.getWorlds()
                }).store(in: &disposables)
        }
    }

    func makeWorld(named name: String) throws {
        try networkClient.makeWorld(named: name)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    print("finished making world")
                case .failure(let errorWithLocalizedDescription):
                    print("🔴 Error in fetching \(errorWithLocalizedDescription.localizedDescription)")
                }
            }, receiveValue: { newWorldInfo in
                print("the new world was created") 
                self.selectedWorld = newWorldInfo
                self.getWorlds()
            }).store(in: &disposables)
    }

    func addAnchor(anchorName: String, anchorID: UUID, worldData: Data) throws {
        guard let currentSelectedWorld = selectedWorld else {
            throw ViewModelError.noWorldSelected
        }
        print("ViewModel:AddAnchor We have a world selected, so send the anchor \(anchorID) \(anchorName) to the network client")
        try networkClient.update(world: currentSelectedWorld,
                                 anchorID: anchorID,
                                 anchorName: anchorName,
                                 worldMapData: worldData).sink(receiveCompletion: { error in

                                 }, receiveValue: { anchor in
                                    print("ViewModel:AddAnchor just saved this anchor \(anchor) with id: \(anchor.id?.uuidString ?? "No ID set for this anchor")")
                                    self.selectedWorld?.anchors?.append(anchor)
                                 }).store(in: &disposables)
    }

    func get(world: WorldInfo) {
        networkClient.getWorld(uuid: world.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                switch result {

                case .finished:
                    print("got a world")
                case .failure(let error):
                    print("🔴 Error fetching single world \(error)")
                }
            }) { world in
                print("ViewModel got a new world \(world)")

                guard let indexOfOldWorld = self.worlds.firstIndex(where: { queryWorld -> Bool in
                    queryWorld.id == world.id
                }) else {
                    self.worlds.append(world)
                    return
                }
                self.worlds.append(world)
                // Handle the case where selected world was the one we are fetching
                if self.selectedWorld == self.worlds[indexOfOldWorld] {
                    self.selectedWorld = world
                }
                self.worlds.remove(at: indexOfOldWorld)
        }.store(in: &disposables)
    }
    func getWorlds() {
        networkClient.getWorlds
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] value in
                    guard let self = self else { return }
                    switch value {
                    case .failure:
                        self.worlds = []
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] worlds in
                    guard let self = self else { return }

                    // Auto select solo worlds
                    if worlds.count == 1 {
                        self.selectedWorld = worlds.first
                    }
                    if let selected = self.selectedWorld {
                        self.anchors = selected.anchors ?? []
                    }
                    self.worlds = worlds
            })
            .store(in: &disposables)
    }

}

