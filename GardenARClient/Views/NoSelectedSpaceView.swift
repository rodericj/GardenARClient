//
//  NoSelectedSpaceView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/13/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct NoSelectedSpaceView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        VStack {
            if viewModel.spaces.isEmpty {
                AddSpaceButton()
            } else {
                SpacesListView()
            }
        }
    }
}

struct NoSelectedSpaceView_Previews: PreviewProvider {
    static var previews: some View {
        let bananaSpace = SpaceInfo(title: "Banana", id: UUID())
        let appleSpace = SpaceInfo(title: "Apple", id: UUID())
        let viewModelWithTwoSpaces = ViewModel(networkClient: NetworkClient())
        viewModelWithTwoSpaces.spaces = [appleSpace, bananaSpace]
        return NoSelectedSpaceView().environmentObject(viewModelWithTwoSpaces)
    }
}
