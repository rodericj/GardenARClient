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
    let networkClient: NetworkClient
    init(initialValue: Value, networkClient: NetworkClient) {
        self.value = initialValue
        self.networkClient = networkClient
    }

}
