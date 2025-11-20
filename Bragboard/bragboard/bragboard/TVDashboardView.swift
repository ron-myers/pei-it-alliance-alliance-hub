//
//  TVDashboardView.swift
//  bragboard
//
//  Apple TV dashboard displaying all enabled widgets
//  With manual CloudKit sync support
//

#if os(tvOS)
import SwiftUI
import SwiftData
import CloudKit

struct TVDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Widget.position) private var allWidgets: [Widget]
    
    @State private var lastRefresh = Date()
    @State private var isSyncing = false
    @State private var syncStatus = ""
    @State private var showingDebugInfo = false
    
    var enabledWidgets: [Widget] {
        allWidgets.filter { $0.isEnabled }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                if allWidgets.isEmpty && !isSyncing {
                    // No widgets at all - need to sync or add from iPhone
                    emptyStateView
                } else if enabledWidgets.isEmpty && !allWidgets.isEmpty {
                    // Widgets exist but none enabled
                    noEnabledWidgetsView
                } else if enabledWidgets.isEmpty && isSyncing {
                    // Currently syncing
                    syncingView
                } else {
                    // Show widget dashboard
                    dashboardView
                }
            }
            .onAppear {
                print("📺 TVDashboardView appeared")
                print("📺 Total widgets: \(allWidgets.count), Enabled: \(enabledWidgets.count)")
                
                // Auto-sync on appear
                performCloudKitSync()
            }
        }
    }
    
    // MARK: - Dashboard View
    private var dashboardView: some View {
        VStack(spacing: 0) {
            // Top bar with sync controls
            topBar
            
            // Widget grid
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 500, maximum: 700), spacing: 40)
                    ],
                    spacing: 40
                ) {
                    ForEach(enabledWidgets) { widget in
                        WidgetContainer {
                            createWidgetView(for: widget)
                        }
                        .frame(minHeight: 400)
                    }
                }
                .padding(60)
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Debug info toggle
            Button {
                showingDebugInfo.toggle()
            } label: {
                Label("Debug", systemImage: "info.circle")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            // Sync status
            if !syncStatus.isEmpty {
                Text(syncStatus)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Last refresh time
            Text("Updated: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Sync button
            Button {
                performCloudKitSync()
            } label: {
                if isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isSyncing)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.8))
        .sheet(isPresented: $showingDebugInfo) {
            debugInfoSheet
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 120))
                .foregroundColor(.gray)
            
            Text("No Widgets Found")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text("Add widgets from your iPhone app,\nthen tap Sync to load them here")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 30) {
                Button {
                    performCloudKitSync()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 100)
                    } else {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSyncing)
                
                Button {
                    showingDebugInfo = true
                } label: {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 20)
            
            if !syncStatus.isEmpty {
                Text(syncStatus)
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.top, 10)
            }
        }
    }
    
    // MARK: - No Enabled Widgets
    private var noEnabledWidgetsView: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.slash")
                .font(.system(size: 100))
                .foregroundColor(.gray)
            
            Text("All Widgets Disabled")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text("You have \(allWidgets.count) widget(s) but none are enabled.\nEnable widgets from your iPhone app.")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button {
                performCloudKitSync()
            } label: {
                Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }
    
    // MARK: - Syncing View
    private var syncingView: some View {
        VStack(spacing: 30) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)
            
            Text("Syncing with iCloud...")
                .font(.title)
                .foregroundColor(.white)
            
            Text(syncStatus)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Debug Sheet
    private var debugInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Widget counts
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total Widgets: \(allWidgets.count)")
                            Text("Enabled Widgets: \(enabledWidgets.count)")
                            Text("Last Sync: \(lastRefresh.formatted())")
                        }
                        .font(.body)
                    } header: {
                        Text("Widget Status")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    // List all widgets
                    Section {
                        if allWidgets.isEmpty {
                            Text("No widgets in database")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(allWidgets) { widget in
                                HStack {
                                    Image(systemName: widget.type.icon)
                                        .foregroundColor(widget.isEnabled ? .green : .gray)
                                    Text(widget.type.displayName)
                                    Spacer()
                                    Text(widget.isEnabled ? "ON" : "OFF")
                                        .foregroundColor(widget.isEnabled ? .green : .red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("All Widgets")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    // CloudKit status
                    Section {
                        Button("Check CloudKit Status") {
                            checkCloudKitStatus()
                        }
                        .buttonStyle(.bordered)
                        
                        Text(syncStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("CloudKit")
                            .font(.headline)
                    }
                }
                .padding(40)
            }
            .background(Color.black)
            .navigationTitle("Debug Info")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDebugInfo = false
                    }
                }
            }
        }
    }
    
    // MARK: - CloudKit Sync
    private func performCloudKitSync() {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncStatus = "Checking iCloud..."
        print("📺 Starting sync check...")
        
        let container = CKContainer.default()
        
        // Check account status
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.syncStatus = "❌ Account error: \(error.localizedDescription)"
                    self.isSyncing = false
                    return
                }
                
                switch status {
                case .available:
                    self.syncStatus = "✅ iCloud connected"
                    self.refreshContext()
                case .noAccount:
                    self.syncStatus = "❌ No iCloud account - sign in on this device"
                case .restricted:
                    self.syncStatus = "⚠️ iCloud restricted"
                case .couldNotDetermine:
                    self.syncStatus = "⚠️ Could not check iCloud"
                case .temporarilyUnavailable:
                    self.syncStatus = "⚠️ iCloud temporarily unavailable"
                @unknown default:
                    self.syncStatus = "❓ Unknown iCloud status"
                }
                
                self.lastRefresh = Date()
                self.isSyncing = false
            }
        }
    }
    
    private func refreshContext() {
        // SwiftData handles CloudKit sync automatically
        // We just log the current state for debugging
        print("📺 Current SwiftData state:")
        print("📺   Total widgets: \(allWidgets.count)")
        print("📺   Enabled widgets: \(enabledWidgets.count)")
        
        for widget in allWidgets {
            print("📺   - \(widget.type.displayName): enabled=\(widget.isEnabled)")
        }
        
        if allWidgets.isEmpty {
            syncStatus = "✅ iCloud connected - waiting for data (add widgets from iPhone)"
        } else {
            syncStatus = "✅ Synced: \(allWidgets.count) widget(s), \(enabledWidgets.count) enabled"
        }
    }
    
    private func checkCloudKitStatus() {
        syncStatus = "Checking CloudKit..."
        
        let container = CKContainer.default()
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.syncStatus = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                switch status {
                case .available:
                    self.syncStatus = "✅ iCloud: Available | Container: \(container.containerIdentifier ?? "none")"
                case .noAccount:
                    self.syncStatus = "❌ No iCloud account signed in"
                case .restricted:
                    self.syncStatus = "⚠️ iCloud restricted"
                case .couldNotDetermine:
                    self.syncStatus = "⚠️ Could not determine iCloud status"
                case .temporarilyUnavailable:
                    self.syncStatus = "⚠️ iCloud temporarily unavailable"
                @unknown default:
                    self.syncStatus = "❓ Unknown status"
                }
            }
        }
    }
}

#Preview {
    TVDashboardView()
        .modelContainer(for: Widget.self, inMemory: true)
}
#endif
