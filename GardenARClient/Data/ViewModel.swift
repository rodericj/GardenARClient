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
    @Published var selectedWorld: WorldInfo? = nil

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
            .sink(receiveCompletion: { error in
                switch error {

                case .finished:
                    print("finished \(error)")
                case .failure(let errorWithLocalizedDescription):
                    print(errorWithLocalizedDescription.localizedDescription)
                }
                print("error in fetching \(error)")
            }, receiveValue: { newWorldInfo in
                print("the new world was created")
                self.selectedWorld = newWorldInfo
                self.getWorlds()
            }).store(in: &disposables)
    }

    func addAnchor(anchorName: String, worldData: Data) throws {
        guard let currentSelectedWorld = selectedWorld else {
            throw ViewModelError.noWorldSelected
        }
        let maybeWeDontNeedThisUUID = UUID()
        try networkClient.update(world: currentSelectedWorld,
                                 anchorID: maybeWeDontNeedThisUUID,
                                 anchorName: anchorName,
                                 worldMapData: worldData).sink(receiveCompletion: { error in

                                 }, receiveValue: { anchor in
                                    print("just saved this anchor \(anchor) with id: \(anchor.id)")
                                    self.getWorlds()
                                 }).store(in: &disposables)
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
                    self.worlds = worlds
            })
            .store(in: &disposables)
    }

}

