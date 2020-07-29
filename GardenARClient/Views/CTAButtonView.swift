//
//  CTAButton.swift
//  GardenARClient
//
//  Created by Roderic Campbell on 7/21/20.
//  Copyright © 2020 Thumbworks. All rights reserved.
//

import SwiftUI

struct CTAButtonView: View {
    let title: String
    var body: some View {
        Text(title)
            .fontWeight(.heavy)
            .font(.title)
            .padding()
            .foregroundColor(.white)
            .background(Color.green)
            .cornerRadius(40)
            .shadow(radius: 10)
    }
}

struct CTAButton_Previews: PreviewProvider {
    static var previews: some View {
        CTAButtonView(title: "This is a button")
    }
}
