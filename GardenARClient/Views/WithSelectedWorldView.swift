//
//  WithSelectedWorldView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/13/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct WithSelectedWorldView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        ZStack {
            AddWorldButton()
            VStack {
                Button(action: {
                    self.viewModel.selectedWorld = nil
                }) {
                    Text("World: \(viewModel.selectedWorld?.title ?? "")")
                        .fontWeight(.heavy)
                        .font(.title)
                        .padding()
                        .foregroundColor(.black)
                        .background(Color.white)
                        .cornerRadius(40)
                }
                Spacer()
            }
        }
    }
}

struct WithSelectedWorldView_Previews: PreviewProvider {
    static var previews: some View {
        let bananaWorld = WorldInfo(title: "Banana", id: UUID())
        let appleWorld = WorldInfo(title: "Apple", id: UUID())
        let viewModelWithTwoWorlds = ViewModel(networkClient: NetworkClient())
        viewModelWithTwoWorlds.selectedWorld = appleWorld
        viewModelWithTwoWorlds.worlds = [appleWorld, bananaWorld]

        let viewModelWithOneWorld = ViewModel(networkClient: NetworkClient())
        viewModelWithOneWorld.selectedWorld = bananaWorld
        viewModelWithOneWorld.worlds = [bananaWorld]

        return Group {
            WithSelectedWorldView().environmentObject(viewModelWithTwoWorlds)
            WithSelectedWorldView().environmentObject(viewModelWithOneWorld)
        }
    }
}
