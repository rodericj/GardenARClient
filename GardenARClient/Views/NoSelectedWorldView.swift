//
//  NoSelectedWorldView.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/13/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct NoSelectedWorldView: View {
    @ObservedObject var viewModel: ViewModel
    var body: some View {
        VStack {
            if viewModel.worlds.isEmpty {
                AddWorldButton(viewModel: viewModel)
            } else {
                WorldListView(viewModel: viewModel)
            }
        }
    }
}

struct NoSelectedWorldView_Previews: PreviewProvider {
    static var previews: some View {
        let client = NetworkClient()
        return NoSelectedWorldView(viewModel: ViewModel(networkClient: client))
    }
}
