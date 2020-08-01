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
            if !viewModel.isAddingSign {
                AddItemsButtons()
            } else {
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
                            self.viewModel.isAddingSign = false
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
            }
            VStack {
                Button(action: {
                    self.viewModel.selectedSpace = nil
                }) {
                    CTAButtonView(title: "Space: \(viewModel.selectedSpace?.title ?? "")")
                }
                Button(action: {
                    self.viewModel.saveTheWorld()
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
        let viewModelWithTwoSpaces = ViewModel(networkClient: NetworkClient())
        viewModelWithTwoSpaces.selectedSpace = appleSpace
        viewModelWithTwoSpaces.spaces = [appleSpace, bananaSpace]

        let viewModelWithOneSpaceIsAddingSign = ViewModel(networkClient: NetworkClient())
        viewModelWithOneSpaceIsAddingSign.selectedSpace = bananaSpace
        viewModelWithOneSpaceIsAddingSign.spaces = [bananaSpace]
        viewModelWithOneSpaceIsAddingSign.isAddingSign = true

        let viewModelWithOneSpace = ViewModel(networkClient: NetworkClient())
               viewModelWithOneSpace.selectedSpace = bananaSpace
               viewModelWithOneSpace.spaces = [bananaSpace]

        return Group {
//            WithSelectedSpaceView().environmentObject(viewModelWithTwoSpaces)
            WithSelectedSpaceView().environmentObject(viewModelWithOneSpace)
            WithSelectedSpaceView().environmentObject(viewModelWithOneSpaceIsAddingSign)
        }
    }
}
