#if os(tvOS)
import SwiftUI
import SwiftData
import CloudKit

struct TVContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    
    @State private var currentPhotoIndex = 0
    @State private var slideshowTimer: Timer?
    @State private var showBouncing = false
    @State private var isSyncing = false
    @State private var syncLog: [String] = []
    
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
                
                if items.isEmpty {
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
                            
                            HStack(spacing: 30) {
                                // Sync button - triggers sync directly
                                Button {
                                    performSync()
                                } label: {
                                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.title3)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                
                                // Debug button - opens consolidated debug view
                                NavigationLink(destination: ConsolidatedDebugView()) {
                                    Label("Debug", systemImage: "hammer.circle")
                                        .font(.title3)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 30)
                        }
                    }
                } else if !showBouncing {
                    // Photo slideshow - this is the main content!
                    ZStack {
                        PhotoSlideshowView(
                            items: items,
                            currentIndex: $currentPhotoIndex
                        )
                        
                        // Control buttons overlay (top right)
                        VStack {
                            HStack {
                                Spacer()
                                
                                Button {
                                    performSync()
                                } label: {
                                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .padding(.trailing, 20)
                                
                                NavigationLink(destination: ConsolidatedDebugView()) {
                                    Label("Debug", systemImage: "hammer.circle")
                                }
                                .buttonStyle(.bordered)
                                .padding(.trailing, 20)
                            }
                            .padding(.top, 20)
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
    
    private func performSync() {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncLog = ["🔄 Starting sync from CloudKit..."]
        
        print("📺 Performing manual sync...")
        
        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        
        // Create configuration for full fetch
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = nil
        
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )
        
        var fetchedRecords: [CKRecord] = []
        
        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                if record.recordType == "CD_Item" {
                    fetchedRecords.append(record)
                }
            case .failure(let error):
                print("⚠️ Error fetching record: \(error.localizedDescription)")
            }
        }
        
        operation.recordZoneFetchResultBlock = { zoneID, result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    if fetchedRecords.isEmpty {
                        self.syncLog.append("ℹ️ No new records found")
                    } else {
                        self.importRecordsFromSync(fetchedRecords)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.syncLog.append("❌ Sync error: \(error.localizedDescription)")
                    print("❌ Sync error: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
        
        operation.fetchRecordZoneChangesResultBlock = { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                DispatchQueue.main.async {
                    self.syncLog.append("❌ Overall sync error: \(error.localizedDescription)")
                    print("❌ Overall sync error: \(error.localizedDescription)")
                    self.isSyncing = false
                }
            }
        }
        
        database.add(operation)
    }
    
    private func importRecordsFromSync(_ records: [CKRecord]) {
        let existingTitles = Set(items.map { $0.title })
        var importedCount = 0
        
        for record in records {
            guard let timestamp = record["CD_timestamp"] as? Date else { continue }
            let title = (record["CD_title"] as? String) ?? ""
            
            if existingTitles.contains(title) && !title.isEmpty {
                continue
            }
            
            var imageData: Data? = nil
            
            if let asset = record["CD_imageData_ckAsset"] as? CKAsset,
               let assetURL = asset.fileURL {
                imageData = try? Data(contentsOf: assetURL)
            } else if let bytes = record["CD_imageData"] as? Data {
                imageData = bytes
            }
            
            let newItem = Item(
                timestamp: timestamp,
                title: title,
                imageData: imageData
            )
            
            modelContext.insert(newItem)
            importedCount += 1
            syncLog.append("✅ Imported: \(title.isEmpty ? "Untitled" : title)")
        }
        
        if importedCount > 0 {
            do {
                try modelContext.save()
                syncLog.append("💾 Saved \(importedCount) new items")
                print("✅ Sync complete: Imported \(importedCount) new items")
            } catch {
                syncLog.append("❌ Error saving: \(error.localizedDescription)")
                print("❌ Error saving: \(error.localizedDescription)")
            }
        } else {
            syncLog.append("✅ Already up to date")
            print("✅ Sync complete: Already up to date")
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

// Consolidated Debug View - combines SwiftData debug info and CloudKit diagnostics
struct ConsolidatedDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @State private var debugInfo: [String] = []
    @State private var diagnosticResults: [String] = []
    @State private var isRunningDiagnostics = false
    @State private var selectedTab = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Debug & Diagnostics")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(.top)
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("SwiftData Debug").tag(0)
                    Text("CloudKit Diagnostics").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                
                ScrollView {
                    if selectedTab == 0 {
                        // SwiftData Debug View
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Items Count: \(items.count)")
                                .font(.title)
                                .foregroundColor(.green)
                            
                            Divider().background(Color.white)
                            
                            if items.isEmpty {
                                Text("No items found in SwiftData")
                                    .foregroundColor(.red)
                                    .font(.title3)
                            } else {
                                Text("Items from @Query:")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("\(index + 1). \(item.title.isEmpty ? "Untitled" : item.title)")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        Text("   Date: \(item.timestamp.formatted())")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("   Has image: \(item.imageData != nil ? "Yes (\(item.imageData?.count ?? 0) bytes)" : "No")")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                            
                            if !debugInfo.isEmpty {
                                Divider().background(Color.white)
                                Text("Debug Log:")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                ForEach(debugInfo, id: \.self) { info in
                                    Text(info)
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .padding()
                    } else {
                        // CloudKit Diagnostics View
                        VStack(alignment: .leading, spacing: 10) {
                            if diagnosticResults.isEmpty {
                                Text("Press 'Run Diagnostics' to check iCloud status")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.title3)
                                    .padding()
                            } else {
                                ForEach(diagnosticResults, id: \.self) { result in
                                    Text(result)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 600)
                
                // Action buttons
                HStack(spacing: 30) {
                    Button("Back") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    if selectedTab == 0 {
                        Button("Refresh") {
                            refreshDebugInfo()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: runDiagnostics) {
                            if isRunningDiagnostics {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Running...")
                                }
                            } else {
                                Text("Run Diagnostics")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunningDiagnostics)
                    }
                }
                .padding()
            }
            .padding()
        }
        .onAppear {
            print("🔍 Debug view appeared - Items: \(items.count)")
        }
    }
    
    private func refreshDebugInfo() {
        debugInfo.removeAll()
        do {
            try modelContext.save()
            debugInfo.append("✅ Context refreshed")
            print("🔍 Items count: \(items.count)")
            for (index, item) in items.enumerated() {
                print("🔍 Item \(index + 1): '\(item.title)' - \(item.timestamp)")
            }
        } catch {
            debugInfo.append("❌ Error: \(error.localizedDescription)")
        }
    }
    
    private func runDiagnostics() {
        isRunningDiagnostics = true
        diagnosticResults = []
        
        addResult("📺 Starting Apple TV Diagnostics...")
        addResult("")
        
        addResult("📱 CHECK 1: iCloud Account")
        checkiCloudAccountStatus()
        
        addResult("")
        addResult("☁️ CHECK 2: CloudKit Container")
        checkCloudKitContainer()
        
        addResult("")
        addResult("🌐 CHECK 3: Network")
        checkNetworkStatus()
        
        addResult("")
        addResult("🔒 CHECK 4: CloudKit Permissions")
        checkCloudKitPermissions()
        
        addResult("")
        addResult("🔍 CHECK 5: Fetching Records")
        checkRecords()
        
        addResult("")
        addResult("✅ Diagnostics Complete!")
        
        isRunningDiagnostics = false
    }
    
    private func checkiCloudAccountStatus() {
        let container = CKContainer.default()
        let group = DispatchGroup()
        
        group.enter()
        container.accountStatus { status, error in
            defer { group.leave() }
            
            if let error = error {
                addResult("❌ Error: \(error.localizedDescription)")
                return
            }
            
            switch status {
            case .available:
                addResult("✅ iCloud Account: Available")
            case .noAccount:
                addResult("❌ iCloud Account: NOT SIGNED IN")
                addResult("   → Go to Settings and sign into iCloud")
            case .restricted:
                addResult("⚠️ iCloud Account: Restricted")
            case .couldNotDetermine:
                addResult("❓ iCloud Account: Could not determine")
            case .temporarilyUnavailable:
                addResult("⏳ iCloud Account: Temporarily unavailable")
            @unknown default:
                addResult("❓ iCloud Account: Unknown status")
            }
        }
        
        group.wait()
    }
    
    private func checkCloudKitContainer() {
        let container = CKContainer.default()
        addResult("Container ID: \(container.containerIdentifier ?? "none")")
        
        let group = DispatchGroup()
        group.enter()
        
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: zoneID) { records, error in
            defer { group.leave() }
            
            if let error = error as? CKError {
                switch error.code {
                case .notAuthenticated:
                    addResult("❌ Not authenticated with CloudKit")
                case .networkUnavailable, .networkFailure:
                    addResult("❌ Network error: \(error.localizedDescription)")
                case .zoneNotFound:
                    addResult("⚠️ SwiftData zone not found yet")
                    addResult("   → Add a photo from iPhone first")
                default:
                    addResult("⚠️ CloudKit error: \(error.localizedDescription)")
                }
            } else {
                addResult("✅ CloudKit Container: Accessible")
                addResult("   Found \(records?.count ?? 0) records")
            }
        }
        
        group.wait()
    }
    
    private func checkNetworkStatus() {
        if let url = URL(string: "https://www.apple.com") {
            let semaphore = DispatchSemaphore(value: 0)
            let task = URLSession.shared.dataTask(with: url) { _, _, error in
                if error != nil {
                    addResult("❌ No internet connection")
                } else {
                    addResult("✅ Internet: Connected")
                }
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
    }
    
    private func checkCloudKitPermissions() {
        let container = CKContainer.default()
        let group = DispatchGroup()
        
        group.enter()
        container.requestApplicationPermission(.userDiscoverability) { status, error in
            defer { group.leave() }
            
            if let error = error {
                addResult("⚠️ Permission check error: \(error.localizedDescription)")
            } else {
                switch status {
                case .granted:
                    addResult("✅ CloudKit Permissions: Granted")
                case .denied:
                    addResult("❌ CloudKit Permissions: Denied")
                case .couldNotComplete:
                    addResult("⚠️ CloudKit Permissions: Could not complete")
                case .initialState:
                    addResult("ℹ️ CloudKit Permissions: Not requested yet")
                @unknown default:
                    addResult("❓ CloudKit Permissions: Unknown")
                }
            }
        }
        
        group.wait()
    }
    
    private func checkRecords() {
        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        let group = DispatchGroup()
        
        group.enter()
        
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: zoneID) { records, error in
            defer { group.leave() }
            
            if let error = error as? CKError {
                addResult("❌ Query failed: \(error.localizedDescription)")
                if error.code == .zoneNotFound {
                    addResult("   💡 HINT: Add photos from iPhone first")
                }
            } else if let records = records {
                addResult("✅ Successfully fetched \(records.count) records")
                
                if records.isEmpty {
                    addResult("   ℹ️ No photos found yet")
                } else {
                    addResult("   📸 Photos found:")
                    for (index, record) in records.prefix(5).enumerated() {
                        if let title = record["CD_title"] as? String {
                            addResult("   \(index + 1). \(title.isEmpty ? "Untitled" : title)")
                        }
                    }
                    if records.count > 5 {
                        addResult("   ... and \(records.count - 5) more")
                    }
                }
            }
        }
        
        group.wait()
    }
    
    private func addResult(_ text: String) {
        DispatchQueue.main.async {
            diagnosticResults.append(text)
        }
    }
}

struct TVContentView_Previews: PreviewProvider {
    static var previews: some View {
        TVContentView()
            .modelContainer(for: Item.self, inMemory: true)
    }
}

#endif
