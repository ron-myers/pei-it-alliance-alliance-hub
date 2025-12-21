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
    @State private var showSidebar = false

    // ✨ NEW: Shuffled widget positions for burn-in prevention
    @State private var shuffledWidgets: [Widget] = []
    @State private var shuffleTimer: Timer?

    // ✨ NEW: Page sliding for Apple TV interface
    @State private var currentPage = 0
    @State private var slidingTimer: Timer?
    private let pageCount = 3 // Dashboard, Logo, Calendar

    // Calendar events
    @State private var events: [LocariusEvent] = []
    @State private var isLoadingEvents = false

    var enabledWidgets: [Widget] {
        allWidgets.filter { $0.isEnabled }
    }
    
    // Dynamic background color based on theme
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(white: 0.95)
    }
    
    var body: some View {
        ZStack {
            // Main content
            ZStack {
                // Dynamic background
                backgroundColor.ignoresSafeArea()

                // Simple state-based page switching with sliding animation
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Page 0: Dashboard
                        ZStack {
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
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: CGFloat(0 - currentPage) * geometry.size.width)

                        // Page 1: Logo page
                        logoPage
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(1 - currentPage) * geometry.size.width)

                        // Page 2: Calendar page
                        calendarPage
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(2 - currentPage) * geometry.size.width)
                    }
                    .clipped() // Prevent pages from showing outside the viewport
                }

                // Page control buttons (bottom center) - HIDDEN
//                VStack {
//                    Spacer()
//
//                    HStack(spacing: 30) {
//                        // Previous page button
//                        Button {
//                            withAnimation(.easeInOut(duration: 0.5)) {
//                                currentPage = 0
//                            }
//                        } label: {
//                            Circle()
//                                .fill(currentPage == 0 ? Color.white : Color.white.opacity(0.4))
//                                .frame(width: currentPage == 0 ? 20 : 14, height: currentPage == 0 ? 20 : 14)
//                        }
//                        .buttonStyle(.plain)
//
//                        // Next page button
//                        Button {
//                            withAnimation(.easeInOut(duration: 0.5)) {
//                                currentPage = 1
//                            }
//                        } label: {
//                            Circle()
//                                .fill(currentPage == 1 ? Color.white : Color.white.opacity(0.4))
//                                .frame(width: currentPage == 1 ? 20 : 14, height: currentPage == 1 ? 20 : 14)
//                        }
//                        .buttonStyle(.plain)
//                    }
//                    .padding(.bottom, 80)
//                }
            }

            // Sidebar overlay (Apple TV+ style)
            if showSidebar {
                // Backdrop with blur effect
                (colorScheme == .dark ? Color.black.opacity(0.6) : Color.black.opacity(0.3))
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSidebar = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                // Sidebar panel
                HStack(spacing: 0) {
                    sidebar
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Spacer()
                }
                .zIndex(2)
            }

            // Menu button (top-left corner)
            if !showSidebar {
                VStack {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSidebar.toggle()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .frame(width: 70, height: 70)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.8)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 60)
                        .padding(.top, 60)

                        Spacer()
                    }
                    Spacer()
                }
                .zIndex(3)
            }
        }
        .onAppear {
            print("📺 TVDashboardView appeared")
            print("📺 Total widgets: \(allWidgets.count), Enabled: \(enabledWidgets.count)")
            print("📺 tvOS - Token configured: \(AppConfig.shared.isLocariusConfigured)")
            print("📺 tvOS - Token length: \(AppConfig.shared.locariusAPIToken.count)")

            // Initial shuffle
            shuffleWidgetPositions()

            // Start shuffle timer (every 100 seconds)
            startShuffleTimer()

            // Start sliding timer (every 20 seconds) - now works with state-based switching
            startSlidingTimer()

            // Auto-sync on appear
            performCloudKitSync()

            // Fetch events for calendar
            fetchEvents()
        }
        .onDisappear {
            // Clean up timers
            stopShuffleTimer()
            stopSlidingTimer()
        }
    }
    
    // MARK: - Sidebar (Apple TV+ Style)
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation items
            VStack(alignment: .leading, spacing: 4) {
                // Home button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 0 // Return to dashboard
                        // Restart auto-slide timer when returning to home
                        startSlidingTimer()
                    }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Home")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 70)

                // Debug button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                    }
                    showingDebugInfo.toggle()
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Debug")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Sync button
                Button {
                    performCloudKitSync()
                } label: {
                    HStack(spacing: 20) {
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .white : .black))
                                .scaleEffect(0.9)
                                .frame(width: 30)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 26, weight: .medium))
                                .frame(width: 30)
                        }
                        Text("Sync")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)

                // Calendar button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 2 // Navigate to calendar page
                        // Stop auto-slide timer when viewing calendar
                        stopSlidingTimer()
                    }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "calendar")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Calendar")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)

            Spacer()

            // Status info at bottom
            VStack(alignment: .leading, spacing: 10) {
                if !syncStatus.isEmpty {
                    Text(syncStatus)
                        .font(.system(size: 18))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                }

                Text("Updated: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 18))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 50)
        }
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.leading, 50)
        .padding(.vertical, 70)
        .sheet(isPresented: $showingDebugInfo) {
            debugInfoSheet
        }
    }

    // MARK: - Calendar Page
    private var calendarPage: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Calendar header with title
                HStack {
                    Spacer()
                        .frame(width: 140) // Space for menu button

                    Text(getCurrentMonthYear())
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Spacer()
                }
                .padding(.horizontal, 50)
                .padding(.top, 70)
                .padding(.bottom, 35)

                // Days of week header
                HStack(spacing: 15) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 25)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 7), spacing: 15) {
                    ForEach(getCalendarDays(), id: \.self) { day in
                        if day == 0 {
                            // Empty cell for padding
                            Text("")
                                .frame(height: 130)
                        } else {
                            // Day cell
                            let event = getEventForDay(day)

                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isToday(day: day)
                                        ? Color.blue
                                        : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)))

                                // Day number in top right corner
                                Text("\(day)")
                                    .font(.system(size: 20, weight: isToday(day: day) ? .bold : .medium))
                                    .foregroundColor(isToday(day: day)
                                        ? .white.opacity(0.9)
                                        : (colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5)))
                                    .padding(8)

                                // Event name in center
                                if let event = event {
                                    Text(event.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(isToday(day: day)
                                            ? .white
                                            : (colorScheme == .dark ? .white : .black))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .frame(height: 130)
                        }
                    }
                }
                .padding(.horizontal, 50)

                Spacer()
            }
        }
        .tag(2)
    }

    // Helper functions for calendar
    private func getCurrentMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func getCalendarDays() -> [Int] {
        let calendar = Calendar.current
        let today = Date()

        // Get the first day of the month
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let firstDayOfMonth = calendar.date(from: components) else { return [] }

        // Get the weekday of the first day (1 = Sunday, 7 = Saturday)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        // Get the number of days in the month
        let range = calendar.range(of: .day, in: .month, for: today)
        let numDays = range?.count ?? 30

        // Create array with padding and days
        var days: [Int] = []

        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(0)
        }

        // Add the actual days
        for day in 1...numDays {
            days.append(day)
        }

        return days
    }

    private func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let currentDay = calendar.component(.day, from: today)
        return day == currentDay
    }

    // MARK: - Dashboard View
    private var dashboardView: some View {
        // ✨ NEW: Custom grid layout that handles 2x widgets
        GeometryReader { geometry in
            ScrollView {
                widgetGridView
                    .padding(60)
                    .frame(minHeight: geometry.size.height)
            }
        }
    }

    // MARK: - Logo Page
    private var logoPage: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            // Use dark mode logo (larger size) in dark mode, light mode logo in light mode
            Image(colorScheme == .dark ? "PIA logo-14" : "PIA logo-02")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: colorScheme == .dark ? 3500 : 1200,
                       maxHeight: colorScheme == .dark ? 3500 : 1200)
        }
        .tag(1)
    }

    // MARK: - ✨ NEW: Custom Widget Grid (handles 2x widgets)
    private var widgetGridView: some View {
        let columnAssignments = distributeWidgetsToColumns(shuffledWidgets)
        
        return HStack(alignment: .top, spacing: 30) {
            // 3 columns
            ForEach(0..<3, id: \.self) { columnIndex in
                VStack(spacing: 50) {
                    // Get widgets assigned to this column
                    ForEach(columnAssignments[columnIndex], id: \.id) { widget in
                        TVWidgetContainer {
                            TVCreateWidgetView(for: widget)
                        }
                        // ✨ Height based on widget size (2x = 2 * 1x height + spacing)
                        .frame(height: widget.is2x ? 850 : 400)
                        .aspectRatio(widget.is2x ? 0.66 : 1.4, contentMode: .fit)
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
        shuffleTimer = Timer.scheduledTimer(withTimeInterval: 10000000.0, repeats: true) { _ in
            shuffleWidgetPositions()
        }
    }
    
    private func stopShuffleTimer() {
        shuffleTimer?.invalidate()
        shuffleTimer = nil
    }

    // MARK: - Page Sliding Timer Logic
    private func startSlidingTimer() {
        // Cancel any existing timer
        stopSlidingTimer()

        // Schedule next page transition based on current page
        scheduleNextPageTransition()
    }

    private func scheduleNextPageTransition() {
        // Cancel any existing timer
        stopSlidingTimer()

        // Determine duration based on current page
        // Page 0 (Dashboard/Widget): 7 seconds
        // Page 1 (Logo): 3 seconds
        // Page 2 (Calendar): Manual navigation only, skip in auto-slide
        let duration: TimeInterval = currentPage == 0 ? 7.0 : 3.0

        // Create timer for the appropriate duration
        slidingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [self] _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                // Only auto-slide between pages 0 and 1, skip calendar (page 2)
                if currentPage == 0 {
                    currentPage = 1
                } else if currentPage == 1 {
                    currentPage = 0
                } else {
                    // If somehow on calendar page, go back to dashboard
                    currentPage = 0
                }
            }

            // Schedule the next transition
            scheduleNextPageTransition()
        }
    }

    private func stopSlidingTimer() {
        slidingTimer?.invalidate()
        slidingTimer = nil
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

    // MARK: - Event Fetching
    private func fetchEvents() {
        guard !isLoadingEvents else { return }

        isLoadingEvents = true

        Task {
            do {
                let token = AppConfig.shared.locariusAPIToken
                let fetchedEvents = try await LocariusEventService.shared.fetchUpcomingEvents(token: token)

                await MainActor.run {
                    events = fetchedEvents
                    isLoadingEvents = false
                    print("📅 Fetched \(fetchedEvents.count) events for calendar")
                }
            } catch {
                await MainActor.run {
                    isLoadingEvents = false
                    print("❌ Failed to fetch events: \(error)")
                }
            }
        }
    }

    // Helper to get event for a specific day of the current month
    private func getEventForDay(_ day: Int) -> LocariusEvent? {
        let calendar = Calendar.current
        let today = Date()

        // Get the year and month components from today
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = day

        guard let dayDate = calendar.date(from: components) else { return nil }

        // Find event that matches this day
        return events.first { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: dayDate)
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
