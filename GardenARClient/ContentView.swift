//
//  ContentView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/10/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import RealityKit
import Combine

struct ContentView : View {
    // This can't be right, but it is fetching, so that's good
    var cancellable = NetworkClient().getWorlds
        .sink(receiveCompletion: { error in
            print("Error is \(error)")
        }, receiveValue: { worlds in
            print("got response \(worlds)")
        })
    
    var body: some View {
        return ARViewContainer()
            .edgesIgnoringSafeArea(.all)
            .onAppear {

        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        
        // Load the "Box" scene from the "Experience" Reality File
        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
