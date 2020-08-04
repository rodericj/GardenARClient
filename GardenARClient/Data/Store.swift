//
//  Store.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 8/3/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation

final class Store<Value>: ObservableObject {
    @Published var value: Value
    init(initialValue: Value) {
        self.value = initialValue
    }

}
extension Store where Value == ViewModel {
    func appendSpace(spaceInfo: SpaceInfo) {
        switch value.spaces {

        case .fetching:
            value.spaces = .fetched([spaceInfo])
        case .fetched(let fetchedSpaces):
            var copy = fetchedSpaces
            copy.append(spaceInfo)
            value.spaces = .fetched(copy)
        case .failed(let error):
            print("error making a space \(error)")
        }
    }
    func removeSpace(at index: Int) {
        switch value.spaces {

        case .fetching:
            break
        case .fetched(let fetchedSpaces):
            var copy = fetchedSpaces
            copy.remove(at: index)
            value.spaces = .fetched(copy)
        case .failed(let error):
            print("error making a space \(error)")
        }
    }
}
