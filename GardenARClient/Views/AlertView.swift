//
//  AlertView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/21/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine
import ARKit
import RealityKit
enum TextInputType: Equatable {

    case none
    case createSpace(String)
    case createMarker(String, ARView, ARRaycastResult?)

    var title: String {
        get {
            switch self {
            case .createMarker(let title, _, _):
                return title
            case .createSpace(let title):
                return title
            case .none:
                return ""
            }
        }
    }
}

struct TextInputView: View {
    @State var enteredText: String = ""
    let alertType: TextInputType
    @EnvironmentObject var store: Store<ViewModel>
    @Environment(\.presentationMode) var presentationMode
    let completion: (String) -> ()
    var body: some View {
        VStack {
            Spacer().frame(width: 0, height: 20, alignment: .center)
            Text(alertType.title)//.foregroundColor(.accentColor)

            TextField("Backyard", text: $enteredText)
                .foregroundColor(.primary)
                .padding(5)
                .border(Color.primary)
                .padding(10)
            HStack {
                Button(action: {
                    self.store.value.isShowingModalInfoCollectionFlow = false // TODO use a reducer here
                }) {
                    Text("Cancel")
                        .padding()
                        .frame(width: 100, height: nil, alignment: .center)
                        .background(Color.primary).colorInvert()
                        .foregroundColor(.red)
                        .cornerRadius(5)
                }.padding(10)
                Button(action: {
                    self.completion(self.enteredText)
                }) {
                    Text("Ok")
                        .padding()
                        .frame(width: 100, height: nil, alignment: .center)
                        .background(Color.primary).colorInvert()
                        .cornerRadius(5)
                }.padding(10)
            }
            Spacer()
        }
    }

}

struct AlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TextInputView(alertType: .createMarker("Enter new name: Light Mode", ARView(), nil), completion: { _ in }).environment(\.colorScheme, .light).background(Color.white)
            TextInputView(alertType: .createMarker("Enter new Space Name: Dark Mode", ARView(), nil), completion: { _ in }).environment(\.colorScheme, .dark).background(Color.black)
        }
    }
}
