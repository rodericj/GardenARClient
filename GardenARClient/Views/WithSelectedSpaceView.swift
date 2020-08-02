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
            } else {
                AddItemsButtons()
            }
            VStack {
                Button(action: {
                    self.store.value.selectedSpace = nil
                }) {
                    CTAButtonView(title: "Space: \(store.value.selectedSpace?.title ?? "")")
                }
                Button(action: {
                    self.store.value.saveTheWorld()
                    print("save world")
                }) {
                    Text("Save the world")
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
        viewModelWithTwoSpaces.selectedSpace = appleSpace
        viewModelWithTwoSpaces.spaces = [appleSpace, bananaSpace]
        let storeWithTwoSpaces = Store<ViewModel>(initialValue: viewModelWithTwoSpaces)

        var viewModelWithOneSpaceIsAddingSign = ViewModel()
        viewModelWithOneSpaceIsAddingSign.selectedSpace = bananaSpace
        viewModelWithOneSpaceIsAddingSign.spaces = [bananaSpace]
        viewModelWithOneSpaceIsAddingSign.isAddingSign = true
        let storeWithOneSpaceIsAdding = Store<ViewModel>(initialValue: viewModelWithOneSpaceIsAddingSign)

        var viewModelWithOneSpace = ViewModel()
        viewModelWithOneSpace.selectedSpace = bananaSpace
        viewModelWithOneSpace.spaces = [bananaSpace]
        let storeWithOneSpace = Store<ViewModel>(initialValue: viewModelWithOneSpace)

        return Group {
            WithSelectedSpaceView().environmentObject(storeWithTwoSpaces)
            WithSelectedSpaceView().environmentObject(storeWithOneSpaceIsAdding)
            WithSelectedSpaceView().environmentObject(storeWithOneSpace)

        }
    }
}
