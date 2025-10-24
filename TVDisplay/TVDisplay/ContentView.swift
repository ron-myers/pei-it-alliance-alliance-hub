//
//  ContentView.swift
//  TVDisplay
//
//  Created by RH Lee on 24/10/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image("PIA logo-01")
                .resizable()
                .scaledToFit()
            Text("Welcome to the Foundry").font((.title))
        }
        .padding()
        .preferredColorScheme(ColorScheme.light)
        
    }
}

#Preview {
    ContentView()
}
