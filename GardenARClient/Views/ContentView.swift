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

    @EnvironmentObject var store: Store<ViewModel>
    let sceneDelegate: ARSessionDelegate & HasOptionalARView
    let networkClient: NetworkClient
    var body: some View {
        ZStack {
            ARViewContainer(sceneDelegate: sceneDelegate, store: store)
                .edgesIgnoringSafeArea(.all)
            WithSelectedSpaceView()
            // The alert view workaround. This could be it's own view in a popover. It's cleaner
            containedView()
        }
        .popover(isPresented: $store.value.isShowingPlantInfo, attachmentAnchor: .point(.bottomTrailing), arrowEdge: .bottom) {
            PlantInfo()
        }
        .popover(isPresented: $store.value.isShowingSpaceSelectionView, attachmentAnchor: .point(.top), arrowEdge: .top) {
            SpacesListView(networkClient: self.networkClient).environmentObject(self.store).frame(width: 300, height: 600)
        }
    }

    func containedView() -> AnyView? {
        switch store.value.showingAlert {

        case .none:
            return nil
        case .createSpace(_):
            return  AnyView(
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .edgesIgnoringSafeArea(.all)
                    AlertView(alertType: store.value.showingAlert, completion: { spaceName in
                        print("the new space name \(spaceName)")
                        try? self.makeSpace(named: spaceName)
                    })
                }
            )
        case .createMarker(_, let arView, let raycastResult):
            return AnyView(
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .edgesIgnoringSafeArea(.all)
                    AlertView(alertType: store.value.showingAlert, completion: { plantName in
                        print("the new plantName name \(plantName)")
                        self.addSign(named: plantName, at: raycastResult, on: arView)
                    })
                }
            )
        }
    }
}

extension ContentView {
    // TODO move network things like this a coordinator between the network and the view model
    private func getSpaces() {
        var cancellable: AnyCancellable?
        cancellable = networkClient.getSpaces
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { value in
                    switch value {
                    case .failure(let error):
                        self.store.value.spaces = .failed(error)
                    case .finished:
                        break
                    }
                },
                receiveValue: { spaces in
                    self.store.value.spaces = .fetched(spaces)
                    cancellable?.cancel()
            })

    }

    func makeSpace(named name: String) throws {
        var cancellable: AnyCancellable?
        cancellable = try networkClient.makeSpace(named: name)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    print("finished making space")
                case .failure(let errorWithLocalizedDescription):
                    print("🔴 Error in fetching \(errorWithLocalizedDescription.localizedDescription)")
                }
            }, receiveValue: { newSpaceInfo in
                print("the new space was created")
                switch self.store.value.spaces {

                case .fetching:
                    self.store.value.spaces = .fetched([newSpaceInfo])
                case .fetched(let fetchedSpaces):
                    var copy = fetchedSpaces
                    copy.append(newSpaceInfo)
                    self.store.value.spaces = .fetched(copy)
                case .failed(let error):
                    print("error making a space \(error)")
                }
                self.store.value.selectedSpace = .space(newSpaceInfo)
                cancellable?.cancel()
            })
    }

    func addSign(named name: String, at raycastResult: ARRaycastResult?, on  arView: ARView) {
        #if !targetEnvironment(simulator)

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
    }

    func addAnchor(anchorName: String, anchorID: UUID, worldData: Data) throws {
        guard case let SelectedSpaceInfoIsSet.space(currentSelectedSpace) = store.value.selectedSpace else {
            print("we have no selected space")
            throw ViewModelError.noSpaceSelected
        }
        print("ViewModel:AddAnchor We have a space selected, so send the anchor \(anchorID) \(anchorName) to the network client")
        var cancellable: AnyCancellable?
        cancellable = try networkClient.update(space: currentSelectedSpace,
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

    init(sceneDelegate: ARSessionDelegate & HasOptionalARView, store: Store<ViewModel>) {
        self.sceneDelegate = sceneDelegate
        self.store = store
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        store.value.arView = arView
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
}
struct ContentView_Previews : PreviewProvider {

    static var previews: some View {
        var viewModelWithSelected = ViewModel()
        viewModelWithSelected.selectedSpace = .space(SpaceInfo(title: "Banana", id: UUID()))
        let storeSelected = Store<ViewModel>(initialValue: viewModelWithSelected)

        let viewModelWithoutSelected = ViewModel()
        let storeWithoutSelected = Store<ViewModel>(initialValue: viewModelWithoutSelected)

        var viewModelShowingAlert = ViewModel()
        viewModelShowingAlert.showingAlert = .createMarker("Hello there", ARView(), nil)
        let storeShowingAlert = Store<ViewModel>(initialValue: viewModelShowingAlert)

        var viewModelShowingListNoAlert = ViewModel()
        viewModelShowingListNoAlert.selectedSpace = .none
        let storeShowingListNoAlert = Store<ViewModel>(initialValue: viewModelShowingListNoAlert)

        var viewModelShowingListAndAlert = ViewModel()
        viewModelShowingListAndAlert.selectedSpace = .none
        viewModelShowingListAndAlert.spaces = .fetched([SpaceInfo(title: "Banana", id: UUID())])
        viewModelShowingListAndAlert.showingAlert = .createMarker("Hello there", ARView(), nil)
        let storeShowingListAndAlert = Store<ViewModel>(initialValue: viewModelShowingListAndAlert)

        return Group {
            ContentView(sceneDelegate: TestARSession(), networkClient: NetworkClient()).environmentObject(storeSelected)
            ContentView(sceneDelegate: TestARSession(), networkClient: NetworkClient()).environmentObject(storeWithoutSelected)
            ContentView(sceneDelegate: TestARSession(), networkClient: NetworkClient()).environmentObject(storeShowingAlert)
            ContentView(sceneDelegate: TestARSession(), networkClient: NetworkClient()).environmentObject(storeShowingListNoAlert)
            ContentView(sceneDelegate: TestARSession(), networkClient: NetworkClient()).environmentObject(storeShowingListAndAlert)
            ContentView(sceneDelegate: TestARSession(), networkClient: NetworkClient()).environmentObject(storeShowingListAndAlert).environment(\.colorScheme, .dark)

        }
    }
}
#endif
