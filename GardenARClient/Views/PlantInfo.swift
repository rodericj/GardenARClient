//
//  PlantInfo.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/31/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct PlantInfo: View {
    var body: some View {
        VStack {
            Text("Name: Tomato").padding()
            Text("Date: May 25, 2020").padding()
            Text("Some info").padding()
            Text("Days till Harvest: 3").padding()
        }
    }

}

struct PlantInfo_Previews: PreviewProvider {
    static var previews: some View {
        PlantInfo()
    }
}
