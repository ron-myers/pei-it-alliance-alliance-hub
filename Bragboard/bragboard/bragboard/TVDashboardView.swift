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
    @Query(sort: \AlbumPhoto.displayOrder) private var albumPhotos: [AlbumPhoto]

    @State private var lastRefresh = Date()
    @State private var isSyncing = false
    @State private var syncStatus = ""
    @State private var showingDebugInfo = false
    @State private var showSidebar = false
    @State private var showMenuButton = false  // Auto-hide menu button
    @State private var hideButtonTimer: Timer?  // Timer to hide button after inactivity

    // ✨ NEW: Shuffled widget positions for burn-in prevention
    @State private var shuffledWidgets: [Widget] = []
    @State private var shuffleTimer: Timer?

    // ✨ NEW: Page sliding for Apple TV interface
    @State private var currentPage = 0
    @State private var slidingTimer: Timer?
    private let pageCount = DashboardPage.allCases.count

    // Which pages rotate, for how long, and whether the page indicator shows
    @State private var settings = DashboardSettings()
    @State private var showSettings = false

    // Pitch competition clock — takes over the screen, nothing else runs behind it
    @State private var showPitchTimer = false

    // Photo album state
    @State private var photoTimer: Timer?
    @State private var currentPhotoIndex: Int = 0

    // Calendar events
    @State private var events: [LocariusEvent] = []
    @State private var isLoadingEvents = false
    @State private var calendarViewMode: CalendarViewMode = .techWeek

    // Event countdown page state
    @State private var countdownEvent: LocariusEvent?
    @State private var countdownTimer: Timer?
    @State private var countdownCurrentTime = Date()

    enum CalendarViewMode {
        case techWeek
        case month
        case threeDays
    }

    // Tech Week programme, derived from the same Locarius feed as the calendar.
    // Held in state rather than recomputed, because it is read many times per redraw.
    @State private var techWeek = TechWeekSchedule(events: [])

    // Co-op Placements roster, read once from the bundled JSON
    @State private var coopStudents: [CoopStudent] = []

    /// The calendar defaults to the Tech Week strip, and falls back to the month grid once the week has passed
    private var effectiveCalendarMode: CalendarViewMode {
        if calendarViewMode == .techWeek && techWeek.isEmpty { return .month }
        return calendarViewMode
    }

    var enabledWidgets: [Widget] {
        // Filter out Countries Served widget - it's only shown as full-screen page, not in dashboard
        allWidgets.filter { $0.isEnabled && $0.type != .countriesServed }
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

                        // Page 3: Photos page
                        photosPage
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(3 - currentPage) * geometry.size.width)

                        // Page 4: Event Countdown page
                        eventCountdownPage
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(4 - currentPage) * geometry.size.width)

                        // Page 5: Co-op Placements slideshow
                        CoopPlacementsSlideshowView(students: coopStudents, isVisible: currentPage == 5)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(5 - currentPage) * geometry.size.width)

                        // Page 6: Tech Week slideshow — drops out of the rotation on its
                        // own whenever Locarius has no Tech Week sessions, and comes back
                        // by itself when next year's are published.
                        TechWeekSlideshowView(schedule: techWeek, isVisible: currentPage == 6)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(6 - currentPage) * geometry.size.width)
                    }
                    .clipped() // Prevent pages from showing outside the viewport
                }
                .ignoresSafeArea() // Pages run edge to edge — otherwise coloured pages show a black border

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
                    .contentShape(Rectangle())  // CRITICAL: Define explicit hit-test bounds to prevent blocking all touches
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

            // Menu button (top-left corner) - Auto-hide
            if !showSidebar && !showSettings && !showPitchTimer && showMenuButton {
                VStack {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSidebar.toggle()
                                // Hide menu button when sidebar opens
                                showMenuButton = false
                                stopHideButtonTimer()
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
                        .buttonStyle(.card)
                        .padding(.leading, 60)
                        .padding(.top, 60)

                        Spacer()
                    }
                    Spacer()
                }
                .zIndex(3)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            // Page indicators (bottom center) - Apple TV style
            if !showSidebar && !showSettings && !showPitchTimer && settings.showPageDots {
                VStack {
                    Spacer()

                    HStack(spacing: 12) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: currentPage == index ? 12 : 8, height: currentPage == index ? 12 : 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .padding(.bottom, 6)
                }
                .zIndex(3)
                .allowsHitTesting(false)  // Don't block taps
            }

            // Settings — covers everything, and holds the rotation while it's open
            if showSettings {
                DashboardSettingsView(
                    settings: settings,
                    onDebug: { showingDebugInfo = true }
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettings = false
                    }
                    startSlidingTimer()
                }
                .transition(.opacity)
                .zIndex(4)
            }

            // Pitch timer — above everything, including settings - COMMENTED OUT (not needed for now)
//            if showPitchTimer {
//                PitchTimerView {
//                    withAnimation(.easeInOut(duration: 0.3)) {
//                        showPitchTimer = false
//                    }
//                    startSlidingTimer()
//                }
//                .transition(.opacity)
//                .zIndex(5)
//            }
        }
        #if os(tvOS)
        .overlay {
            // Invisible focusable area for tvOS remote interaction
            // CRITICAL: Only capture touches when menu button is hidden, otherwise it blocks all clicks
            if !showSidebar && !showSettings && !showPitchTimer && !showMenuButton {
                Color.clear
                    .contentShape(Rectangle())
                    .focusable(true)
                    .onLongPressGesture(minimumDuration: 0.01) {
                        // Triggers on Select button press
                        revealMenuButton()
                    }
                    .onPlayPauseCommand {
                        // Also handle Play/Pause button
                        revealMenuButton()
                    }
                    .onMoveCommand { _ in
                        // Any swipe or arrow on the remote also brings the menu back
                        revealMenuButton()
                    }
            }
        }
        #else
        .contentShape(Rectangle())
        .onTapGesture {
            // Show menu button on tap/click (iOS)
            // Only capture tap if menu button is not already visible
            if !showMenuButton && !showSidebar {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMenuButton = true
                }
                startHideButtonTimer()
            }
        }
        #endif
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

            // Load the Co-op Placements roster from the bundle
            coopStudents = CoopStudent.loadRoster()

            // Start whichever timers the opening page needs
            pageTimers(for: currentPage)
        }
        .onChange(of: currentPage) { _, page in
            pageTimers(for: page)
        }
        .onDisappear {
            // Clean up timers
            stopShuffleTimer()
            stopSlidingTimer()
            stopPhotoTimer()
            stopCountdownTimer()
            stopHideButtonTimer()
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
                        // Restart auto-slide timer (cycles through Dashboard -> Logo -> Calendar)
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
                .buttonStyle(.card)
                .padding(.top, 70)


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
                .buttonStyle(.card)
                .disabled(isSyncing)

                // Calendar button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 2 // Navigate to calendar page
                        // Auto-slide will continue from calendar page
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
                .buttonStyle(.card)

                // Photos button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 3 // Navigate to photos page
                        // Auto-slide will continue from photos page
                    }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Photos")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)

                // Countdown button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 4 // Navigate to event countdown page
                    }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "timer")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Countdown")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)

                // Logo button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 1 // Navigate to logo page
                        startSlidingTimer()
                    }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "building.2")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Logo")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)

                // Co-op Placements button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 5 // Navigate to Co-op Placements slideshow
                        startSlidingTimer()
                    }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "graduationcap")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Co-op Placements")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)
                .disabled(coopStudents.isEmpty)

                // Tech Week button — greys out by itself when there is no schedule
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        currentPage = 6 // Navigate to Tech Week slideshow
                        startSlidingTimer()
                    }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Tech Week")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)
                .disabled(techWeek.isEmpty)

                // Pitch Timer button - COMMENTED OUT (not needed for now)
//                Button {
//                    withAnimation(.easeInOut(duration: 0.3)) {
//                        showSidebar = false
//                        showPitchTimer = true
//                    }
//                    stopSlidingTimer()
//                } label: {
//                    HStack(spacing: 20) {
//                        Image(systemName: "stopwatch")
//                            .font(.system(size: 26, weight: .medium))
//                            .frame(width: 30)
//                        Text("Pitch Timer")
//                            .font(.system(size: 32, weight: .medium))
//                    }
//                    .foregroundColor(colorScheme == .dark ? .white : .black)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.horizontal, 36)
//                    .padding(.vertical, 16)
//                    .contentShape(Rectangle())
//                }
//                .buttonStyle(.card)

                // Settings button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar = false
                        showSettings = true
                    }
                    stopSlidingTimer()
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 26, weight: .medium))
                            .frame(width: 30)
                        Text("Settings")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)

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
                // Calendar header with title and toggle button
                HStack {
                    Spacer()
                        .frame(width: 140) // Space for menu button

                    VStack(spacing: 10) {
                        Text(calendarTitle)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        if !techWeek.isEmpty && effectiveCalendarMode != .techWeek {
                            Text("PEI TECH WEEK  ·  \(techWeek.dateRangeLabel)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(TechWeekTheme.gradient))
                        }
                    }

                    Spacer()

                    // Toggle button (top right) - cycles Tech Week -> Month -> Upcoming Days
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cycleCalendarMode()
                        }
                    } label: {
                        Image(systemName: calendarToggleIcon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .frame(width: 70, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 50)
                }
                .padding(.horizontal, 50)
                .padding(.top, 70)
                .padding(.bottom, 35)

                switch effectiveCalendarMode {
                case .techWeek:
                    techWeekWeekView
                case .month:
                    monthView
                case .threeDays:
                    threeDayView
                }
            }
        }
        .tag(2)
    }

    // MARK: - Calendar Header Helpers
    private var calendarTitle: String {
        switch effectiveCalendarMode {
        case .techWeek: return "PEI Tech Week  ·  \(techWeek.dateRangeLabel)"
        case .month: return getCurrentMonthYear()
        case .threeDays: return "Upcoming Days"
        }
    }

    private var calendarToggleIcon: String {
        switch effectiveCalendarMode {
        case .techWeek: return "calendar"
        case .month: return "calendar.day.timeline.left"
        case .threeDays: return "sparkles.tv"
        }
    }

    private func cycleCalendarMode() {
        switch effectiveCalendarMode {
        case .techWeek: calendarViewMode = .month
        case .month: calendarViewMode = .threeDays
        case .threeDays: calendarViewMode = techWeek.isEmpty ? .month : .techWeek
        }
    }

    // MARK: - Tech Week Week View
    /// One column per Tech Week day, every session listed — unlike the month grid, which shows one per day
    private var techWeekWeekView: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(techWeek.days, id: \.self) { day in
                VStack(spacing: 14) {
                    // Day header
                    VStack(spacing: 0) {
                        Text(calendarDayLabel(day, format: "EEE").uppercased())
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text(calendarDayLabel(day, format: "d"))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(TechWeekTheme.gradient))

                    ForEach(sessions(on: day), id: \.id) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.timeOfDay)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(TechWeekTheme.coral)

                            Text(session.techWeekTitle)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                        )
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(.horizontal, 50)
        .padding(.bottom, 70)
    }

    private func sessions(on day: Date) -> [LocariusEvent] {
        let calendar = Calendar.current
        return techWeek.sessions.filter { session in
            guard let date = session.startDate else { return false }
            return calendar.isDate(date, inSameDayAs: day)
        }
    }

    private func calendarDayLabel(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    // MARK: - Month View
    private var monthView: some View {
        VStack(spacing: 0) {
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
                        let isTechWeek = isTechWeekDay(day: day)
                        let isHighlighted = isToday(day: day) || isTechWeek

                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isToday(day: day)
                                    ? Color.blue
                                    : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)))
                                .overlay(
                                    // Tech Week days wear the event branding
                                    isTechWeek
                                        ? RoundedRectangle(cornerRadius: 12).fill(TechWeekTheme.gradient).opacity(isToday(day: day) ? 0.55 : 1)
                                        : nil
                                )

                            // Day number in top right corner
                            Text("\(day)")
                                .font(.system(size: 20, weight: isHighlighted ? .bold : .medium))
                                .foregroundColor(isHighlighted
                                    ? .white.opacity(0.9)
                                    : (colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5)))
                                .padding(8)

                            // Event name in center
                            if let event = event {
                                Text(isTechWeek ? event.techWeekTitle : event.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isHighlighted
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

    // MARK: - 3-Day View
    private var threeDayView: some View {
        let threeDays = getNextThreeDays()
        let timeRange = calculateTimeRange(for: threeDays)

        return HStack(alignment: .top, spacing: 20) {
            ForEach(threeDays, id: \.date) { dayInfo in
                VStack(spacing: 0) {
                    // Day header
                    VStack(spacing: 8) {
                        Text(dayInfo.dayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(dayInfo.isToday ? .blue : (colorScheme == .dark ? .white : .black))

                        Text(dayInfo.dateString)
                            .font(.system(size: 16))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                    }
                    .padding(.bottom, 20)

                    // Time slots with events
                    if dayInfo.events.isEmpty {
                        // No events - show placeholder
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "calendar.badge.minus")
                                .font(.system(size: 50))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.2))
                            Text("No events recorded")
                                .font(.system(size: 20))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                        )
                    } else {
                        // Has events - show timeline
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(timeRange.startHour...timeRange.endHour, id: \.self) { hour in
                                    timeSlotRow(hour: hour, events: dayInfo.events, isToday: dayInfo.isToday)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 50)
        .padding(.bottom, 40)
    }

    // Time slot row for 3-day view
    private func timeSlotRow(hour: Int, events: [LocariusEvent], isToday: Bool) -> some View {
        let eventsInHour = events.filter { event in
            guard let startDate = event.startDate else { return false }
            let calendar = Calendar.current
            return calendar.component(.hour, from: startDate) == hour
        }

        return HStack(spacing: 12) {
            // Time label
            Text(formatHour(hour))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                .frame(width: 80, alignment: .trailing)

            // Event area
            if eventsInHour.isEmpty {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 60)
                    .overlay(
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .frame(height: 1),
                        alignment: .top
                    )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(eventsInHour, id: \.id) { event in
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(isToday ? Color.blue : Color.purple)
                                .frame(width: 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .lineLimit(2)

                                if let startDate = event.startDate {
                                    Text(formatEventTime(startDate))
                                        .font(.system(size: 13))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isToday ? Color.blue.opacity(0.2) : Color.purple.opacity(0.15))
                        )
                    }
                }
                .frame(height: 60)
            }
        }
        .padding(.horizontal, 16)
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

    private func isTechWeekDay(day: Int) -> Bool {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.day = day
        guard let dayDate = calendar.date(from: components) else { return false }
        return techWeek.isTechWeekDay(dayDate)
    }

    // Helper structures for 3-day view
    struct DayInfo: Identifiable {
        let id = UUID()
        let date: Date
        let dayName: String
        let dateString: String
        let isToday: Bool
        let events: [LocariusEvent]
    }

    struct TimeRange {
        let startHour: Int
        let endHour: Int
    }

    // Get next 3 days starting from today
    private func getNextThreeDays() -> [DayInfo] {
        let calendar = Calendar.current
        let today = Date()

        var days: [DayInfo] = []

        for offset in 0..<3 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

            // Format day name
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let dayName = dayFormatter.string(from: date)

            // Format date string
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let dateString = dateFormatter.string(from: date)

            // Check if today
            let isToday = calendar.isDateInToday(date)

            // Get events for this day
            let dayEvents = events.filter { event in
                guard let eventDate = event.startDate else { return false }
                return calendar.isDate(eventDate, inSameDayAs: date)
            }

            days.append(DayInfo(
                date: date,
                dayName: dayName,
                dateString: dateString,
                isToday: isToday,
                events: dayEvents
            ))
        }

        return days
    }

    // Calculate dynamic time range based on events across all 3 days
    private func calculateTimeRange(for days: [DayInfo]) -> TimeRange {
        let allEvents = days.flatMap { $0.events }

        guard !allEvents.isEmpty else {
            // No events - default range 8am to 5pm
            return TimeRange(startHour: 8, endHour: 17)
        }

        let calendar = Calendar.current
        var earliestHour = 23
        var latestHour = 0

        for event in allEvents {
            guard let startDate = event.startDate else { continue }

            let startHour = calendar.component(.hour, from: startDate)

            // Estimate end time as 2 hours after start (typical event duration)
            let estimatedEndHour = min(23, startHour + 2)

            earliestHour = min(earliestHour, startHour)
            latestHour = max(latestHour, estimatedEndHour)
        }

        // Add padding - 2 hours before earliest, 2 hours after latest
        let startHour = max(0, earliestHour - 2)
        let endHour = min(23, latestHour + 2)

        // Ensure minimum 8-hour range
        let minRange = 8
        if (endHour - startHour) < minRange {
            let midpoint = (startHour + endHour) / 2
            let halfRange = minRange / 2
            return TimeRange(
                startHour: max(0, midpoint - halfRange),
                endHour: min(23, midpoint + halfRange)
            )
        }

        return TimeRange(startHour: startHour, endHour: endHour)
    }

    // Format hour for display (e.g., "8:00 AM")
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0

        guard let date = calendar.date(from: components) else { return "\(hour):00" }
        return formatter.string(from: date)
    }

    // Format event time (e.g., "2:30 PM")
    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Photos Page
    private var photosPage: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if albumPhotos.isEmpty {
                // Empty state
                VStack(spacing: 30) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 120))
                        .foregroundColor(.secondary)
                    Text("No Photos in Album")
                        .font(.largeTitle)
                    Text("Add photos from your iPhone app")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            } else if currentPhotoIndex < albumPhotos.count {
                // Display current photo with bounds check
                let photo = albumPhotos[currentPhotoIndex]
                let _ = print("📸 Displaying photo at index: \(currentPhotoIndex) of \(albumPhotos.count)")

                VStack(spacing: 0) {
                    Spacer()

                    if let imageData = photo.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(80)
                    }

                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 120)
                            .padding(.bottom, 80)
                    }

                    Spacer()
                }
                .id("photo-\(currentPhotoIndex)")  // Force view update when photo changes
                .transition(.opacity)
            } else {
                // Index out of bounds - show loading state and reset
                VStack(spacing: 30) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 100))
                        .foregroundColor(.secondary)
                    Text("Loading photo...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    print("📸 Index out of bounds (\(currentPhotoIndex)), resetting to 0")
                    currentPhotoIndex = 0
                }
            }
        }
        // Timer is driven by currentPage, not onAppear — see pageTimers(for:)
    }

    // MARK: - Event Countdown Page
    private var eventCountdownPage: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if let event = countdownEvent {
                VStack(spacing: 0) {
                    Spacer()

                    // Event name
                    Text(formatEventNameForCountdown(event.name))
                        .font(.system(size: 96, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 120)

                    // Divider
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                        .frame(width: 300, height: 3)
                        .padding(.vertical, 50)

                    // Countdown display
                    Text(formatSmartCountdown(for: event))
                        .font(.system(size: 280, weight: .bold))
                        .foregroundColor(countdownTextColor(for: event))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 60)

                    // Countdown label
                    Text(countdownLabel(for: event))
                        .font(.system(size: 56, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                        .padding(.top, 20)

                    // Divider
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                        .frame(width: 300, height: 3)
                        .padding(.vertical, 50)

                    // Event date/time
                    Text(event.displayDate)
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))

                    Spacer()
                }
            } else {
                // No event to show - this shouldn't display if skip logic works
                VStack(spacing: 30) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 160))
                        .foregroundColor(.secondary)
                    Text("No Upcoming Events")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                }
            }
        }
        // Timer is driven by currentPage, not onAppear — see pageTimers(for:)
    }

    // MARK: - Countdown Helpers
    private func formatEventNameForCountdown(_ name: String) -> String {
        // Clean up event name - remove parts after colon for cleaner display
        if let colonIndex = name.firstIndex(of: ":") {
            return String(name[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        }
        // Remove parenthetical parts
        if let parenIndex = name.firstIndex(of: "(") {
            return String(name[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    private func formatSmartCountdown(for event: LocariusEvent) -> String {
        guard let eventDate = event.startDate else { return "--" }

        let timeRemaining = eventDate.timeIntervalSince(countdownCurrentTime)
        guard timeRemaining > 0 else { return "NOW" }

        let days = Int(timeRemaining) / 86400
        let hours = Int(timeRemaining) / 3600 % 24
        let minutes = Int(timeRemaining) / 60 % 60
        let seconds = Int(timeRemaining) % 60

        // More than 7 days: show "X DAYS"
        if days > 7 {
            return "\(days)"
        }

        // 2-7 days: show "Xd Xh"
        if days >= 2 {
            return "\(days)d \(hours)h"
        }

        // 1 day: show "1d Xh" or just hours if less than 24h
        if days == 1 {
            return "1d \(hours)h"
        }

        // Less than 24 hours: show HH:MM:SS
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func countdownLabel(for event: LocariusEvent) -> String {
        guard let eventDate = event.startDate else { return "" }

        let timeRemaining = eventDate.timeIntervalSince(countdownCurrentTime)
        guard timeRemaining > 0 else { return "" }

        let days = Int(timeRemaining) / 86400

        if days > 7 {
            return "DAYS"
        } else if days >= 1 {
            return "UNTIL EVENT"
        } else {
            return "HOURS : MINS : SECS"
        }
    }

    private func countdownTextColor(for event: LocariusEvent) -> Color {
        guard let eventDate = event.startDate else {
            return colorScheme == .dark ? .white : .black
        }

        let timeRemaining = eventDate.timeIntervalSince(countdownCurrentTime)
        let hours = timeRemaining / 3600

        // Within 1 hour - orange/urgent
        if hours < 1 {
            return .orange
        }
        // Within 24 hours - blue highlight
        if hours < 24 {
            return .blue
        }
        // Default color
        return colorScheme == .dark ? .white : .black
    }

    private func shouldShowCountdownPage() -> Bool {
        guard let event = countdownEvent else { return false }

        // Don't show if event is a night shift
        if event.isNightShift { return false }

        // Don't show if event is happening now
        if isEventCurrentlyHappening(event) { return false }

        return true
    }

    private func isEventCurrentlyHappening(_ event: LocariusEvent) -> Bool {
        guard let startDate = event.startDate else { return false }
        // Assume 4-hour duration for events
        let endDate = Calendar.current.date(byAdding: .hour, value: 4, to: startDate) ?? startDate
        let now = countdownCurrentTime
        return now >= startDate && now < endDate
    }

    // MARK: - Countdown Timer
    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            countdownCurrentTime = Date()
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // Update countdown event from fetched events
    private func updateCountdownEvent() {
        // Find next non-night-shift event
        let nonNightShiftEvents = events.filter { !$0.isNightShift }
        let upcomingEvents = nonNightShiftEvents.filter { event in
            guard let date = event.startDate else { return false }
            return date > Date()
        }.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }

        countdownEvent = upcomingEvents.first
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

    /// The pages the rotation actually visits — whatever is switched on in settings, minus
    /// Tech Week once the Locarius feed has no sessions left and Co-op Placements while the
    /// roster is empty, so those pages drop out on their own.
    private var rotationPages: [DashboardPage] {
        settings.rotation.filter { page in
            switch page {
            case .coopPlacements: return !coopStudents.isEmpty
            case .techWeek: return !techWeek.isEmpty
            default: return true
            }
        }
    }

    private func scheduleNextPageTransition() {
        // Cancel any existing timer
        stopSlidingTimer()

        let pages = rotationPages
        guard !pages.isEmpty else { return }

        let current = DashboardPage(rawValue: currentPage)
        let nextPage: DashboardPage

        if let current, let index = pages.firstIndex(of: current) {
            nextPage = pages[(index + 1) % pages.count]
        } else {
            // Opened from the sidebar onto a page that isn't in the rotation — rejoin at the top
            nextPage = pages[0]
        }

        guard nextPage != current else { return } // only one page rotating, nothing to schedule

        // A page holds for its ratio's worth of screen time; a sidebar-only page gets a
        // default minute before the rotation takes over again.
        let duration = current.map { settings.isEnabled($0) ? settings.duration($0) : 60.0 } ?? 60.0

        slidingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [self] _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                currentPage = nextPage.rawValue
            }

            // Schedule the next transition
            scheduleNextPageTransition()
        }
    }

    private func stopSlidingTimer() {
        slidingTimer?.invalidate()
        slidingTimer = nil
    }

    // MARK: - Photo Timer Logic
    private func startPhotoTimer() {
        stopPhotoTimer()

        // Only advance if we have photos
        guard !albumPhotos.isEmpty else {
            print("📸 No photos in album, timer not started")
            currentPhotoIndex = 0
            return
        }

        // Ensure index is within bounds when starting
        if currentPhotoIndex >= albumPhotos.count {
            currentPhotoIndex = 0
            print("📸 Reset index to 0 (was out of bounds)")
        }

        print("📸 Starting photo timer. Total photos: \(albumPhotos.count), Starting at index: \(currentPhotoIndex)")

        photoTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [self] _ in
            print("📸 Photo timer fired! Current index: \(currentPhotoIndex), Total photos: \(albumPhotos.count)")

            // Guard against empty album
            guard !albumPhotos.isEmpty else {
                print("📸 Album is empty, stopping timer")
                stopPhotoTimer()
                return
            }

            withAnimation(.easeInOut(duration: 1.0)) {
                // Cycle through all photos continuously using fresh count
                currentPhotoIndex = (currentPhotoIndex + 1) % albumPhotos.count
                print("📸 Advanced to photo index: \(currentPhotoIndex)")
            }
        }
    }

    private func stopPhotoTimer() {
        photoTimer?.invalidate()
        photoTimer = nil
    }

    // MARK: - Per-Page Timers
    /// Every page lives in the hierarchy permanently and is just moved off-screen, so a page's
    /// own .onAppear fires once at launch and its .onDisappear never fires at all. Left that way,
    /// the countdown's 1-second timer runs forever and mutates state on THIS view, re-evaluating
    /// all pages once a second. Driving the timers off currentPage keeps them to the visible page.
    private func pageTimers(for page: Int) {
        if page == 3 { startPhotoTimer() } else { stopPhotoTimer() }
        if page == 4 { startCountdownTimer() } else { stopCountdownTimer() }
    }

    // MARK: - Auto-hide Menu Button Timer
    private func revealMenuButton() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showMenuButton = true
        }
        startHideButtonTimer()
    }

    private func startHideButtonTimer() {
        // Cancel any existing timer
        stopHideButtonTimer()

        // Hide button after 30 seconds of inactivity
        hideButtonTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [self] _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showMenuButton = false
            }
        }
    }

    private func stopHideButtonTimer() {
        hideButtonTimer?.invalidate()
        hideButtonTimer = nil
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
                    techWeek = TechWeekSchedule(events: fetchedEvents)
                    isLoadingEvents = false
                    updateCountdownEvent()
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
