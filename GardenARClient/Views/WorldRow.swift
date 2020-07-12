//
//  WorldRow.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine
struct WorldRow: View {
    let worldInfo: WorldInfo
    @Binding var selected: WorldInfo?

    var body: some View {
        Button(action: {
            print("Select this world")
            self.selected = self.worldInfo
        }) {
            Text(worldInfo.title)
        }
    }
}

//struct WorldRow_Previews: PreviewProvider {
//
//    static var previews: some View {
//        let network = NetworkClient()
//        let myWorldInfo = WorldInfo(title: "Backyard", id: UUID())
//        let viewModel = ViewModel(networkClient: network)
//        return WorldRow(worldInfo: myWorldInfo, selected: viewModel.selectedWorld)
//    }
//}
