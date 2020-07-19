//
//  Anchor.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/17/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
final class Anchor: Codable, Equatable, CustomStringConvertible {
    var description: String {
        get {
            return "\(id) : \(title)"
        }
    }

    static func == (lhs: Anchor, rhs: Anchor) -> Bool {
        return (lhs.id == rhs.id) && (lhs.title == rhs.title)
    }

    var id: UUID?
    var title: String

}
