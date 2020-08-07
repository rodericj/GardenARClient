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
    func setupObservers(arView: ARView)
}


struct ContentView : View {

    @EnvironmentObject var store: Store<ViewModel>
    let sceneDelegate: ARSessionDelegate & HasOptionalARView
    let arViewContainer: ARViewContainer
    var body: some View {
        ZStack {
            arViewContainer.edgesIgnoringSafeArea(.all)
            WithSelectedSpaceView()
        }
        .sheet(isPresented: $store.value.isShowingModalInfoCollectionFlow, onDismiss: {
                self.store.checkModalState()
        }, content: {
            if self.store.value.showingAlert != .none {
                TextInputView(alertType: self.store.value.showingAlert) { name in
                    if !name.isEmpty {
                        switch self.store.value.showingAlert {
                        case .createSpace(_):
                            try? self.store.makeSpace(named: name)
                        case .createMarker(_, let arView, let raycastResult):
                            self.addSign(named: name, at: raycastResult, on: arView)
                        case .none:
                            break
                        }
                    }
                    self.store.value.isShowingModalInfoCollectionFlow = false
                    self.store.value.showingAlert = .none
                }
            }
                // Then we check if we have a selected space
            else if self.store.value.selectedSpace == .none {
                SpacesListView().environmentObject(self.store)
            } else if self.store.value.isShowingPlantInfo {
                PlantInfo().onDisappear {
                    self.store.value.isShowingPlantInfo = false
                }
            } else {
                Text("this isn't supposed to be like this")
            }
        }).onAppear {
            self.store.getSpaces()
        }
    }
}

extension ContentView {

    func addSign(named name: String, at raycastResult: ARRaycastResult?, on  arView: ARView) {
        #if !targetEnvironment(simulator)

        guard let originalSignEntityScene = self.store.value.loadedPlantSignScene else {
            print("There is no original plant sign scene")
            return
        }
        // This is us adding the full scene to the
        guard let clonedPlantSign = self.store.value.loadedPlantSignScene?.plantSignEntityToAttach?.clone(recursive: true) else {
            print("no plant sign entity")
            return
        }
        // TODO ensure that this top part gets added also
//        guard let extraTop = self.store.value.loadedPlantSignScene?.plantSignExtraTop?.clone(recursive: true) else {
//            print("no plant sign entity")
//            return
//        }
        guard let raycastResult = raycastResult else { return }

        let anchorEntity = AnchorEntity(world: raycastResult.worldTransform)
        anchorEntity.name = Scene.AnchorCollection.signAnchorNameIdentifier
        let collisionEntity = PlantSignCollisionEntity(plantSignEntity: clonedPlantSign)
        collisionEntity.addChild(clonedPlantSign)
//        clonedPlantSign.addChild(extraTop)
        anchorEntity.addChild(collisionEntity)

        collisionEntity.generateCollisionShapes(recursive: true)

        // 5. add an occlusion plane to the anchor for when the sign is down below
        //                anchorEntity.addOcclusionBox()

        // 6. Set the sign text
        clonedPlantSign.updatePlantSignName(name: name)

        print("// 7. From Content View add the anchor to the arView")
        arView.scene.addAnchor(anchorEntity)
        let arKitAnchor = ARAnchor(name: "RemoteUUID-\(UUID().uuidString)", transform: raycastResult.worldTransform)
        store.value.pendingAnchorEntityLookup[arKitAnchor] = (anchorEntity, name)
        arView.session.add(anchor: arKitAnchor)
        #endif

        // Set us back to the not isAddingSign state
        store.value.isAddingSign = false

        let notifications = originalSignEntityScene.notifications
        let overrides = [originalSignEntityScene.name: clonedPlantSign]
//        notifications.lookAtCamera.post(overrides: overrides)

    }

    func addAnchor(anchorName: String, anchorID: UUID, worldData: Data) throws {
        guard case let SelectedSpaceInfoIsSet.space(currentSelectedSpace) = store.value.selectedSpace else {
            print("we have no selected space")
            throw ViewModelError.noSpaceSelected
        }
        print("ViewModel:AddAnchor We have a space selected, so send the anchor \(anchorID) \(anchorName) to the network client")
        var cancellable: AnyCancellable?
        cancellable = try store.update(space: currentSelectedSpace,
                                       anchorID: anchorID,
                                       anchorName: anchorName,
                                       worldMapData: worldData).sink(receiveCompletion: { error in

                                       }, receiveValue: { anchor in
                                        print("ViewModel:AddAnchor just saved this anchor \(anchor) with id: \(anchor.id?.uuidString ?? "No ID set for this anchor")")
                                        guard case var SelectedSpaceInfoIsSet.space(currentSelectedSpace) = self.store.value.selectedSpace else {
                                            print("we have no selected space")
                                            return
                                        }
                                        currentSelectedSpace.anchors?.append(anchor)
                                        cancellable?.cancel()
                                       })
    }


}
final class ARViewContainer: UIViewRepresentable {
    let store: Store<ViewModel>
    let sceneDelegate: ARSessionDelegate & HasOptionalARView
    var sceneObserver: Cancellable!
    var anchorStateChangeObserver: Cancellable!
    let arView = ARView(frame: .zero)

    init(sceneDelegate: ARSessionDelegate & HasOptionalARView, store: Store<ViewModel>) {
        self.sceneDelegate = sceneDelegate
        self.store = store
        self.store.value.arView = arView
    }

    func makeUIView(context: Context) -> ARView {
        #if !targetEnvironment(simulator)
        arView.session.delegate = sceneDelegate
        sceneDelegate.tapGestureSetup()
        sceneDelegate.setupObservers(arView: arView)
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
    func setupObservers(arView: ARView) {

    }

    func tapGestureSetup() {
    }
}
struct ContentView_Previews : PreviewProvider {

    private class DummyDelegate: NSObject, ARSessionDelegate, HasOptionalARView {
        func tapGestureSetup() {

        }

        func setupObservers(arView: ARView) {

        }


    }
    static var previews: some View {

        var viewModelWithSelected = ViewModel()
        let storeSelected = Store<ViewModel>(initialValue: viewModelWithSelected, networkClient: NetworkClient())
        spaceSelectionReducer(viewModel: &viewModelWithSelected, action: .selectSpace(SpaceInfo(title: "Banana", id: UUID())))

        let viewModelWithoutSelected = ViewModel()
        let storeWithoutSelected = Store<ViewModel>(initialValue: viewModelWithoutSelected, networkClient: NetworkClient())

        var viewModelShowingAlert = ViewModel()
        viewModelShowingAlert.showingAlert = .createMarker("Hello there", ARView(), nil)
        let storeShowingAlert = Store<ViewModel>(initialValue: viewModelShowingAlert, networkClient: NetworkClient())

        let viewModelShowingListNoAlert = ViewModel()
        let storeShowingListNoAlert = Store<ViewModel>(initialValue: viewModelShowingListNoAlert, networkClient: NetworkClient())

        var viewModelShowingListAndAlert = ViewModel()
        viewModelShowingListAndAlert.selectedSpace = .none
        viewModelShowingListAndAlert.spaces = .fetched([SpaceInfo(title: "Banana", id: UUID())])
        viewModelShowingListAndAlert.showingAlert = .createMarker("Hello there", ARView(), nil)
        let storeShowingListAndAlert = Store<ViewModel>(initialValue: viewModelShowingListAndAlert, networkClient: NetworkClient())

        let arViewContainer = ARViewContainer(sceneDelegate: DummyDelegate(), store: storeShowingListAndAlert)
        return Group {
            ContentView(sceneDelegate: TestARSession(), arViewContainer: arViewContainer).environmentObject(storeSelected)
            ContentView(sceneDelegate: TestARSession(), arViewContainer: arViewContainer).environmentObject(storeWithoutSelected)
            ContentView(sceneDelegate: TestARSession(), arViewContainer: arViewContainer).environmentObject(storeShowingAlert)
            ContentView(sceneDelegate: TestARSession(), arViewContainer: arViewContainer).environmentObject(storeShowingListNoAlert)
            ContentView(sceneDelegate: TestARSession(), arViewContainer: arViewContainer).environmentObject(storeShowingListAndAlert)
            ContentView(sceneDelegate: TestARSession(), arViewContainer: arViewContainer).environmentObject(storeShowingListAndAlert).environment(\.colorScheme, .dark)

        }
    }
}
#endif
