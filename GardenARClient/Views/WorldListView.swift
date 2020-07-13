//
//  WorldListView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct WorldListView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        List {
            ForEach(viewModel.worlds) { world in
                WorldRow(worldInfo: world, selected: self.$viewModel.selectedWorld)
            }.onDelete(perform: delete)
        }.onAppear(perform: viewModel.getWorlds)
    }

    func delete(at offsets: IndexSet) {
        viewModel.deleteWorld(at: offsets)
    }
}

struct WorldListView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ViewModel(networkClient: NetworkClient())
        return WorldListView().environmentObject(viewModel)
    }
}
