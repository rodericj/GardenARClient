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
    @Binding var selected: SelectedSpaceInfoIsSet
    @EnvironmentObject var store: Store<ViewModel>
    let networkClient: NetworkClient
    
    var body: some View {
        Button(action: {
            print("🌎 Select space \(self.spaceInfo.title)")
            self.get(space: self.spaceInfo)
            self.selected = .space(self.spaceInfo)
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
                guard let indexOfOldSpace = self.store.value.spaces.all.firstIndex(where: { querySpace -> Bool in
                    querySpace.id == space.id
                }) else {
                    self.store.appendSpace(spaceInfo: space)
                    cancellable?.cancel()
                    return
                }
                self.store.appendSpace(spaceInfo: space)
                self.store.value.selectedSpace = .space(space)
                self.store.removeSpace(at: indexOfOldSpace)
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
