//
//  ViewModel.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
import Combine

protocol HasSpaces {
    var spaces: [SpaceInfo] { get }
    var selectedSpace: SpaceInfo? { get }
}

enum ViewModelError: Error {
    case noSpaceSelected
}
enum DataOrLoading {
    case loading
    case spaces([SpaceInfo])
}

class ViewModel: ObservableObject, Identifiable, HasSpaces {
    private let networkClient: NetworkFetching
    private var disposables = Set<AnyCancellable>()

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

    init(networkClient: NetworkFetching) {
      self.networkClient = networkClient
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

