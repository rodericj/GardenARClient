//
//  AddSpaceButton.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine

struct AddItemsButtons: View {
    @EnvironmentObject var store: Store<ViewModel>
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        VStack {
            Spacer()
            HStack {
                if store.value.selectedSpace == .none {
                    Button(action: {
                        self.store.value.showingAlert = .createSpace("Add a new Space") // TODO use a reducer here
                    }) {
                        CTAButtonView(title: "+ Space")
                    }
                }
                if store.value.shouldShowAddSignButton {
                    Button(action: {
                        self.store.value.isAddingSign = true // TODO use a reducer here
                    }) {
                        CTAButtonView(title: "+ Sign")
                    }

                }
            }
        }.padding()
    }
}

struct AddSpaceButton_Previews: PreviewProvider {
    static var previews: some View {
        var viewModel = ViewModel()
        let bananaSpace = SpaceInfo(title: "Banana", id: UUID())
        let store = Store<ViewModel>(initialValue: viewModel, networkClient: NetworkClient())
        viewModel.selectedSpace = .space(bananaSpace)
        return AddItemsButtons().environmentObject(store)
    }
}
