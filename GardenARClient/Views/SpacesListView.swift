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
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(store.value.spaces.all) { space in
                        SpaceRow(spaceInfo: space, selected: self.$store.value.selectedSpace)
                    }.onDelete(perform: delete)
                }.onAppear {
                    self.store.getSpaces()
                }
                AddItemsButtons()
            }.navigationBarTitle(Text("Available Spaces"))
        }
    }

    func delete(at offsets: IndexSet) {
        store.deleteSpace(at: offsets)
    }
}


struct SpacesListView_Previews: PreviewProvider {
    static var previews: some View {
        var viewModel = ViewModel()
        viewModel.spaces = .fetched([SpaceInfo(title: "banana", id: UUID()),
                                     SpaceInfo(title: "some other space", id: UUID())])
        let store = Store<ViewModel>(initialValue: viewModel, networkClient: NetworkClient())
        return SpacesListView().environmentObject(store)
    }
}
