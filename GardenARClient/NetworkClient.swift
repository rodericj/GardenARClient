//
//  NetworkClient.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/10/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
import Combine

struct WorldInfoPayload: Decodable {
    let worlds: [WorldInfo]
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var world: WorldInfo
        var newWorlds = [WorldInfo]()
        while !container.isAtEnd {
            world = try container.decode(WorldInfo.self)
            newWorlds.append(world)
        }
        worlds = newWorlds
    }

}
struct WorldInfo: Codable {
    let title: String
    let id: UUID
}

class NetworkClient {
    let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }

    var getWorlds: AnyPublisher<[WorldInfo], Error> {
        guard let url = URL(string: "http://thumbworksbot.ngrok.io/world") else {
            fatalError("URL fail")
        }
        return session.dataTaskPublisher(for: url)
            .tryMap { (data, response)  in
                let worldsPayload = try JSONDecoder().decode(WorldInfoPayload.self, from: data)
                return worldsPayload.worlds
        }.receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
