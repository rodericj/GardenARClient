//
//  SpaceRow.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/11/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI
import Combine
struct SpaceRow: View {
    let spaceInfo: SpaceInfo
    @Binding var selected: SpaceInfo?
    @EnvironmentObject var store: Store<ViewModel>
    let networkClient: NetworkClient
    
    var body: some View {
        Button(action: {
            print("🌎 Select space \(self.spaceInfo.title)")
            self.get(space: self.spaceInfo)
            self.selected = self.spaceInfo
        }) {
            VStack(alignment: .leading) {
                Text(spaceInfo.title).font(.largeTitle).autocapitalization(.words)
                Spacer()
                Text("\(spaceInfo.anchors?.count ?? 0) Anchors").font(.body)
            }
        }
    }
}
extension SpaceRow {
    func get(space: SpaceInfo) {
        var cancellable: AnyCancellable?
        cancellable = networkClient.getSpace(uuid: space.id)
            
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                switch result {

                case .finished:
                    print("got a space")
                case .failure(let error):
                    print("🔴 Error fetching single space \(error)")
                }
            }) { space in
                print("ViewModel got a new space \(space)")

                guard let indexOfOldSpace = self.store.value.spaces.firstIndex(where: { querySpace -> Bool in
                    querySpace.id == space.id
                }) else {
                    self.store.value.spaces.append(space)

                    cancellable?.cancel()
                    return
                }
                self.store.value.spaces.append(space)
                // Handle the case where selected space was the one we are fetching
                if self.store.value.selectedSpace == self.store.value.spaces[indexOfOldSpace] {
                    self.store.value.selectedSpace = space
                }
                self.store.value.spaces.remove(at: indexOfOldSpace)
                cancellable?.cancel()
        }
    }
}

//struct SpaceRow_Previews: PreviewProvider {
//
//    static var previews: some View {
//        let network = NetworkClient()
//        let mySpaceInfo = SpaceInfo(title: "Backyard", id: UUID())
//        let viewModel = ViewModel(networkClient: network)
//        return SpaceRow(spaceInfo: mySpaceInfo)
//    }
//}
