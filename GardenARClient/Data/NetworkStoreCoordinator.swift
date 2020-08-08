//
//  NetworkViewModelCoordinator.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 8/3/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
import Combine

extension Store where Value == ViewModel {

    func checkModalState() {
        value.isShowingModalInfoCollectionFlow = (value.showingAlert != TextInputType.none) || (value.selectedSpace == .none)
    }

    func appendSpace(spaceInfo: SpaceInfo) {
        switch value.spaces {

        case .fetching:
            value.spaces = .fetched([spaceInfo])
        case .fetched(let fetchedSpaces):
            var copy = fetchedSpaces
            copy.append(spaceInfo)
            value.spaces = .fetched(copy)
        case .failed(let error):
            print("error making a space \(error)")
        }
    }
    func removeSpace(at index: Int) {
        switch value.spaces {

        case .fetching:
            break
        case .fetched(let fetchedSpaces):
            var copy = fetchedSpaces
            copy.remove(at: index)
            value.spaces = .fetched(copy)
        case .failed(let error):
            print("error making a space \(error)")
        }
    }

    func get(space: SpaceInfo) {
        var cancellable: AnyCancellable?
        cancellable = networkClient.getSpace(uuid: space.id)

            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    print("got a space")
                case .failure(let error):
                    print("🔴 Error fetching single space \(error)")
                }
            }) { space in
                guard let indexOfOldSpace = self.value.spaces.all.firstIndex(where: { querySpace -> Bool in
                    querySpace.id == space.id
                }) else {
                    self.appendSpace(spaceInfo: space)
                    cancellable?.cancel()
                    return
                }
                self.appendSpace(spaceInfo: space)
                spaceSelectionReducer(viewModel: &self.value, action: .selectSpace(space))
                self.removeSpace(at: indexOfOldSpace)
                cancellable?.cancel()
        }
    }

    func getSpaces() {
           var cancellable: AnyCancellable?
           cancellable = networkClient.getSpaces
               .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { value in
                    switch value {
                    case .failure(let error):
                        self.value.spaces = .failed(error)
                    case .finished:
                        break
                    }
            },
                receiveValue: { spaces in
                    self.value.spaces = .fetched(spaces)
                    cancellable?.cancel()
            })

    }

    func update(space: SpaceInfo, anchorID: UUID, anchorName: String, worldMapData: Data) throws -> AnyPublisher<Anchor, Error> {
        return try networkClient.update(space: space, anchorID: anchorID, anchorName: anchorName, worldMapData: worldMapData)
    }

    func deleteSpace(at offsets: IndexSet) {
        try? offsets.map { value.spaces.all[$0].id }.forEach { uuid in
            var cancellable: AnyCancellable?
            cancellable = try networkClient
                .deleteSpace(uuid: uuid )
                .sink(receiveCompletion: { error in
                    print("error deleting \(error)")
                }, receiveValue: { succeeded in
                    self.getSpaces()
                    cancellable?.cancel()
                })
        }
    }

    func makeSpace(named name: String) throws {
        var cancellable: AnyCancellable?
        cancellable = try networkClient.makeSpace(named: name)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    print("finished making space")
                case .failure(let errorWithLocalizedDescription):
                    print("🔴 Error in fetching \(errorWithLocalizedDescription.localizedDescription)")
                }
            }, receiveValue: { newSpaceInfo in
                print("the new space was created")
                switch self.value.spaces {

                case .fetching:
                    self.value.spaces = .fetched([newSpaceInfo])
                case .fetched(let fetchedSpaces):
                    var copy = fetchedSpaces
                    copy.append(newSpaceInfo)
                    spaceSelectionReducer(viewModel: &self.value, action: .createdSpace(newSpaceInfo))
                case .failed(let error):
                    print("error making a space \(error)")
                }
                spaceSelectionReducer(viewModel: &self.value, action: .selectSpace(newSpaceInfo))
                cancellable?.cancel()
            })
    }
    
}
