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
    @State private var logoColor: Color = .white  // Color for the logo tint (white = original colors)
    @State private var hitCorner = false  // Track if corner was hit
    @State private var topLeftHit = 0
    @State private var bottomLeftHit = 0
    @State private var topRightHit = 0
    @State private var bottomRightHit = 0
    
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
                    VStack(alignment: .leading, spacing: 16){
                        HStack{
                            VStack(alignment: .leading){
                                Text("Top Left: ")
                                Text("Top Right: ")
                                Text("Bottom Left: ")
                                Text("Bottom Right：")
                            }
                            VStack{
                                Text("\(topLeftHit)")
                                Text("\(topRightHit)")
                                Text("\(bottomLeftHit)")
                                Text("\(bottomRightHit)")
                            }
                        }
                        
                    }
                    
                    // Corner hit celebration text
                    if hitCorner {
                        Text("🎯 CORNER HIT! 🎯")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.red)
                            .position(x: screenSize.width / 2, y: 100)
                    }
                    
                    Image("PIA logo-02")
                        .resizable()
                        .scaledToFit()
                        .frame(width: bouncingLogoWidth, height: bouncingLogoHeight)
                        .colorMultiply(logoColor)  // Apply color tint
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
            
            // Calculate boundaries
            let halfLogoWidth = bouncingLogoWidth / 2
            let halfLogoHeight = bouncingLogoHeight / 2
            let minX = halfLogoWidth
            let maxX = screenSize.width - halfLogoWidth
            let minY = halfLogoHeight
            let maxY = screenSize.height - halfLogoHeight
            
            // CHANGE 2: Randomize initial velocity direction
            let speed: CGFloat = 3.0
            let randomXDirection: CGFloat = Bool.random() ? 1 : -1
            let randomYDirection: CGFloat = Bool.random() ? 1 : -1
            velocity = CGPoint(x: speed * randomXDirection, y: speed * randomYDirection)
            
            // CHANGE 2: Randomize starting position (anywhere in the valid bounds)
            logoPosition = CGPoint(
                x: CGFloat.random(in: minX...maxX),
                y: CGFloat.random(in: minY...maxY)
            )
            
            print("Starting bounce at: \(logoPosition)")
            print("Velocity: \(velocity)")
            print("Logo size: width=\(bouncingLogoWidth), height=\(bouncingLogoHeight)")
            print("Distance to edges: X margin: \(min(logoPosition.x - minX, maxX - logoPosition.x)), Y margin: \(min(logoPosition.y - minY, maxY - logoPosition.y))")
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
            
            
            var hitVertical = false
            var hitHorizontal = false
            
            // Bounce off top/bottom edges
            if logoPosition.y <= minY {
                print("Hit top! minY=\(minY), logoPosition.y=\(logoPosition.y)")
                velocity.y = abs(velocity.y)
                logoPosition.y = minY
                hitVertical = true
                // CHANGE 1: Add random angle variation while maintaining constant speed
                velocity.x += CGFloat.random(in: -0.5...0.5)
                // Normalize to maintain constant speed of 3.0
                let currentSpeed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                velocity.x = (velocity.x / currentSpeed) * 3.0
                velocity.y = (velocity.y / currentSpeed) * 3.0
            } else if logoPosition.y >= maxY {
                print("Hit bottom! maxY=\(maxY), logoPosition.y=\(logoPosition.y)")
                velocity.y = -abs(velocity.y)
                logoPosition.y = maxY
                hitVertical = true
                // CHANGE 1: Add random angle variation while maintaining constant speed
                velocity.x += CGFloat.random(in: -0.5...0.5)
                // Normalize to maintain constant speed of 3.0
                let currentSpeed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                velocity.x = (velocity.x / currentSpeed) * 3.0
                velocity.y = (velocity.y / currentSpeed) * 3.0
            }
            
            // Bounce off left/right edges
            if logoPosition.x <= minX {
                print("Hit left! minX=\(minX), logoPosition.x=\(logoPosition.x)")
                velocity.x = abs(velocity.x)
                logoPosition.x = minX
                hitHorizontal = true
                // CHANGE 1: Add random angle variation while maintaining constant speed
                velocity.y += CGFloat.random(in: -0.5...0.5)
                // Normalize to maintain constant speed of 3.0
                let currentSpeed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                velocity.x = (velocity.x / currentSpeed) * 3.0
                velocity.y = (velocity.y / currentSpeed) * 3.0
            } else if logoPosition.x >= maxX {
                print("Hit right! maxX=\(maxX), logoPosition.x=\(logoPosition.x)")
                velocity.x = -abs(velocity.x)
                logoPosition.x = maxX
                hitHorizontal = true
                // CHANGE 1: Add random angle variation while maintaining constant speed
                velocity.y += CGFloat.random(in: -0.5...0.5)
                // Normalize to maintain constant speed of 3.0
                let currentSpeed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                velocity.x = (velocity.x / currentSpeed) * 3.0
                velocity.y = (velocity.y / currentSpeed) * 3.0
            }
            print("GCS: X=\(logoPosition.x) Y=\(logoPosition.y)")
            // Check if corner was hit (both edges at once)
            if ((logoPosition.x >= 350.0 && logoPosition.x <= 351.0) && (logoPosition.y >= 120 && logoPosition.y <= 125)) || ((logoPosition.x >= 350.0 && logoPosition.x <= 351.0) && (logoPosition.y >= 954.8 && logoPosition.y <= 959.8)) || ((logoPosition.x >= 1569 && logoPosition.x <= 1574) && (logoPosition.y >= 954.8 && logoPosition.y <= 959.8)) || ((logoPosition.x >= 1569 && logoPosition.x <= 1574) && (logoPosition.y >= 120 && logoPosition.y <= 125)){
                print("🎯 CORNER HIT! 🎯")
                if ((logoPosition.x >= 350.0 && logoPosition.x <= 351.0) && (logoPosition.y >= 120 && logoPosition.y <= 125)){
                    topLeftHit += 1
                }
                
                if ((logoPosition.x >= 350.0 && logoPosition.x <= 351.0) && (logoPosition.y >= 954.8 && logoPosition.y <= 959.8)){
                    bottomLeftHit += 1
                }
                
                if ((logoPosition.x >= 1569 && logoPosition.x <= 1574) && (logoPosition.y >= 954.8 && logoPosition.y <= 959.8)){
                    bottomRightHit += 1
                }
                
                if ((logoPosition.x >= 1569 && logoPosition.x <= 1574) && (logoPosition.y >= 120 && logoPosition.y <= 125)){
                    topRightHit += 1
                }
                
                logoColor = .red  // Corners turn RED
                hitCorner = true
                
                // Hide the corner message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    hitCorner = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
