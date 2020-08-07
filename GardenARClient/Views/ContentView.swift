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

struct ContentView : View {

    @EnvironmentObject var store: Store<ViewModel>
    let sceneDelegate: ARSessionDelegate // TODO We may be able to get rid of this
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

//        let notifications = originalSignEntityScene.notifications
//        let overrides = [originalSignEntityScene.name: clonedPlantSign]
//        notifications.lookAtCamera.post(overrides: overrides)

    }
}
final class ARViewContainer: NSObject, UIViewRepresentable {
    let store: Store<ViewModel>
    let sceneDelegate: ARSessionDelegate
    var sceneObserver: Cancellable!
    var anchorStateChangeObserver: Cancellable!
    let arView = ARView(frame: .zero)
    private var disposables = Set<AnyCancellable>()

    init(sceneDelegate: ARSessionDelegate, store: Store<ViewModel>) {
        self.sceneDelegate = sceneDelegate
        self.store = store
        self.store.value.arView = arView
    }

    func makeUIView(context: Context) -> ARView {
        #if !targetEnvironment(simulator)
        arView.session.delegate = self
        tapGestureSetup()
        setupObservers(arView: arView)
        #endif
        arView.addCoaching()
        return arView
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        print("We've been asked to dismantle our arView")
    }
    // MARK: - Gesture recognizer callbacks
    func updateUIView(_ uiView: ARView, context: Context) {}

    func setupObservers(arView: ARView) {

        // When an anchor is added, we need to trigger the lookAtCamera notification which is set to repeat
        arView.scene.publisher(for: SceneEvents.AnchoredStateChanged.self)
            .subscribe(on: RunLoop.main)
            .filter { $0.isAnchored }
            .filter { $0.anchor.name == Scene.AnchorCollection.signAnchorNameIdentifier }
            .map { $0.anchor }
            .sink { plantSignAnchorWrapper in
                print("Anchor State Changed to isAnchored true. This means we have a new anchor")
                // TODO ok unrelated actually I think when we re-load a new arView we need to move this thing over perhaps

                // Get the previously loaded scene. This contains the notifications and the original entity which we've cloned
                guard let scene = self.store.value.loadedPlantSignScene else {
                    print("we must not have a scene yet")
                    return
                }

                guard let originalSignEntity = scene.plantSignEntityToAttach else {
                    print("This is the origina entity. use this as the key for the overrides")
                    return
                }
                let notifications = scene.notifications
                let overrides = [originalSignEntity.name: plantSignAnchorWrapper]
                notifications.lookAtCamera.post(overrides: overrides)
        }.store(in: &disposables)
    }

    fileprivate func addNewAnchor(_ sender: UITapGestureRecognizer) {
           // Get the user's tap screen location.
           guard let arView = store.value.arView else {
               return
           }
           let touchLocation = sender.location(in: arView)

           // do nothing if we are in the adding sign state
           guard !store.value.isAddingSign else {
               addSign(at: touchLocation, on: arView)
               return
           }

          checkForCollisions(at: touchLocation, on: arView)
       }
    
    func tapGestureSetup() {
           let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedOnARView))
           assert(store.value.arView != nil)
           store.value.arView?.addGestureRecognizer(tapGesture)
       }

       /// Tap gesture input handler.
       /// - Tag: TapHandler
       @objc
       func tappedOnARView(_ sender: UITapGestureRecognizer) {
           addNewAnchor(sender)
       }

       private func addSign(at touchLocation: CGPoint, on arView: ARView) {
           // Cast a ray to check for its intersection with any planes.
           #if !targetEnvironment(simulator)

           let raycastResultsArray = arView.raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .any)
           guard let raycastResult = raycastResultsArray.first else {
               // TODO messageLabel.displayMessage("No surface detected, try getting closer.", duration: 2.0)
               print("No surface detected, try getting closer.")
               return
           }
           store.value.showingAlert = .createMarker("Name this plant", arView, raycastResult)
           #endif
       }

       private func checkForCollisions(at touchLocation: CGPoint, on arView: ARView) {
           let hits = arView.hitTest(touchLocation)
           hits.map { $0.entity.findRoot() }
               .map { $0.findEntity(named: "PlantSignEntityToAttach") }
               .compactMap { $0 }
               .forEach { entity in
                   print("we have tapped on \(entity.anchor?.anchorIdentifier)")
                   store.value.isShowingPlantInfo = true
                   store.value.isShowingModalInfoCollectionFlow = true
           }
       }
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
class TestARSession: NSObject, ARSessionDelegate {
    func setupObservers(arView: ARView) {

    }

    func tapGestureSetup() {
    }
}
struct ContentView_Previews : PreviewProvider {

    private class DummyDelegate: NSObject, ARSessionDelegate {
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
