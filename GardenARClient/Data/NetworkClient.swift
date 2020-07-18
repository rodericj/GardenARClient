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

protocol HasTitle {
    var title: String { get }
}

struct WorldInfo: Codable, Identifiable, HasTitle, Equatable {

    let title: String
    let id: UUID
    let data: Data?
    var anchors = [Anchor]()
    init(title: String, id: UUID) {
        self.id = id
        self.title = title
        self.data = nil
    }
}

extension URL {
    static let world = URL(string: "http://thumbworksbot.ngrok.io/world")!
    static func world(uuid: UUID) -> URL {
        URL(string: "http://thumbworksbot.ngrok.io/world/\(uuid)")!
    }
}

protocol NetworkFetching {
    var getWorlds: AnyPublisher<[WorldInfo], Error> { get }
    func makeWorld(named name: String) throws -> AnyPublisher<WorldInfo, Error>
    func update(world: WorldInfo, anchorID: UUID, anchorName: String, worldMapData: Data) throws -> AnyPublisher<Anchor, Error>
    func deleteWorld(uuid: UUID) throws -> AnyPublisher<Bool, Error>
}

class NetworkClient: NetworkFetching {

    let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }

    struct AnchorDataPayload: Codable {
        var anchorName: String
        var data: Data
    }

    func update(world: WorldInfo, anchorID: UUID, anchorName: String, worldMapData: Data) throws -> AnyPublisher<Anchor, Error> {
        var request = URLRequest(url: URL.world(uuid: world.id))
        request.httpMethod = "POST"

        let payloadData = AnchorDataPayload(anchorName: anchorName, data: worldMapData)
        let payload = try JSONEncoder().encode(payloadData)
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return session.dataTaskPublisher(for: request)
            .tryMap { (data, response)  in
                let anchor = try JSONDecoder().decode(Anchor.self, from: data)
                return anchor
        }.receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func makeWorld(named name: String) throws -> AnyPublisher<WorldInfo, Error> {
        var request = URLRequest(url: URL.world)

        let payload = try JSONEncoder().encode(WorldInfo(title: name, id: UUID()))
        
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        return session.dataTaskPublisher(for: request)
                   .tryMap { (data, response)  in
                       // TODO handle network errors gracefully here
                       let world = try JSONDecoder().decode(WorldInfo.self, from: data)
                       return world
               }.receive(on: DispatchQueue.main)
                   .eraseToAnyPublisher()
    }

    func deleteWorld(uuid: UUID) throws -> AnyPublisher<Bool, Error>  {
        var request = URLRequest(url: URL.world(uuid: uuid))
        request.httpMethod = "DELETE"
        return session.dataTaskPublisher(for: request)
            .tryMap { (data, response)  in
                return true
        }.receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    var getWorlds: AnyPublisher<[WorldInfo], Error> {
        return session.dataTaskPublisher(for: URL.world)
            .tryMap { (data, response)  in
                // TODO handle network errors gracefully here
                let worldsPayload = try JSONDecoder().decode(WorldInfoPayload.self, from: data)
                return worldsPayload.worlds
        }.receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
