//
//  SpacesListView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine

struct SpacesListView: View {
    @EnvironmentObject var store: Store<ViewModel>
    let networkClient: NetworkClient
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(store.value.spaces.all) { space in
                        SpaceRow(spaceInfo: space, selected: self.$store.value.selectedSpace, networkClient: self.networkClient)
                    }.onDelete(perform: delete)
                }.onAppear(perform: getSpaces)
                AddItemsButtons()
            }.navigationBarTitle(Text("Available Spaces"))
        }
    }

    func delete(at offsets: IndexSet) {
        deleteSpace(at: offsets)
    }
}

extension SpacesListView {
    func deleteSpace(at offsets: IndexSet) {
        try? offsets.map { store.value.spaces.all[$0].id }.forEach { uuid in
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
    func getSpaces() {
        var cancellable: AnyCancellable?
        cancellable = networkClient.getSpaces
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { value in
                    switch value {
                    case .failure(let error):
                        self.store.value.spaces = .failed(error)
                    case .finished:
                        break
                    }
                },
                receiveValue: { spaces in
                    self.store.value.spaces = .fetched(spaces)
                    cancellable?.cancel()
            })
    }
}

struct SpacesListView_Previews: PreviewProvider {
    static var previews: some View {
        var viewModel = ViewModel()
        viewModel.spaces = .fetched([SpaceInfo(title: "banana", id: UUID()),
                                     SpaceInfo(title: "some other space", id: UUID())])
        let store = Store<ViewModel>(initialValue: viewModel)
        return SpacesListView(networkClient: NetworkClient()).environmentObject(store)
    }
}
