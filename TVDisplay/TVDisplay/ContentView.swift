//
//  ContentView.swift
//  TVDisplay
//
//  Created by RH Lee on 24/10/2025.
//
/*
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
*/
//
//  ContentView.swift
//  TVDisplay
//
//  Created by RH Lee on 24/10/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var logoPosition = CGPoint(x: 200, y: 200)
    @State private var velocity = CGPoint(x: 3, y: 3)
    @State private var isBouncingActive = false
    @State private var timer: Timer?
    
    let staticLogoSize: CGFloat = 400
    let bouncingLogoWidth: CGFloat = 700  // Make it bigger to be more visible
    
    // Logo aspect ratio is 2000:704 = 2.84:1
    let logoAspectRatio: CGFloat = 2000.0 / 704.0
    
    // Calculate actual rendered height based on aspect ratio
    var bouncingLogoHeight: CGFloat {
        return bouncingLogoWidth / logoAspectRatio  // = 700 / 2.84 = 246 pixels
    }
    
    // Get the ACTUAL screen size
    let screenSize = UIScreen.main.bounds.size
    
    var body: some View {
        ZStack {
            // Original static content
            if !isBouncingActive {
                VStack {
                    Image("PIA logo-02")
                        .resizable()
                        .scaledToFit()
                        .frame(width: staticLogoSize, height: staticLogoSize)
                    Text("Welcome to the Foundry").font(.title)
                }
                .padding()
            }
            
            // Bouncing logo (DVD screensaver style)
            if isBouncingActive {
                ZStack {
                    Color.white
                    Image("PIA logo-02")
                        .resizable()
                        .scaledToFit()
                        .frame(width: bouncingLogoWidth, height: bouncingLogoHeight)
                        .position(logoPosition)
                }
                .frame(width: screenSize.width, height: screenSize.height)
                .position(x: screenSize.width / 2, y: screenSize.height / 2)
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .background(Color.white)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear {
            print("UIScreen.main.bounds: \(UIScreen.main.bounds)")
            print("Screen size: width=\(screenSize.width), height=\(screenSize.height)")
            startBouncingAfterDelay()
        }
    }
    
    func startBouncingAfterDelay() {
        // Start bouncing after 5 seconds for testing
        // Change back to 60 for production
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isBouncingActive = true
            logoPosition = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
            print("Starting bounce at center: \(logoPosition)")
            print("Logo size: width=\(bouncingLogoWidth), height=\(bouncingLogoHeight)")
            print("Will bounce between Y: \(bouncingLogoHeight/2) and \(screenSize.height - bouncingLogoHeight/2)")
            startBouncing()
        }
    }
    
    func startBouncing() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Update position
            logoPosition.x += velocity.x
            logoPosition.y += velocity.y
            
            // Calculate boundaries using actual logo dimensions
            let halfLogoWidth = bouncingLogoWidth / 2
            let halfLogoHeight = bouncingLogoHeight / 2
            let minX = halfLogoWidth
            let maxX = screenSize.width - halfLogoWidth
            let minY = halfLogoHeight
            let maxY = screenSize.height - halfLogoHeight
            
            // Bounce off top/bottom edges
            if logoPosition.y <= minY {
                print("Hit top! minY=\(minY), logoPosition.y=\(logoPosition.y), screen height=\(screenSize.height)")
                velocity.y = abs(velocity.y)
                logoPosition.y = minY
            } else if logoPosition.y >= maxY {
                print("Hit bottom! maxY=\(maxY), logoPosition.y=\(logoPosition.y), screen height=\(screenSize.height)")
                velocity.y = -abs(velocity.y)
                logoPosition.y = maxY
            }
            
            // Bounce off left/right edges
            if logoPosition.x <= minX {
                print("Hit left! minX=\(minX), logoPosition.x=\(logoPosition.x)")
                velocity.x = abs(velocity.x)
                logoPosition.x = minX
            } else if logoPosition.x >= maxX {
                print("Hit right! maxX=\(maxX), logoPosition.x=\(logoPosition.x)")
                velocity.x = -abs(velocity.x)
                logoPosition.x = maxX
            }
        }
    }
}

#Preview {
    ContentView()
}
