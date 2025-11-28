//
//  TVDashboardView.swift
//  bragboard
//
//  Apple TV dashboard displaying all enabled widgets
//  With manual CloudKit sync support and dark/light mode adaptation
//  ✨ NEW: Auto-shuffle widgets every 5 seconds to prevent screen burn
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
                
                // Start shuffle timer (every 5 seconds)
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
            
            // Widget grid - 3 columns, 2 rows = 6 widgets max
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30)
                    ],
                    spacing: 30
                ) {
                    // ✨ Use shuffled widgets instead of enabledWidgets
                    ForEach(shuffledWidgets) { widget in
                        TVWidgetContainer {
                            TVCreateWidgetView(for: widget)
                        }
                        .frame(height: 400)
                        .aspectRatio(1.4, contentMode: .fit)
                        // ✨ Smooth transition animation
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(50)
                // ✨ Animate position changes
                .animation(.easeInOut(duration: 0.8), value: shuffledWidgets.map { $0.id })
            }
        }
    }
    
    // MARK: - Widget Shuffle Logic
    private func startShuffleTimer() {
        // Cancel any existing timer
        stopShuffleTimer()
        
        // Create new timer that fires every 5 seconds
        shuffleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            shuffleWidgetPositions()
        }
    }
    
    private func stopShuffleTimer() {
        shuffleTimer?.invalidate()
        shuffleTimer = nil
    }
    
    private func shuffleWidgetPositions() {
        withAnimation {
            shuffledWidgets = enabledWidgets.shuffled()
        }
        print("🔀 Shuffled \(shuffledWidgets.count) widgets to prevent burn-in")
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
                .font(.system(size: 100))
                .foregroundColor(.secondary)
            
            Text("All Widgets Disabled")
                .font(.largeTitle)
                .foregroundColor(.primary)
            
            Text("You have \(allWidgets.count) widget(s) but none are enabled.\nEnable widgets from your iPhone app.")
                .font(.title3)
                .foregroundColor(.secondary)
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
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(2)
            
            Text("Syncing with iCloud...")
                .font(.title)
                .foregroundColor(.primary)
            
            Text(syncStatus)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Debug Sheet
    private var debugInfoSheet: some View {
        NavigationStack {
            List {
                Section("Widget Status") {
                    LabeledContent("Total Widgets", value: "\(allWidgets.count)")
                    LabeledContent("Enabled", value: "\(enabledWidgets.count)")
                    LabeledContent("Disabled", value: "\(allWidgets.count - enabledWidgets.count)")
                }
                
                Section("CloudKit Status") {
                    LabeledContent("Last Sync", value: lastRefresh.formatted(date: .numeric, time: .shortened))
                    if !syncStatus.isEmpty {
                        LabeledContent("Status", value: syncStatus)
                    }
                }
                
                Section("Shuffle Status") {
                    LabeledContent("Auto-Shuffle", value: "Every 5 seconds")
                    LabeledContent("Current Order", value: "\(shuffledWidgets.count) widgets")
                }
                
                if !allWidgets.isEmpty {
                    Section("All Widgets") {
                        ForEach(allWidgets) { widget in
                            HStack {
                                Image(systemName: widget.type.icon)
                                    .foregroundColor(widget.isEnabled ? .green : .gray)
                                
                                VStack(alignment: .leading) {
                                    Text(widget.type.displayName)
                                        .font(.headline)
                                    Text("Position: \(widget.position)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(widget.isEnabled ? "Enabled" : "Disabled")
                                    .font(.caption)
                                    .foregroundColor(widget.isEnabled ? .green : .gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard Diagnostics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
        syncStatus = "Syncing..."
        
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.rhlee.bragboard")
                let database = container.privateCloudDatabase
                
                syncStatus = "Checking iCloud..."
                
                // Simple query to trigger sync
                let query = CKQuery(recordType: "CD_Widget", predicate: NSPredicate(value: true))
                let results = try await database.records(matching: query)
                
                syncStatus = "Found \(results.matchResults.count) record(s)"
                
                // Give SwiftData time to process
                try await Task.sleep(for: .seconds(2))
                
                await MainActor.run {
                    lastRefresh = Date()
                    isSyncing = false
                    
                    // ✨ Clear sync status after successful sync
                    if !allWidgets.isEmpty {
                        // If we have widgets, clear the status
                        syncStatus = ""
                    } else {
                        // If still no widgets, show helpful message
                        syncStatus = results.matchResults.isEmpty ? "No widgets found - add from iPhone" : "Synced ✓"
                    }
                    
                    // Refresh shuffled widgets after sync
                    shuffleWidgetPositions()
                    
                    // ✨ Auto-clear success message after 3 seconds
                    if !syncStatus.isEmpty && !syncStatus.contains("No widgets") {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            await MainActor.run {
                                syncStatus = ""
                            }
                        }
                    }
                }
                
                print("✅ CloudKit sync completed - \(results.matchResults.count) records found")
            } catch {
                await MainActor.run {
                    isSyncing = false
                    
                    // ✨ Only show error if we have no widgets
                    if allWidgets.isEmpty {
                        syncStatus = "Sync failed - retrying..."
                        print("❌ CloudKit sync error: \(error)")
                        
                        // Auto-retry after 3 seconds
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            await MainActor.run {
                                performCloudKitSync()
                            }
                        }
                    } else {
                        // If we already have widgets, silently ignore sync errors
                        syncStatus = ""
                        print("⚠️ CloudKit sync error (ignored - widgets already loaded): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Widget Factory (TV-specific)
@ViewBuilder
private func TVCreateWidgetView(for widget: Widget) -> some View {
    switch widget.type {
    case .companyLogo:
        TVLogoWidgetView(widget: widget)
    case .customerCount:
        TVCustomerCounterWidgetView(widget: widget)
    case .instagramFollowers:
        TVInstagramFollowersWidgetView(widget: widget)
    case .locationsMap:
        TVLocationMapWidgetView(widget: widget)
    case .yearsInBusiness:
        TVYearsInBusinessWidgetView(widget: widget)
    case .daysSinceIncident:
        TVDaysSinceIncidentWidgetView(widget: widget)
    case .hiringBadge:
        TVHiringBadgeWidgetView(widget: widget)
    default:
        TVPlaceholderWidgetView(widget: widget)
    }
}

// MARK: - Widget Container (Common styling)
private struct TVWidgetContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                (colorScheme == .dark ? Color.black : Color.white)
                    .opacity(colorScheme == .dark ? 0.2 : 0.8)
            )
            .cornerRadius(24)
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.1),
                radius: 10,
                x: 0,
                y: 5
            )
    }
}

// MARK: - Company Logo Widget
private struct TVLogoWidgetView: View {
    let widget: Widget
    
    var body: some View {
        VStack {
            Spacer()
            if let imageData = widget.configuration?.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "building.2")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("Add Logo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - Customer Counter Widget
private struct TVCustomerCounterWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme
    
    private var label: String {
        let configLabel = widget.configuration?.counterLabel ?? ""
        return configLabel.isEmpty ? "Customers Served" : configLabel
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text(MockDataService.formatNumber(
                widget.configuration?.counterValue ?? 0,
                style: .full
            ))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text(label)
                .font(.title3)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue.opacity(colorScheme == .dark ? 0.6 : 0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    Color.purple.opacity(colorScheme == .dark ? 0.3 : 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Instagram Followers Widget
private struct TVInstagramFollowersWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme
    @State private var followerCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            Text(MockDataService.formatNumber(followerCount))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text("Instagram Followers")
                .font(.title3)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("SAMPLE DATA")
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            (colorScheme == .dark ? Color.black : Color.white)
                .opacity(colorScheme == .dark ? 0.3 : 0.5)
        )
        .onAppear {
            followerCount = MockDataService.shared.getInstagramFollowers()
        }
    }
}

// MARK: - Location Map Widget
private struct TVLocationMapWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme
    @State private var locations: [String] = []
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(colorScheme == .dark ? 0.3 : 0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            Text("\(locations.count)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text("Locations Worldwide")
                .font(.title3)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("SAMPLE DATA")
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [
                    Color.green.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    Color.teal.opacity(colorScheme == .dark ? 0.3 : 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onAppear {
            locations = MockDataService.shared.getLocationNames()
        }
    }
}

// MARK: - Years in Business Widget
private struct TVYearsInBusinessWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme
    
    private var yearsInBusiness: Int {
        guard let startDate = widget.configuration?.startDate else { return 0 }
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: startDate, to: Date()).year ?? 0
        return max(0, years)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(yearsInBusiness)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text(yearsInBusiness == 1 ? "Year" : "Years")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text("In Business")
                .font(.title3)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            if let startDate = widget.configuration?.startDate {
                Text("Since \(startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Set start date")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    Color.cyan.opacity(colorScheme == .dark ? 0.3 : 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Days Since Incident Widget
private struct TVDaysSinceIncidentWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme
    
    private var daysSinceIncident: Int {
        guard let incidentDate = widget.configuration?.incidentDate else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: incidentDate, to: Date()).day ?? 0
        return max(0, days)
    }
    
    private var incidentLabel: String {
        widget.configuration?.incidentLabel ?? "Last Incident"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(colorScheme == .dark ? 0.3 : 0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(daysSinceIncident)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text(daysSinceIncident == 1 ? "Day" : "Days")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text("Since \(incidentLabel)")
                .font(.title3)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            if let incidentDate = widget.configuration?.incidentDate {
                Text("Last: \(incidentDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Set incident date")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [
                    Color.green.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    Color.mint.opacity(colorScheme == .dark ? 0.3 : 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - ✨ NEW: We're Hiring Badge Widget
private struct TVHiringBadgeWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(colorScheme == .dark ? 0.3 : 0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(1 + sin(animationPhase) * 0.1)
                
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animationPhase = .pi * 2
                }
            }
            
            // Main message
            Text("WE'RE HIRING!")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            // Subtitle
            Text("Join Our Team")
                .font(.title2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            // Badge
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                Text("Now Accepting Applications")
                    .font(.caption)
                Image(systemName: "sparkles")
                    .font(.caption)
            }
            .foregroundColor(.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.2))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [
                    Color.green.opacity(colorScheme == .dark ? 0.25 : 0.12),
                    Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Placeholder Widget
private struct TVPlaceholderWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: widget.type.icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(widget.type.displayName)
                .font(.title3)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color.secondary.opacity(colorScheme == .dark ? 0.1 : 0.05))
    }
}

#Preview {
    TVDashboardView()
        .modelContainer(for: Widget.self, inMemory: true)
}
#endif
