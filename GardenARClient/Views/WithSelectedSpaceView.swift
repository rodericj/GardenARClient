//
//  WithSelectedSpaceView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/13/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct WithSelectedSpaceView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        ZStack {
            AddSpaceButton()
            VStack {
                Button(action: {
                    self.viewModel.selectedSpace = nil
                }) {
                    VStack {
                        CTAButtonView(title: "Space: \(viewModel.selectedSpace?.title ?? "")")
                        Button(action: {
                            self.viewModel.saveTheWorld()
                            print("save world")
                        }) {
                            Text("Save the world")
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

struct WithSelectedSpaceView_Previews: PreviewProvider {
    static var previews: some View {
        let bananaSpace = SpaceInfo(title: "Banana", id: UUID())
        let appleSpace = SpaceInfo(title: "Apple", id: UUID())
        let viewModelWithTwoSpaces = ViewModel(networkClient: NetworkClient())
        viewModelWithTwoSpaces.selectedSpace = appleSpace
        viewModelWithTwoSpaces.spaces = [appleSpace, bananaSpace]

        let viewModelWithOneSpace = ViewModel(networkClient: NetworkClient())
        viewModelWithOneSpace.selectedSpace = bananaSpace
        viewModelWithOneSpace.spaces = [bananaSpace]

        return Group {
            WithSelectedSpaceView().environmentObject(viewModelWithTwoSpaces)
            WithSelectedSpaceView().environmentObject(viewModelWithOneSpace)
        }
    }
}
