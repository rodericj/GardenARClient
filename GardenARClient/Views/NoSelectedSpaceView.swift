//
//  NoSelectedSpaceView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/13/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct NoSelectedSpaceView: View {
    @EnvironmentObject var store: Store<ViewModel>
    let networkClient: NetworkClient
    var body: some View {
        VStack {
            if store.value.spaces.isEmpty {
                AddItemsButtons()
            } else {
                SpacesListView(networkClient: networkClient)
            }
        }
    }
}

struct NoSelectedSpaceView_Previews: PreviewProvider {
    static var previews: some View {
        let bananaSpace = SpaceInfo(title: "Banana", id: UUID())
        let appleSpace = SpaceInfo(title: "Apple", id: UUID())
        var viewModelWithTwoSpaces = ViewModel()
        viewModelWithTwoSpaces.spaces = [appleSpace, bananaSpace]
        let store = Store<ViewModel>(initialValue: viewModelWithTwoSpaces)
        return NoSelectedSpaceView(networkClient: NetworkClient()).environmentObject(store)
    }
}
