//
//  ContentView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/10/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import ARKit
import SwiftUI
import RealityKit
import Combine

protocol HasOptionalARView {
    var arView: ARView? { get set }
}

struct ContentView : View {

    @EnvironmentObject var viewModel: ViewModel
    let sceneDelegate: ARSessionDelegate & HasOptionalARView
    var body: some View {
        return ZStack {
            ARViewContainer(sceneDelegate: sceneDelegate)
                .edgesIgnoringSafeArea(.all)
            if viewModel.selectedSpace == nil {
                NoSelectedSpaceView()
            } else {
               WithSelectedSpaceView()
            }
            if viewModel.showingAlert != .notShowing {
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .edgesIgnoringSafeArea(.all)
                    AlertView()
                }
            }
        }
        .onAppear(perform: viewModel.getSpaces)
    }
}

final class ARViewContainer: UIViewRepresentable {
    var sceneDelegate: ARSessionDelegate & HasOptionalARView

    init(sceneDelegate: ARSessionDelegate & HasOptionalARView) {
        self.sceneDelegate = sceneDelegate
    }

    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        sceneDelegate.arView = arView
        arView.session.delegate = sceneDelegate
        arView.tapGestureSetup()
        return arView
    }

    // MARK: - Gesture recognizer callbacks

    func updateUIView(_ uiView: ARView, context: Context) {}
}

#if DEBUG
class TestARSession: NSObject, ARSessionDelegate, HasOptionalARView {
    var arView: ARView?
}
struct ContentView_Previews : PreviewProvider {

    static var previews: some View {
        let viewModelWithSelected = ViewModel(networkClient: NetworkClient())
        viewModelWithSelected.selectedSpace = SpaceInfo(title: "Banana", id: UUID())

        let viewModelWithOutSelected = ViewModel(networkClient: NetworkClient())

        let viewModelShowingAlert = ViewModel(networkClient: NetworkClient())
        viewModelShowingAlert.showingAlert = .showing("Hello there")

        let viewModelShowingListNoAlert = ViewModel(networkClient: NetworkClient())
        viewModelShowingListNoAlert.selectedSpace = nil

        let viewModelShowingListAndAlert = ViewModel(networkClient: NetworkClient())
        viewModelShowingListAndAlert.selectedSpace = nil
        viewModelShowingListAndAlert.spaces = [SpaceInfo(title: "Banana", id: UUID())]
        viewModelShowingListAndAlert.showingAlert = .showing("Hello there")

        return Group {
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelWithOutSelected)
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelWithSelected)
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelShowingAlert)
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelShowingListNoAlert)
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelShowingListAndAlert)
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelShowingListAndAlert).environment(\.colorScheme, .dark)
        }
    }
}
#endif
