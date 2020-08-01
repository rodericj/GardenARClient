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

// This may not be necessary anymore now that view model has the arview
protocol HasOptionalARView {
    func tapGestureSetup()
    func updateWithEntity(entity: HasAnchoring)
}


struct ContentView : View {

    @EnvironmentObject var viewModel: ViewModel
   
    let sceneDelegate: ARSessionDelegate & HasOptionalARView
    var body: some View {
        ZStack {
            ARViewContainer(sceneDelegate: sceneDelegate, viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            if viewModel.selectedSpace == nil {
                NoSelectedSpaceView()
            } else {
                WithSelectedSpaceView()
            }
            containedView()
        }
        .popover(isPresented: $viewModel.isShowingPlantInfo, attachmentAnchor: .point(.bottomTrailing), arrowEdge: .bottom) {
            PlantInfo()
        }
    }

    func containedView() -> AnyView? {
        switch viewModel.showingAlert {

        case .none:
            return nil
        case .createSpace(_):
            return  AnyView(
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .edgesIgnoringSafeArea(.all)
                    AlertView(alertType: viewModel.showingAlert)
                }
            )
        case .createMarker(_, _, _):
            return AnyView(
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .edgesIgnoringSafeArea(.all)
                    AlertView(alertType: viewModel.showingAlert)
                }
            )
        }
    }
}

final class ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    let sceneDelegate: ARSessionDelegate & HasOptionalARView
    var sceneObserver: Cancellable!
    var anchorStateChangeObserver: Cancellable!

    init(sceneDelegate: ARSessionDelegate & HasOptionalARView, viewModel: ViewModel) {
        self.sceneDelegate = sceneDelegate
        self.viewModel = viewModel
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        viewModel.arView = arView
        #if !targetEnvironment(simulator)
        arView.session.delegate = sceneDelegate
        sceneDelegate.tapGestureSetup()
        #endif
//        arView.addCoaching()
        return arView
    }

    // MARK: - Gesture recognizer callbacks

    func updateUIView(_ uiView: ARView, context: Context) {}
}
extension ARView: ARCoachingOverlayViewDelegate {
    func addCoaching() {

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.delegate = self
        #if !targetEnvironment(simulator)

        coachingOverlay.session = self.session
        #endif
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.goal = .tracking
        self.addSubview(coachingOverlay)
    }

    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        //Ready to add entities next?
    }
}

#if DEBUG
class TestARSession: NSObject, ARSessionDelegate, HasOptionalARView {
    func updateWithEntity(entity: HasAnchoring) {
        
    }

    func tapGestureSetup() {
    }

    var arView: ARView?
}
struct ContentView_Previews : PreviewProvider {

    static var previews: some View {
        let viewModelWithSelected = ViewModel(networkClient: NetworkClient())
        viewModelWithSelected.selectedSpace = SpaceInfo(title: "Banana", id: UUID())

        let viewModelWithOutSelected = ViewModel(networkClient: NetworkClient())

        let viewModelShowingAlert = ViewModel(networkClient: NetworkClient())
        viewModelShowingAlert.showingAlert = .createMarker("Hello there", ARView(), nil)

        let viewModelShowingListNoAlert = ViewModel(networkClient: NetworkClient())
        viewModelShowingListNoAlert.selectedSpace = nil

        let viewModelShowingListAndAlert = ViewModel(networkClient: NetworkClient())
        viewModelShowingListAndAlert.selectedSpace = nil
        viewModelShowingListAndAlert.spaces = [SpaceInfo(title: "Banana", id: UUID())]
        viewModelShowingListAndAlert.showingAlert = .createMarker("Hello there", ARView(), nil)

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
