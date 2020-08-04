//
//  SpaceRow.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine
struct SpaceRow: View {
    let spaceInfo: SpaceInfo
    @Binding var selected: SelectedSpaceInfoIsSet
    @EnvironmentObject var store: Store<ViewModel>

    var body: some View {
        Button(action: {
            print("🌎 Select space \(self.spaceInfo.title)")
            self.store.get(space: self.spaceInfo)
            self.selected = .space(self.spaceInfo)
        }) {
            VStack(alignment: .leading) {
                Text(spaceInfo.title).font(.largeTitle).autocapitalization(.words)
                Spacer()
                Text("\(spaceInfo.anchors?.count ?? 0) Anchors").font(.body)
            }
        }
    }
}

//struct SpaceRow_Previews: PreviewProvider {
//
//    static var previews: some View {
//        let network = NetworkClient()
//        let mySpaceInfo = SpaceInfo(title: "Backyard", id: UUID())
//        let viewModel = ViewModel(networkClient: network)
//        return SpaceRow(spaceInfo: mySpaceInfo)
//    }
//}
