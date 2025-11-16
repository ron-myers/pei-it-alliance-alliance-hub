#if os(tvOS)
import SwiftUI
import SwiftData

struct TVContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    
    @State private var currentPhotoIndex = 0
    @State private var slideshowTimer: Timer?
    @State private var showBouncing = false
    @State private var showTestMode = false  // Toggle to add test photos
    
    // Bouncing logo state
    @State private var logoPosition = CGPoint(x: 200, y: 200)
    @State private var velocity = CGPoint(x: 3, y: 3)
    @State private var bouncingTimer: Timer?
    @State private var logoColor: Color = .white
    @State private var hitCorner = false
    @State private var topLeftHit = 0
    @State private var bottomLeftHit = 0
    @State private var topRightHit = 0
    @State private var bottomRightHit = 0
    
    let staticLogoSize: CGFloat = 400
    let bouncingLogoWidth: CGFloat = 700
    let logoAspectRatio: CGFloat = 2000.0 / 704.0
    
    var bouncingLogoHeight: CGFloat {
        return bouncingLogoWidth / logoAspectRatio
    }
    
    let screenSize = UIScreen.main.bounds.size
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if showTestMode {
                    // TEST MODE: Add photos directly on Apple TV for testing
                    TestModeView(modelContext: modelContext, items: items, showTestMode: $showTestMode)
                } else if items.isEmpty {
                    // Show welcome screen if no photos
                    VStack(spacing: 30) {
                        Image("PIA logo-02")
                            .resizable()
                            .scaledToFit()
                            .frame(width: staticLogoSize, height: staticLogoSize)
                        
                        VStack(spacing: 15) {
                            Text("Welcome to the Foundry")
                                .font(.title)
                                .foregroundColor(.white)
                            
                            Text("Add photos from your iPhone to display them here")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            VStack(spacing: 15) {
                                HStack(spacing: 20) {
                                    // Test button to add sample photos
                                    Button("Add Test Photo (For Testing)") {
                                        showTestMode = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    // Manual Sync button
                                    NavigationLink(destination: ManualSyncView()) {
                                        Label("Manual Sync", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                }
                                
                                HStack(spacing: 20) {
                                    // Diagnostics button
                                    NavigationLink(destination: TVDiagnosticsView()) {
                                        Label("Diagnostics", systemImage: "stethoscope")
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    // Debug button
                                    NavigationLink(destination: DebugView()) {
                                        Label("Debug", systemImage: "ant.circle")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.top, 20)
                        }
                    }
                } else if !showBouncing {
                    // Photo slideshow - this is the main content!
                    ZStack {
                        PhotoSlideshowView(
                            items: items,
                            currentIndex: $currentPhotoIndex
                        )
                        
                        // Test button overlay (top right)
                        VStack {
                            HStack {
                                Spacer()
                                
                                NavigationLink(destination: ManualSyncView()) {
                                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .padding(.trailing)
                                
                                NavigationLink(destination: DebugView()) {
                                    Label("Debug", systemImage: "ant.circle")
                                }
                                .buttonStyle(.bordered)
                                .padding(.trailing)
                                
                                NavigationLink(destination: TVDiagnosticsView()) {
                                    Label("Diagnostics", systemImage: "stethoscope")
                                }
                                .buttonStyle(.bordered)
                                .padding(.trailing)
                                
                                Button("Test Mode") {
                                    showTestMode = true
                                }
                                .buttonStyle(.bordered)
                                .padding()
                            }
                            Spacer()
                        }
                    }
                } else {
                    // Bouncing logo screensaver (only after long inactivity)
                    BouncingLogoView(
                        logoPosition: $logoPosition,
                        velocity: $velocity,
                        logoColor: $logoColor,
                        hitCorner: $hitCorner,
                        topLeftHit: $topLeftHit,
                        bottomLeftHit: $bottomLeftHit,
                        topRightHit: $topRightHit,
                        bottomRightHit: $bottomRightHit,
                        bouncingLogoWidth: bouncingLogoWidth,
                        bouncingLogoHeight: bouncingLogoHeight,
                        screenSize: screenSize
                    )
                }
                }
            .onAppear {
                print("📺 TVContentView appeared")
                print("📺 Items count: \(items.count)")
                if items.count > 0 {
                    for (index, item) in items.enumerated() {
                        print("📺   Item \(index + 1): '\(item.title.isEmpty ? "Untitled" : item.title)' - \(item.timestamp)")
                    }
                }
                startSlideshow()
                // Optional: Schedule bouncing screensaver after slideshow runs for a while
                // Comment out the next 3 lines if you want photos to loop forever without bouncing mode
                if !items.isEmpty {
                    scheduleBouncingMode()
                }
            }
            .onDisappear {
                slideshowTimer?.invalidate()
                bouncingTimer?.invalidate()
            }
            .onChange(of: items.count) { oldCount, newCount in
                print("📺 TVContentView: Items count changed from \(oldCount) to \(newCount)")
                if newCount > oldCount {
                    print("📺 ✅ NEW PHOTOS RECEIVED! Showing slideshow...")
                    for i in oldCount..<newCount {
                        if items.indices.contains(i) {
                            print("📺   New item: '\(items[i].title.isEmpty ? "Untitled" : items[i].title)'")
                        }
                    }
                }
                // Restart slideshow when photos are added/removed
                slideshowTimer?.invalidate()
                bouncingTimer?.invalidate()
                showBouncing = false
                
                if newCount > 0 {
                    startSlideshow()
                    scheduleBouncingMode()
                }
            }
        }
    }
    
    private func startSlideshow() {
        guard !items.isEmpty else { return }
        
        // Change photo every 10 seconds
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                currentPhotoIndex = (currentPhotoIndex + 1) % items.count
            }
        }
    }
    
    private func scheduleBouncingMode() {
        // Switch to bouncing screensaver after 5 minutes of showing slideshow
        // Set to longer time or comment out if you don't want screensaver mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {  // 300 seconds = 5 minutes
            showBouncing = true
            startBouncingAnimation()
        }
    }
    
    private func startBouncingAnimation() {
        // Calculate boundaries
        let halfLogoWidth = bouncingLogoWidth / 2
        let halfLogoHeight = bouncingLogoHeight / 2
        let minX = halfLogoWidth
        let maxX = screenSize.width - halfLogoWidth
        let minY = halfLogoHeight
        let maxY = screenSize.height - halfLogoHeight
        
        // Randomize initial velocity direction
        let speed: CGFloat = 3.0
        let randomXDirection: CGFloat = Bool.random() ? 1 : -1
        let randomYDirection: CGFloat = Bool.random() ? 1 : -1
        velocity = CGPoint(x: speed * randomXDirection, y: speed * randomYDirection)
        
        // Randomize starting position
        logoPosition = CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
        
        bouncingTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateBouncingPosition()
        }
    }
    
    private func updateBouncingPosition() {
        logoPosition.x += velocity.x
        logoPosition.y += velocity.y
        
        let halfLogoWidth = bouncingLogoWidth / 2
        let halfLogoHeight = bouncingLogoHeight / 2
        let minX = halfLogoWidth
        let maxX = screenSize.width - halfLogoWidth
        let minY = halfLogoHeight
        let maxY = screenSize.height - halfLogoHeight
        
        var hitVertical = false
        var hitHorizontal = false
        
        // Bounce off edges
        if logoPosition.y <= minY {
            velocity.y = abs(velocity.y)
            logoPosition.y = minY
            hitVertical = true
            velocity.x += CGFloat.random(in: -0.5...0.5)
            normalizeVelocity()
        } else if logoPosition.y >= maxY {
            velocity.y = -abs(velocity.y)
            logoPosition.y = maxY
            hitVertical = true
            velocity.x += CGFloat.random(in: -0.5...0.5)
            normalizeVelocity()
        }
        
        if logoPosition.x <= minX {
            velocity.x = abs(velocity.x)
            logoPosition.x = minX
            hitHorizontal = true
            velocity.y += CGFloat.random(in: -0.5...0.5)
            normalizeVelocity()
        } else if logoPosition.x >= maxX {
            velocity.x = -abs(velocity.x)
            logoPosition.x = maxX
            hitHorizontal = true
            velocity.y += CGFloat.random(in: -0.5...0.5)
            normalizeVelocity()
        }
        
        // Check for corner hits
        checkCornerHit()
    }
    
    private func normalizeVelocity() {
        let currentSpeed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        velocity.x = (velocity.x / currentSpeed) * 3.0
        velocity.y = (velocity.y / currentSpeed) * 3.0
    }
    
    private func checkCornerHit() {
        let tolerance: CGFloat = 5.0
        let x = logoPosition.x
        let y = logoPosition.y
        
        let topLeft = (x >= 350.0 - tolerance && x <= 351.0 + tolerance) && (y >= 120 - tolerance && y <= 125 + tolerance)
        let bottomLeft = (x >= 350.0 - tolerance && x <= 351.0 + tolerance) && (y >= 954.8 - tolerance && y <= 959.8 + tolerance)
        let bottomRight = (x >= 1569 - tolerance && x <= 1574 + tolerance) && (y >= 954.8 - tolerance && y <= 959.8 + tolerance)
        let topRight = (x >= 1569 - tolerance && x <= 1574 + tolerance) && (y >= 120 - tolerance && y <= 125 + tolerance)
        
        if topLeft || bottomLeft || bottomRight || topRight {
            print("🎯 CORNER HIT! 🎯")
            
            if topLeft { topLeftHit += 1 }
            if bottomLeft { bottomLeftHit += 1 }
            if bottomRight { bottomRightHit += 1 }
            if topRight { topRightHit += 1 }
            
            logoColor = .red
            hitCorner = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                hitCorner = false
            }
        }
    }
}

// TEST MODE VIEW - Add sample photos directly on Apple TV
struct TestModeView: View {
    var modelContext: ModelContext
    var items: [Item]
    @Binding var showTestMode: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Test Mode")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text("Current Photos: \(items.count)")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 20) {
                Button("Add Red Test Photo") {
                    addTestPhoto(color: .red, title: "Red Test Photo")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button("Add Blue Test Photo") {
                    addTestPhoto(color: .blue, title: "Blue Test Photo")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button("Add Green Test Photo") {
                    addTestPhoto(color: .green, title: "Green Test Photo")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                if !items.isEmpty {
                    Button("Delete Last Photo") {
                        deleteLastPhoto()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            .padding()
            
            Button("Back to Display") {
                showTestMode = false
            }
            .buttonStyle(.bordered)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func addTestPhoto(color: Color, title: String) {
        // Create a simple colored image
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(color).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text to make it interesting
            let text = title as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            let newItem = Item(
                timestamp: Date(),
                title: title,
                imageData: imageData
            )
            modelContext.insert(newItem)
            print("📺 Apple TV: Added test photo - '\(title)'")
            print("📺 Apple TV: Image size: \(imageData.count / 1024)KB")
            
            do {
                try modelContext.save()
                print("✅ Apple TV: Saved to SwiftData successfully")
            } catch {
                print("❌ Apple TV: Error saving: \(error)")
            }
        }
    }
    
    private func deleteLastPhoto() {
        guard let lastItem = items.first else { return }
        modelContext.delete(lastItem)
        print("📺 Apple TV: Deleted photo - '\(lastItem.title)'")
        
        do {
            try modelContext.save()
            print("✅ Apple TV: Deleted successfully")
        } catch {
            print("❌ Apple TV: Error deleting: \(error)")
        }
    }
}

// Photo slideshow component
struct PhotoSlideshowView: View {
    let items: [Item]
    @Binding var currentIndex: Int
    
    var body: some View {
        if items.indices.contains(currentIndex),
           let imageData = items[currentIndex].imageData,
           let uiImage = UIImage(data: imageData) {
            
            VStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.9,
                           maxHeight: UIScreen.main.bounds.height * 0.8)
                    .shadow(radius: 20)
                    .transition(.opacity)
                
                if !items[currentIndex].title.isEmpty {
                    Text(items[currentIndex].title)
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
    }
}

// Bouncing logo component
struct BouncingLogoView: View {
    @Binding var logoPosition: CGPoint
    @Binding var velocity: CGPoint
    @Binding var logoColor: Color
    @Binding var hitCorner: Bool
    @Binding var topLeftHit: Int
    @Binding var bottomLeftHit: Int
    @Binding var topRightHit: Int
    @Binding var bottomRightHit: Int
    
    let bouncingLogoWidth: CGFloat
    let bouncingLogoHeight: CGFloat
    let screenSize: CGSize
    
    var body: some View {
        ZStack {
            Color.white
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Top Left: ")
                        Text("Top Right: ")
                        Text("Bottom Left: ")
                        Text("Bottom Right: ")
                    }
                    VStack {
                        Text("\(topLeftHit)")
                        Text("\(topRightHit)")
                        Text("\(bottomLeftHit)")
                        Text("\(bottomRightHit)")
                    }
                }
            }
            .foregroundColor(.black)
            
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
                .colorMultiply(logoColor)
                .position(logoPosition)
        }
        .frame(width: screenSize.width, height: screenSize.height)
    }
}

#Preview {
    TVContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
#endif
