//
//  NetworkClient.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/10/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import Foundation
import Combine

struct SpacesInfoPayload: Decodable {
    let spaces: [SpaceInfo]
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var space: SpaceInfo
        var newSpaces = [SpaceInfo]()
        while !container.isAtEnd {
            space = try container.decode(SpaceInfo.self)
            newSpaces.append(space)
        }
        spaces = newSpaces
    }
}

struct SpaceInfoPayload: Decodable {
    let space: SpaceInfo
}

protocol HasTitle {
    var title: String { get }
}

struct SpaceInfo: Codable, Identifiable, HasTitle, Equatable, CustomStringConvertible {
    var description: String {
        get {
            return "\n\(title) \(data?.description ?? "no data") \(anchors ?? [])"
        }
    }


    let title: String
    let id: UUID
    let data: Data?
    var anchors: [Anchor]?
    init(title: String, id: UUID) {
        self.id = id
        self.title = title
        self.data = nil
    }
}

extension URL {
    static let space = URL(string: "http://thumbworksbot.ngrok.io/space")!
    static func space(uuid: UUID) -> URL {
        URL(string: "http://thumbworksbot.ngrok.io/space/\(uuid)")!
    }
}

protocol NetworkFetching {
    var getSpaces: AnyPublisher<[SpaceInfo], Error> { get }
    func getSpace(uuid: UUID) -> AnyPublisher<SpaceInfo, Error>
    func makeSpace(named name: String) throws -> AnyPublisher<SpaceInfo, Error>
    func update(space: SpaceInfo, anchorID: UUID, anchorName: String, worldMapData: Data) throws -> AnyPublisher<Anchor, Error>
    func deleteSpace(uuid: UUID) throws -> AnyPublisher<Bool, Never>
}

class NetworkClient: NetworkFetching {

    private var disposables = Set<AnyCancellable>()
    let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }

    struct AnchorDataPayload: Codable {
        var id: UUID
        var anchorName: String
        var data: Data
    }

    func update(space: SpaceInfo, anchorID: UUID, anchorName: String, worldMapData: Data) throws -> AnyPublisher<Anchor, Error> {
        var request = URLRequest(url: URL.space(uuid: space.id))
        request.httpMethod = "POST"
        let payloadData = AnchorDataPayload(id: anchorID, anchorName: anchorName, data: worldMapData)
        let payload = try JSONEncoder().encode(payloadData)
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("POST to server")
        return session.dataTaskPublisher(for: request)
            .tryMap { (data, response)  in
                let anchor = try JSONDecoder().decode(Anchor.self, from: data)
                return anchor
        }.receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func makeSpace(named name: String) throws -> AnyPublisher<SpaceInfo, Error> {
        var request = URLRequest(url: URL.space)

        let payload = try JSONEncoder().encode(SpaceInfo(title: name, id: UUID()))
        
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        return session.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: SpaceInfo.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func deleteSpace(uuid: UUID) throws -> AnyPublisher<Bool, Never>  {
        var request = URLRequest(url: URL.space(uuid: uuid))
        request.httpMethod = "DELETE"
        return session.dataTaskPublisher(for: request)
            .map { _ in true }
            .replaceError(with: false)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    var getSpaces: AnyPublisher<[SpaceInfo], Error> {
        return session.dataTaskPublisher(for: URL.space)
            .map { $0.data}
            .decode(type: SpacesInfoPayload.self, decoder: JSONDecoder())
            .map { $0.spaces }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func getSpace(uuid: UUID) -> AnyPublisher<SpaceInfo, Error> {
           return session.dataTaskPublisher(for: URL.space(uuid: uuid))
               .map { $0.data}
               .decode(type: SpaceInfo.self, decoder: JSONDecoder())
               .receive(on: DispatchQueue.main)
               .eraseToAnyPublisher()
       }
}
