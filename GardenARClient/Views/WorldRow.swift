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
    @EnvironmentObject var viewModel: ViewModel
    var body: some View {
        Button(action: {
            print("🌎 Select world \(self.worldInfo.title)")
            self.viewModel.get(world: self.worldInfo)
            self.selected = self.worldInfo
        }) {
            VStack(alignment: .leading) {
                Text(worldInfo.title).font(.largeTitle).autocapitalization(.words)
                Spacer()
                Text("\(worldInfo.anchors?.count ?? 0) Anchors").font(.body)
            }
        }
    }
}

//struct WorldRow_Previews: PreviewProvider {
//
//    static var previews: some View {
//        let network = NetworkClient()
//        let myWorldInfo = WorldInfo(title: "Backyard", id: UUID())
//        let viewModel = ViewModel(networkClient: network)
//        return WorldRow(worldInfo: myWorldInfo)
//    }
//}
