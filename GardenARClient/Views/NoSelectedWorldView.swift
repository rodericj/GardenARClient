//
//  NoSelectedWorldView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/13/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct NoSelectedWorldView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        VStack {
            if viewModel.worlds.isEmpty {
                AddWorldButton()
            } else {
                WorldListView()
            }
        }
    }
}

struct NoSelectedWorldView_Previews: PreviewProvider {
    static var previews: some View {
        let bananaWorld = WorldInfo(title: "Banana", id: UUID())
        let appleWorld = WorldInfo(title: "Apple", id: UUID())
        let viewModelWithTwoWorlds = ViewModel(networkClient: NetworkClient())
        viewModelWithTwoWorlds.worlds = [appleWorld, bananaWorld]
        return NoSelectedWorldView().environmentObject(viewModelWithTwoWorlds)
    }
}
