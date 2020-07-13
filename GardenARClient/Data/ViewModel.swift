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
            let disposable = try networkClient.deleteWorld(uuid: uuid ).sink(receiveCompletion: { error in
                print("error deleting \(error)")
            }, receiveValue: { succeeded in
                self.getWorlds()
            })
                //.receive(on: DispatchQueue.main)
            disposables.insert(disposable)
        }
    }

    func makeWorld(named name: String) throws {
        let cancellable = try networkClient.makeWorld(named: name).sink(receiveCompletion: { error in
            print("error in fetching \(error)")
        }, receiveValue: { newWorldInfo in
            print("the new world was created")
            self.getWorlds()
        })
        disposables.insert(cancellable)
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

