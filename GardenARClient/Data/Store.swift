//
//  Store.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 8/3/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation

final class Store<Value>: ObservableObject {
    @Published var value: Value
    let networkClient: NetworkClient
    init(initialValue: Value, networkClient: NetworkClient) {
        self.value = initialValue
        self.networkClient = networkClient
    }
}

enum SelectedSpaceAction {
    case selectSpace(SpaceInfo)
    case clearSpace
}

func spaceSelectionReducer( viewModel: inout ViewModel, action: SelectedSpaceAction) {
    switch action {

    case .selectSpace(let space):
        viewModel.selectedSpace = SelectedSpaceInfoIsSet.space(space)
        break
    case .clearSpace:
        viewModel.selectedSpace = .none
        break
    }
}
