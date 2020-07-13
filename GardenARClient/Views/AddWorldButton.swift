//
//  AddWorldButton.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

extension View {
    func creationAlert(viewModel: ViewModel) {
        let alert = UIAlertController(title: "Create new world", message: nil, preferredStyle: .alert)
        alert.addTextField() { textField in
            textField.placeholder = "New world name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { _ in
            guard let textField = alert.textFields?.first,
                let newWorldName = textField.text else {
                    return
            }
            do {
                try viewModel.makeWorld(named: newWorldName)
            } catch {
                print("There was an error in sending the network request to create the world")
            }
        })
        showAlert(alert: alert)
    }

    func showAlert(alert: UIAlertController) {
        if let controller = topMostViewController() {
            controller.present(alert, animated: true)
        }
    }

    private func topMostViewController() -> UIViewController? {
        guard let rootController = keyWindow()?.rootViewController else {
            return nil
        }
        return topMostViewController(for: rootController)
    }

    private func topMostViewController(for controller: UIViewController) -> UIViewController {
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
    private func keyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter {$0.activationState == .foregroundActive}
            .compactMap {$0 as? UIWindowScene}
            .first?.windows.filter {$0.isKeyWindow}.first
    }
}

struct AddWorldButton: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        VStack {
            Spacer()
            Button(action: {
                self.creationAlert(viewModel: self.viewModel)
            }) {
                Text("New World")
                    .fontWeight(.heavy)
                    .font(.title)
                    .padding()
                    .foregroundColor(.black)
                    .background(Color.white)
                    .cornerRadius(40)
            }
        }
    }
}

struct AddWorldButton_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ViewModel(networkClient: NetworkClient())
        return AddWorldButton().environmentObject(viewModel)
    }
}
