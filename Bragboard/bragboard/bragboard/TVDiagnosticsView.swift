//
//  TVDiagnosticsView.swift
//  bragboard
//
//  Diagnostic tool for Apple TV to check iCloud and CloudKit status
//
#if os(tvOS)
import SwiftUI
import CloudKit

struct TVDiagnosticsView: View {
    @State private var diagnosticResults: [String] = []
    @State private var isRunning = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Apple TV iCloud Diagnostics")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                ScrollView {
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
                .frame(maxHeight: 600)
                
                HStack(spacing: 30) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Back")
                            .font(.title3)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: runDiagnostics) {
                        if isRunning {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Running...")
                                    .font(.title3)
                            }
                            .padding()
                        } else {
                            Text("Run Diagnostics")
                                .font(.title3)
                                .padding()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                }
                .padding()
            }
            .padding()
        }
    }
    
    private func runDiagnostics() {
        isRunning = true
        diagnosticResults = []
        
        addResult("📺 Starting Apple TV Diagnostics...")
        addResult("")
        
        // Check 1: iCloud Account Status
        addResult("📱 CHECK 1: iCloud Account")
        checkiCloudAccountStatus()
        
        // Check 2: CloudKit Container
        addResult("")
        addResult("☁️ CHECK 2: CloudKit Container")
        checkCloudKitContainer()
        
        // Check 3: Network Status
        addResult("")
        addResult("🌐 CHECK 3: Network")
        checkNetworkStatus()
        
        // Check 4: CloudKit Permissions
        addResult("")
        addResult("🔒 CHECK 4: CloudKit Permissions")
        checkCloudKitPermissions()
        
        // Check 5: Try to fetch actual records
        addResult("")
        addResult("🔍 CHECK 5: Fetching Records")
        checkRecords()
        
        addResult("")
        addResult("✅ Diagnostics Complete!")
        
        isRunning = false
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
        
        // Check container accessibility
        let group = DispatchGroup()
        group.enter()
        
        let database = container.privateCloudDatabase
        
        // SwiftData uses a custom zone, not the default zone
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        
        // Try to perform a simple query in the correct zone
        let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_timestamp", ascending: false)]
        
        database.perform(query, inZoneWith: zoneID) { records, error in
            defer { group.leave() }
            
            if let error = error as? CKError {
                switch error.code {
                case .notAuthenticated:
                    addResult("❌ Not authenticated with CloudKit")
                    addResult("   → iCloud sign-in may be incomplete")
                case .networkUnavailable, .networkFailure:
                    addResult("❌ Network error: \(error.localizedDescription)")
                case .permissionFailure:
                    addResult("❌ Permission denied")
                    addResult("   → Check iCloud capability in Xcode")
                case .badDatabase:
                    addResult("⚠️ Bad database configuration")
                case .internalError:
                    addResult("⚠️ Internal CloudKit error")
                case .zoneNotFound:
                    addResult("⚠️ SwiftData zone not found yet")
                    addResult("   → Add a photo from iPhone first")
                default:
                    addResult("⚠️ CloudKit error: \(error.localizedDescription)")
                    addResult("   Error code: \(error.code.rawValue)")
                }
            } else {
                addResult("✅ CloudKit Container: Accessible")
                addResult("   Found \(records?.count ?? 0) records in SwiftData zone")
                if let records = records, !records.isEmpty {
                    addResult("   Latest record: \(records.first?.recordID.recordName ?? "unknown")")
                }
            }
        }
        
        group.wait()
    }
    
    private func checkNetworkStatus() {
        // Simple network check
        if let url = URL(string: "https://www.apple.com") {
            let semaphore = DispatchSemaphore(value: 0)
            
            let task = URLSession.shared.dataTask(with: url) { _, response, error in
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
        
        // Try different query approaches
        addResult("Attempting to fetch records from SwiftData zone...")
        
        // SwiftData uses this specific zone
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        
        // Query without sort to avoid index issues
        let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: zoneID) { records, error in
            defer { group.leave() }
            
            if let error = error as? CKError {
                addResult("❌ Query failed: \(error.localizedDescription)")
                addResult("   Error code: \(error.code.rawValue)")
                
                // Provide helpful hints based on error
                if error.code == .badDatabase {
                    addResult("   💡 HINT: CloudKit schema may need setup")
                    addResult("   → Open CloudKit Dashboard")
                    addResult("   → Development → Schema")
                    addResult("   → Add indexes for CD_Item")
                } else if error.code == .zoneNotFound {
                    addResult("   💡 HINT: SwiftData zone doesn't exist yet")
                    addResult("   → Add a photo from iPhone first")
                    addResult("   → This will create the zone automatically")
                }
            } else if let records = records {
                addResult("✅ Successfully fetched \(records.count) records")
                
                if records.isEmpty {
                    addResult("   ℹ️ No photos found yet")
                    addResult("   → Add photos from iPhone")
                    addResult("   → They will sync to Apple TV automatically")
                } else {
                    addResult("   📸 Photos found:")
                    for (index, record) in records.prefix(5).enumerated() {
                        if let title = record["CD_title"] as? String {
                            addResult("   \(index + 1). \(title.isEmpty ? "Untitled" : title)")
                        } else {
                            addResult("   \(index + 1). Record: \(record.recordID.recordName)")
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

#Preview {
    TVDiagnosticsView()
}
#endif
