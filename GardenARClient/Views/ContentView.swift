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

    @ObservedObject var viewModel: ViewModel
    var body: some View {
        return ZStack {
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
            if viewModel.selectedWorld == nil {
                if viewModel.worlds.isEmpty {
                    AddWorldButton(viewModel: viewModel)
                } else {
                    WorldListView(viewModel: viewModel)
                }
            } else {
                if viewModel.selectedWorld != nil {
                    Text(viewModel.selectedWorld!.title)
                    Text(viewModel.selectedWorld!.title)
                    Spacer()
                }
                AddWorldButton(viewModel: viewModel)
            }
        }
        .onAppear(perform: viewModel.getWorlds)
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
        let client = NetworkClient()
        return Group {
            ContentView(viewModel: ViewModel(networkClient: client))
            ContentView(viewModel: ViewModel(networkClient: client))
        }
    }
}
#endif
