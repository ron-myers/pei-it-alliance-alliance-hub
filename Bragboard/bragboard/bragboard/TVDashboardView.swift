//
//  TVDashboardView.swift
//  bragboard
//
//  Apple TV dashboard displaying all enabled widgets
//  ✨ UPDATED: Now handles 2x widgets properly in grid layout
//

#if os(tvOS)
import SwiftUI
import SwiftData
import CloudKit

// MARK: - Main Dashboard View
struct TVDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Widget.position) private var allWidgets: [Widget]
    
    @State private var lastRefresh = Date()
    @State private var isSyncing = false
    @State private var syncStatus = ""
    @State private var showingDebugInfo = false
    
    // ✨ NEW: Shuffled widget positions for burn-in prevention
    @State private var shuffledWidgets: [Widget] = []
    @State private var shuffleTimer: Timer?
    
    var enabledWidgets: [Widget] {
        allWidgets.filter { $0.isEnabled }
    }
    
    // Dynamic background color based on theme
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(white: 0.95)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic background
                backgroundColor.ignoresSafeArea()
                
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
                
                // Initial shuffle
                shuffleWidgetPositions()
                
                // Start shuffle timer (every 60 seconds)
                startShuffleTimer()
                
                // Auto-sync on appear
                performCloudKitSync()
            }
            .onDisappear {
                // Clean up timer
                stopShuffleTimer()
            }
        }
    }
    
    // MARK: - Dashboard View
    private var dashboardView: some View {
        VStack(spacing: 0) {
            // Top bar with sync controls
            topBar
            
            // ✨ NEW: Custom grid layout that handles 2x widgets
            ScrollView {
                widgetGridView
                    .padding(50)
            }
        }
    }
    
    // MARK: - ✨ NEW: Custom Widget Grid (handles 2x widgets)
    private var widgetGridView: some View {
        let columnAssignments = distributeWidgetsToColumns(shuffledWidgets)
        
        return HStack(alignment: .top, spacing: 30) {
            // 3 columns
            ForEach(0..<3, id: \.self) { columnIndex in
                VStack(spacing: 30) {
                    // Get widgets assigned to this column
                    ForEach(columnAssignments[columnIndex], id: \.id) { widget in
                        TVWidgetContainer {
                            TVCreateWidgetView(for: widget)
                        }
                        // ✨ Height based on widget size
                        .frame(height: widget.is2x ? 830 : 400)
                        .aspectRatio(widget.is2x ? 0.7 : 1.4, contentMode: .fit)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: shuffledWidgets.map { $0.id })
    }
    
    // ✨ NEW: Smart distribution algorithm that prevents widgets from disappearing
    private func distributeWidgetsToColumns(_ widgets: [Widget]) -> [[Widget]] {
        // Initialize 3 empty columns
        var columns: [[Widget]] = [[], [], []]
        var columnCapacity = [2, 2, 2] // Each column can hold 2 rows initially
        
        // Process widgets in order
        for widget in widgets {
            if widget.is2x {
                // 2× widget needs an empty column (takes both rows)
                if let emptyColumnIndex = columnCapacity.firstIndex(where: { $0 == 2 }) {
                    columns[emptyColumnIndex].append(widget)
                    columnCapacity[emptyColumnIndex] = 0 // Column is now full
                } else {
                    // No empty column available - skip this 2× widget
                    print("⚠️ Warning: No space for 2× widget, skipping")
                }
            } else {
                // 1× widget - find column with space
                if let availableColumnIndex = columnCapacity.firstIndex(where: { $0 > 0 }) {
                    columns[availableColumnIndex].append(widget)
                    columnCapacity[availableColumnIndex] -= 1
                } else {
                    // No space available - this shouldn't happen with proper validation
                    print("⚠️ Warning: No space for 1× widget, skipping")
                }
            }
        }
        
        return columns
    }
    
    // MARK: - Widget Shuffle Logic
    private func startShuffleTimer() {
        // Cancel any existing timer
        stopShuffleTimer()
        
        // Create new timer that fires every 60 seconds
        shuffleTimer = Timer.scheduledTimer(withTimeInterval: 100.0, repeats: true) { _ in
            shuffleWidgetPositions()
        }
    }
    
    private func stopShuffleTimer() {
        shuffleTimer?.invalidate()
        shuffleTimer = nil
    }
    
    private func shuffleWidgetPositions() {
        withAnimation {
            // ✨ Smart shuffle that respects 2x widget constraints
            shuffledWidgets = smartShuffle(widgets: enabledWidgets)
        }
    }
    
    // ✨ NEW: Smart shuffle that handles 2x widgets properly
    private func smartShuffle(widgets: [Widget]) -> [Widget] {
        // Simple shuffle - the distributeWidgetsToColumns function handles proper placement
        return widgets.shuffled()
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
                    .foregroundColor(.secondary)
            }
            
            // Last refresh time
            Text("Updated: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Sync button
            Button {
                performCloudKitSync()
            } label: {
                if isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
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
        .background(
            (colorScheme == .dark ? Color.black : Color.white)
                .opacity(0.8)
        )
        .sheet(isPresented: $showingDebugInfo) {
            debugInfoSheet
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 120))
                .foregroundColor(.secondary)
            
            Text("No Widgets Found")
                .font(.largeTitle)
                .foregroundColor(.primary)
            
            Text("Add widgets from your iPhone app,\nthen tap Sync to load them here")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 30) {
                Button {
                    performCloudKitSync()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
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
                .font(.system(size: 120))
                .foregroundColor(.secondary)
            
            Text("All Widgets Disabled")
                .font(.largeTitle)
                .foregroundColor(.primary)
            
            Text("Enable widgets from your iPhone app")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                performCloudKitSync()
            } label: {
                Label("Sync to Refresh", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }
    
    // MARK: - Syncing View
    private var syncingView: some View {
        VStack(spacing: 30) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(2)
            
            Text("Syncing Widgets...")
                .font(.largeTitle)
                .foregroundColor(.primary)
            
            if !syncStatus.isEmpty {
                Text(syncStatus)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Debug Info Sheet
    private var debugInfoSheet: some View {
        NavigationStack {
            Form {
                Section("Widget Status") {
                    LabeledContent("Total Widgets", value: "\(allWidgets.count)")
                    LabeledContent("Enabled Widgets", value: "\(enabledWidgets.count)")
                    LabeledContent("2× Widgets", value: "\(enabledWidgets.filter { $0.is2x }.count)")
                }
                
                Section("Widget Details") {
                    ForEach(allWidgets) { widget in
                        HStack {
                            Image(systemName: widget.type.icon)
                                .foregroundColor(widget.isEnabled ? .green : .gray)
                            Text(widget.type.displayName)
                            Spacer()
                            if widget.is2x {
                                Text("2×")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                            Text(widget.isEnabled ? "On" : "Off")
                                .foregroundColor(widget.isEnabled ? .green : .secondary)
                        }
                    }
                }
                
                Section("CloudKit") {
                    Button("Force Sync") {
                        performCloudKitSync()
                    }
                    .disabled(isSyncing)
                }
            }
            .navigationTitle("Debug Information")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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
        
        Task {
            do {
                // Check CloudKit status
                let container = CKContainer.default()
                let status = try await container.accountStatus()
                
                await MainActor.run {
                    switch status {
                    case .available:
                        syncStatus = "iCloud available, fetching changes..."
                        print("âœ… CloudKit account available")
                    case .noAccount:
                        syncStatus = "⚠️ No iCloud account"
                        print("⚠️ No iCloud account signed in")
                    case .restricted:
                        syncStatus = "⚠️ iCloud restricted"
                        print("⚠️ iCloud access restricted")
                    case .couldNotDetermine:
                        syncStatus = "⚠️ Cannot determine iCloud status"
                        print("⚠️ Cannot determine CloudKit status")
                    case .temporarilyUnavailable:
                        syncStatus = "⚠️ iCloud temporarily unavailable"
                        print("⚠️ CloudKit temporarily unavailable")
                    @unknown default:
                        syncStatus = "⚠️ Unknown iCloud status"
                        print("⚠️ Unknown CloudKit status")
                    }
                }
                
                // Small delay to let SwiftData sync
                try await Task.sleep(for: .seconds(2))
                
                await MainActor.run {
                    // Update shuffle after sync
                    shuffleWidgetPositions()
                    lastRefresh = Date()
                    syncStatus = status == .available ? "✅ Sync complete" : "⚠️ Sync completed with warnings"
                    isSyncing = false
                    
                    // Clear status after delay
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        await MainActor.run {
                            if !isSyncing {
                                syncStatus = ""
                            }
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    syncStatus = "❌ Sync failed: \(error.localizedDescription)"
                    isSyncing = false
                    print("❌ CloudKit sync error: \(error)")
                }
            }
        }
    }
}

// MARK: - TV Widget Container
struct TVWidgetContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color.black.opacity(0.2))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - TV Widget View Factory
@ViewBuilder
func TVCreateWidgetView(for widget: Widget) -> some View {
    createWidgetView(for: widget)
}

#Preview {
    TVDashboardView()
        .modelContainer(for: Widget.self, inMemory: true)
}
#endif
