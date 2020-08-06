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
                    NavigationLink(destination: TextInputView(alertType: TextInputType.createSpace("Add a new space"), completion: { newSpaceName in
                        try? self.store.makeSpace(named: newSpaceName)
                    }), label: {
                        Text("New Space")
                    })
                    ForEach(store.value.spaces.all) { space in
                        SpaceRow(spaceInfo: space, selected: self.$store.value.selectedSpace)
                    }.onDelete(perform: delete)
                }
            }.navigationBarTitle(Text("Available Spaces"))
                .navigationBarItems(trailing:
                    Button(action: {
                        self.store.getSpaces()
                    }) {
                        Image(systemName: "gobackward")
                    }
            )
        }
    }

    func delete(at offsets: IndexSet) {
        store.deleteSpace(at: offsets)
    }
}


struct SpacesListView_Previews: PreviewProvider {
    static var previews: some View {
        var viewModel = ViewModel()
        viewModel.spaces = .fetched([SpaceInfo(title: "Banana", id: UUID()),
                                     SpaceInfo(title: "Some other space", id: UUID())])
        let store = Store<ViewModel>(initialValue: viewModel, networkClient: NetworkClient())
        return SpacesListView().environmentObject(store)
    }
}
