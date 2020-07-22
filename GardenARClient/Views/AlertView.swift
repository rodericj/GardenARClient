//
//  AlertView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/21/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine

struct AlertView: View {
    @State var enteredText: String = ""
    @EnvironmentObject var viewModel: ViewModel
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        return VStack {
            Spacer()
            VStack {
                Spacer().frame(width: 0, height: 20, alignment: .center)
                Text("Enter new Space Name").foregroundColor(.accentColor)

                TextField("Backyard", text: $enteredText)
                    .foregroundColor(.primary).colorInvert()
                    .frame(idealWidth: 200,
                           maxWidth: 250,
                           idealHeight: 200,
                           alignment: .center)
                    .padding(5)
                    .background(Color.secondary)
                    .border(Color.primary)
                    .padding(10)
                HStack {
                    Button(action: {
                        self.viewModel.showingAlert = .notShowing
                    }) {
                        Text("Cancel")
                            .padding()
                            .frame(width: 100, height: nil, alignment: .center)
                            .background(Color.secondary)
                            .foregroundColor(.red)
                            .cornerRadius(5)
                    }.padding(10)
                    Button(action: {
                        print("ok")
                        try? self.viewModel.makeSpace(named: self.enteredText)
                        self.viewModel.showingAlert = .notShowing
                    }) {
                        Text("Ok")
                            .padding()
                            .frame(width: 100, height: nil, alignment: .center)
                            .background(Color.secondary)
                            .cornerRadius(5)
                    }.padding(10)
                    Spacer().frame(width: 0, height: 20, alignment: .center)
                }
            }
            .padding(10)
            .background(Color.primary)
            .cornerRadius(10)
            .shadow(radius: 10)
            .padding(.bottom, keyboardHeight)
                       .onReceive(Publishers.keyboardHeight) { self.keyboardHeight = $0 }
            Spacer()


        }
    }
}

struct AlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AlertView().environment(\.colorScheme, .light)
            AlertView().environment(\.colorScheme, .dark)
        }
    }
}
