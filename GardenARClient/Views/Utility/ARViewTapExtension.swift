//
//  ARViewTapExtension.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/16/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import UIKit
import ARKit
import RealityKit

extension ARView {
    // MARK: - Gesture recognizer callbacks

        /// Tap gesture input handler.
        /// - Tag: TapHandler
        @objc
        func tappedOnARView(_ sender: UITapGestureRecognizer) {

            // TODO Ignore the tap if the user is naming an anchor
    //        for note in stickyNotes where note.isEditing { return }

            // Create a new sticky note at the tap location.
            addNewAnchor(sender)
        }

        fileprivate func addNewAnchor(_ sender: UITapGestureRecognizer) {

            // Get the user's tap screen location.
            let touchLocation = sender.location(in: self)

            // Cast a ray to check for its intersection with any planes.
            guard let raycastResult = raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .any).first else {
//                messageLabel.displayMessage("No surface detected, try getting closer.", duration: 2.0)
                return
            }
            let newTemporaryAnchor = ARAnchor(name: "NewUnnamedAnchor", transform: raycastResult.worldTransform)
            self.session.add(anchor: newTemporaryAnchor)

    }

        func tapGestureSetup() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedOnARView))
            addGestureRecognizer(tapGesture)
        }
}
