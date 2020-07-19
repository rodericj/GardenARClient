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
            if viewModel.selectedWorld == nil {
                NoSelectedWorldView()
            } else {
               WithSelectedWorldView()
            }

        }
        .onAppear(perform: viewModel.getWorlds)
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
        // Load the "Box" scene from the "Experience" Reality File
        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor)
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
        viewModelWithSelected.selectedWorld = WorldInfo(title: "Banana", id: UUID())

        let viewModelWithOutSelected = ViewModel(networkClient: NetworkClient())

        return Group {
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelWithOutSelected)
            ContentView(sceneDelegate: TestARSession()).environmentObject(viewModelWithSelected)
        }
    }
}
#endif
