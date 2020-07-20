//
//  SpacesListView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct SpacesListView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.spaces) { space in
                    SpaceRow(spaceInfo: space, selected: self.$viewModel.selectedSpace)
                }.onDelete(perform: delete)
            }.onAppear(perform: viewModel.getSpaces)
            AddSpaceButton()
        }
    }

    func delete(at offsets: IndexSet) {
        viewModel.deleteSpace(at: offsets)
    }
}

struct SpacesListView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ViewModel(networkClient: NetworkClient())
        viewModel.spaces = [SpaceInfo(title: "banana", id: UUID()),
                            SpaceInfo(title: "some other space", id: UUID())]
        return SpacesListView().environmentObject(viewModel)
    }
}
