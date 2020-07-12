//
//  WorldListView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct WorldListView: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        List(viewModel.worlds) { world in
            WorldRow(worldInfo: world, selected: self.$viewModel.selectedWorld)
        }.onAppear(perform: viewModel.getWorlds)
    }
}

struct WorldListView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ViewModel(networkClient: NetworkClient())
        return WorldListView(viewModel: viewModel)
    }
}
