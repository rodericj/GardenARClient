//
//  WithSelectedSpaceView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/13/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct WithSelectedSpaceView: View {
    @EnvironmentObject var store: Store<ViewModel>

    var body: some View {
        ZStack {
            if store.value.isAddingSign {
                VStack {
                    Spacer()
                    HStack {
                        Text("Tap somewhere to add a Sign")
                            .font(.body)
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.orange)
                            .cornerRadius(40)
                            .shadow(radius: 10)
                        Button(action: {
                            self.store.value.isAddingSign = false
                        }) {
                            Text("Cancel")
                                .font(.body)
                                .padding()
                                .foregroundColor(.red)
                                .background(Color.white)
                                .cornerRadius(40)
                                .shadow(radius: 10)
                        }
                    }.padding()
                }
            } else if store.value.selectedSpace != .none {
                AddItemsButtons()
            }
            VStack {
                Button(action: {
                    self.store.value.selectedSpace = .none
                }) {
                    if self.store.value.selectedSpace != .none {
                        CTAButtonView(title: store.value.selectedSpace.title)
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
        var viewModelWithTwoSpaces = ViewModel()
        viewModelWithTwoSpaces.selectedSpace = .space(appleSpace)
        viewModelWithTwoSpaces.spaces = .fetched([appleSpace, bananaSpace])
        let storeWithTwoSpaces = Store<ViewModel>(initialValue: viewModelWithTwoSpaces, networkClient: NetworkClient())

        var viewModelWithOneSpaceIsAddingSign = ViewModel()
        viewModelWithOneSpaceIsAddingSign.selectedSpace = .space(bananaSpace)
        viewModelWithOneSpaceIsAddingSign.spaces = .fetched([bananaSpace])
        viewModelWithOneSpaceIsAddingSign.isAddingSign = true
        let storeWithOneSpaceIsAdding = Store<ViewModel>(initialValue: viewModelWithOneSpaceIsAddingSign, networkClient: NetworkClient())

        var viewModelWithOneSpace = ViewModel()
        viewModelWithOneSpace.selectedSpace = .space(bananaSpace)
        viewModelWithOneSpace.spaces = .fetched([bananaSpace])
        let storeWithOneSpace = Store<ViewModel>(initialValue: viewModelWithOneSpace, networkClient: NetworkClient())

        return Group {
            WithSelectedSpaceView().environmentObject(storeWithTwoSpaces)
            WithSelectedSpaceView().environmentObject(storeWithOneSpaceIsAdding)
            WithSelectedSpaceView().environmentObject(storeWithOneSpace)

        }
    }
}
