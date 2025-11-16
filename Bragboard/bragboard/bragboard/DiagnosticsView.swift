//
//  DiagnosticsView.swift
//  bragboard
//
//  Diagnostic tool to check iCloud and CloudKit status
//
import SwiftUI
import CloudKit

struct DiagnosticsView: View {
    @State private var diagnosticResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Diagnostic Results") {
                    if diagnosticResults.isEmpty {
                        Text("Tap 'Run Diagnostics' to check iCloud status")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(diagnosticResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                Section {
                    Button(action: runDiagnostics) {
                        if isRunning {
                            HStack {
                                ProgressView()
                                Text("Running...")
                            }
                        } else {
                            Text("Run Diagnostics")
                        }
                    }
                    .disabled(isRunning)
                }
            }
            .navigationTitle("iCloud Diagnostics")
        }
    }
    
    private func runDiagnostics() {
        isRunning = true
        diagnosticResults = []
        
        addResult("🔍 Starting Diagnostics...")
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
        addResult("🔐 CHECK 4: CloudKit Permissions")
        checkCloudKitPermissions()
        
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
        
        // Try to fetch a record to see if container is accessible
        let group = DispatchGroup()
        group.enter()
        
        let database = container.privateCloudDatabase
        let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: nil) { records, error in
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
        // Simple network check
        if let url = URL(string: "https://www.apple.com") {
            let task = URLSession.shared.dataTask(with: url) { _, response, error in
                if error != nil {
                    addResult("❌ No internet connection")
                } else {
                    addResult("✅ Internet: Connected")
                }
            }
            task.resume()
            Thread.sleep(forTimeInterval: 1.0) // Wait for response
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
    
    private func addResult(_ text: String) {
        DispatchQueue.main.async {
            diagnosticResults.append(text)
        }
    }
}

#Preview {
    DiagnosticsView()
}
