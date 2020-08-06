//
//  AddSpaceButton.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine

extension UIView {

    // Since these are all static (and a hack) we can have it on whatever type we want, maybe shouldn't be on View
    static func creationAlert(title: String, placeholder: String, completion: @escaping (String) -> ()) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField() { textField in
            textField.placeholder = placeholder
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { _ in
            guard let textField = alert.textFields?.first,
                let inputtedText = textField.text else {
                    return
            }
            completion(inputtedText)
        })
        showAlert(alert: alert)
    }

    static func showAlert(alert: UIAlertController) {
        if let controller = topMostViewController() {
            controller.present(alert, animated: true)
        }
    }

    static private func topMostViewController() -> UIViewController? {
        guard let rootController = keyWindow()?.rootViewController else {
            return nil
        }
        return topMostViewController(for: rootController)
    }

    static private func topMostViewController(for controller: UIViewController) -> UIViewController {
        if let presentedController = controller.presentedViewController {
            return topMostViewController(for: presentedController)
        } else if let navigationController = controller as? UINavigationController {
            guard let topController = navigationController.topViewController else {
                return navigationController
            }
            return topMostViewController(for: topController)
        } else if let tabController = controller as? UITabBarController {
            guard let topController = tabController.selectedViewController else {
                return tabController
            }
            return topMostViewController(for: topController)
        }
        return controller
    }
    static private func keyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter {$0.activationState == .foregroundActive}
            .compactMap {$0 as? UIWindowScene}
            .first?.windows.filter {$0.isKeyWindow}.first
    }
}

struct AddItemsButtons: View {
    @EnvironmentObject var store: Store<ViewModel>
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        VStack {
            Spacer()
            HStack {
                if store.value.selectedSpace == .none {
                    Button(action: {
                        self.store.value.showingAlert = .createSpace("Add a new Space") // TODO use a reducer here
                    }) {
                        CTAButtonView(title: "+ Space")
                    }
                }
                if store.value.shouldShowAddSignButton {
                    Button(action: {
                        self.store.value.isAddingSign = true // TODO use a reducer here
                    }) {
                        CTAButtonView(title: "+ Sign")
                    }

                }
            }

        }.padding()
    }
}

struct AddSpaceButton_Previews: PreviewProvider {
    static var previews: some View {
        var viewModel = ViewModel()
        let bananaSpace = SpaceInfo(title: "Banana", id: UUID())
        let store = Store<ViewModel>(initialValue: viewModel, networkClient: NetworkClient())
        viewModel.selectedSpace = .space(bananaSpace)
        return AddItemsButtons().environmentObject(store)
    }
}
