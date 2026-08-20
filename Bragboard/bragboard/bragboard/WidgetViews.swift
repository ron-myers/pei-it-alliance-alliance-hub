//
//  WidgetViews.swift
//  bragboard
//
//  Reusable view components for each widget type
//  ✨ UPDATED: Room Status widget now supports both 1x and 2x modes
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Widget View Protocol
protocol WidgetViewProtocol: View {
    var widget: Widget { get }
}

// MARK: - Company Logo Widget
struct LogoWidgetView: View {
    let widget: Widget
    
    var body: some View {
        VStack {
            Spacer()
            if let imageData = widget.configuration?.imageData {
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                }
                #elseif os(tvOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                }
                #endif
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "building.2")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
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
struct CustomerCounterWidgetView: View {
    let widget: Widget

    private var label: String {
        let configLabel = widget.configuration?.counterLabel ?? ""
        return configLabel.isEmpty ? "Customers Served" : configLabel
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(maxHeight: 20)

            // Counter value (extra large size)
            Text(MockDataService.formatNumber(
                widget.configuration?.counterValue ?? 0,
                style: .full
            ))
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            // Custom label (same size)
            Text(label)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(maxHeight: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Instagram Followers Widget (Manual Input)
struct InstagramFollowersWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme

    private var followerCount: Int {
        widget.configuration?.instagramFollowerCount ?? 0
    }

    private var username: String {
        let name = widget.configuration?.instagramUsername ?? ""
        return name.isEmpty ? "Instagram" : "@\(name)"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Instagram icon
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

            // Follower count
            Text(MockDataService.formatNumber(followerCount))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            // Label with username
            VStack(spacing: 4) {
                Text("Followers")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)

                Text(username)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            // Use gradient background in dark mode, solid background in light mode
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.black.opacity(0.3)
            }
        }
    }
}

// MARK: - Location Map Widget (Mock Data)
struct LocationMapWidgetView: View {
    let widget: Widget
    @State private var locations: [String] = []
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Map icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            // Location count
            Text("\(locations.count)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text("Locations Worldwide")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Mock data badge
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
                colors: [Color.green.opacity(0.3), Color.teal.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onAppear {
            // Load mock data
            locations = MockDataService.shared.getLocationNames()
        }
    }
}

// MARK: - Years in Business Widget
struct YearsInBusinessWidgetView: View {
    let widget: Widget
    
    // ✨ Calculate time based on selected display format
    private var timeValue: String {
        guard let startDate = widget.configuration?.startDate else { return "0" }
        let calendar = Calendar.current
        let format = widget.configuration?.timeDisplayFormat ?? .years

        switch format {
        case .years:
            let years = calendar.dateComponents([.year], from: startDate, to: Date()).year ?? 0
            return "\(max(0, years))"

        case .months:
            let months = calendar.dateComponents([.month], from: startDate, to: Date()).month ?? 0
            return "\(max(0, months))"

        case .days:
            let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            return "\(max(0, days))"

        case .monthsAndDays:
            return "" // Handled separately in the view
        }
    }

    private var timeUnit: String {
        let format = widget.configuration?.timeDisplayFormat ?? .years

        guard let startDate = widget.configuration?.startDate else {
            return format == .years ? "Years" : format == .months ? "Months" : format == .days ? "Days" : ""
        }

        let calendar = Calendar.current

        switch format {
        case .years:
            let years = calendar.dateComponents([.year], from: startDate, to: Date()).year ?? 0
            return years == 1 ? "Year" : "Years"

        case .months:
            let months = calendar.dateComponents([.month], from: startDate, to: Date()).month ?? 0
            return months == 1 ? "Month" : "Months"

        case .days:
            let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            return days == 1 ? "Day" : "Days"

        case .monthsAndDays:
            return "" // Handled separately in the view
        }
    }

    private var monthsValue: Int {
        guard let startDate = widget.configuration?.startDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: startDate, to: Date())
        return max(0, components.month ?? 0)
    }

    private var daysValue: Int {
        guard let startDate = widget.configuration?.startDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: startDate, to: Date())
        return max(0, components.day ?? 0)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Time count - different layout for monthsAndDays
            if widget.configuration?.timeDisplayFormat == .monthsAndDays {
                HStack(spacing: 40) {
                    VStack(spacing: 20) {
                        Text("\(monthsValue)")
                            .font(.system(size: 140, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text(monthsValue == 1 ? "Month" : "Months")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text("|")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundColor(.white.opacity(0.3))

                    VStack(spacing: 20) {
                        Text("\(daysValue)")
                            .font(.system(size: 140, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text(daysValue == 1 ? "Day" : "Days")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(timeValue)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if !timeUnit.isEmpty {
                        Text(timeUnit)
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            Spacer()
                .frame(height: 30)

            Text(widget.configuration?.timeDisplayFormat.unitLabel ?? "In Business")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.indigo.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Days Since Incident Widget
struct DaysSinceIncidentWidgetView: View {
    let widget: Widget
    
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
            
            // Safety badge
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            // Days count
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(daysSinceIncident)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text(daysSinceIncident == 1 ? "Day" : "Days")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("Since \(incidentLabel)")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Decorative icon
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 32))
                .foregroundColor(.green.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.green.opacity(0.3), Color.teal.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Hiring Badge Widget
struct HiringBadgeWidgetView: View {
    let widget: Widget
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Animated badge
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("JOIN US")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }
            
            // Main text
            Text("We're Hiring!")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Spacer()
            
            // Call to action badge
            HStack(spacing: 8) {
                Text("Join Our Team")
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
                colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - ✨ UPDATED: Room Status Widget with 1x and 2x modes
struct RoomStatusWidgetView: View {
    let widget: Widget
    @State private var roomData: RoomStatusResponse?
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdate = Date()
    @State private var selectedRoomIndex = 0
    @State private var roomCycleTimer: Timer?
    @State private var refreshTimer: Timer?
    
    var body: some View {
        Group {
            if isLoading && roomData == nil {
                loadingView
            } else if let error = error {
                errorView(error: error)
            } else if let data = roomData {
                // ✨ Use widget.is2x to determine view mode
                if widget.is2x {
                    expanded2xRoomStatusView(data: data)
                } else {
                    compact1xRoomStatusView(data: data)
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await fetchRoomStatus()
        }
        .onAppear {
            if !widget.is2x {
                startRoomCycleTimer()
            }
            startRefreshTimer()
        }
        .onDisappear {
            stopRoomCycleTimer()
            stopRefreshTimer()
        }
    }
    
    // MARK: - ✅ WORKING 1x Design (Cycling individual rooms)
    private func compact1xRoomStatusView(data: RoomStatusResponse) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Show one room at a time with cycling
            if !data.rooms.isEmpty {
                let currentRoom = data.rooms[selectedRoomIndex % data.rooms.count]
                
                // Room name and status
                VStack(spacing: 12) {
                    // Room number (e.g., 202A)
                    Text(currentRoom.roomNumber)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Room name
                    Text(currentRoom.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Status badge
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor(for: currentRoom.status))
                            .frame(width: 12, height: 12)
                        
                        Text(currentRoom.status.displayName)
                            .font(.title2.bold())
                            .foregroundColor(statusColor(for: currentRoom.status))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(statusColor(for: currentRoom.status).opacity(0.2))
                    .cornerRadius(20)
                    
                    // Current booking (if exists)
                    if let booking = currentRoom.currentBooking {
                        VStack(spacing: 4) {
                            Text(booking.title)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                            
                            if let timeRemaining = RoomStatusService.timeRemaining(until: booking.endTime) {
                                Text("Ends in \(timeRemaining)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            Spacer()
            
            // Footer with pagination dots
            HStack {
                Text("Updated: \(RoomStatusService.relativeTime(from: data.timestamp))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                // Room pagination dots
                if data.rooms.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<data.rooms.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedRoomIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - ✨ IMPROVED 2x Design (Professional with Current Bookings)
    private func expanded2xRoomStatusView(data: RoomStatusResponse) -> some View {
        VStack(spacing: 0) {
            // Compact header
            HStack {
                Image(systemName: "door.left.hand.open")
                    .font(.title3)
                    .foregroundColor(.blue)

                Text("Room Status")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.bottom, 18)

            // Divider line after header
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.bottom, 22)

            // All rooms with professional layout
            VStack(spacing: 16) {
                ForEach(data.rooms) { room in
                    professionalRoomCard(room: room)
                }
            }

            Spacer(minLength: 0)

            // Compact footer
            Text("Updated: \(RoomStatusService.relativeTime(from: data.timestamp))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 12)
        }
        .padding(18)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - ✨ Professional Room Card (for 2x view)
    private func professionalRoomCard(room: RoomInfo) -> some View {
        HStack(spacing: 10) {
            // Room name & number (switched order)
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(room.roomNumber)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Status badge
            Text(room.status.displayName)
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(statusColor(for: room.status).opacity(room.status == .available ? 0.3 : 0.4))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            
            Text("Loading Rooms...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("Room Status")
                .font(.headline)
                .foregroundColor(.white)

            Text("Data temporarily unavailable")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Room Status")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Configure to load room data")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Helpers
    private func statusColor(for status: RoomStatus) -> Color {
        switch status {
        case .available: return .green
        case .occupied: return .red
        case .maintenance: return .orange
        }
    }
    
    private func fetchRoomStatus() async {
        isLoading = true
        error = nil
        
        do {
            let data = try await RoomStatusService.shared.fetchRoomStatus()
            await MainActor.run {
                self.roomData = data
                self.lastUpdate = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func startRoomCycleTimer() {
        guard !widget.is2x else { return }
        roomCycleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            guard let rooms = roomData?.rooms, rooms.count > 1 else { return }
            withAnimation {
                selectedRoomIndex = (selectedRoomIndex + 1) % rooms.count
            }
        }
    }
    
    private func stopRoomCycleTimer() {
        roomCycleTimer?.invalidate()
        roomCycleTimer = nil
    }

    private func startRefreshTimer() {
        // Refresh room status every 60 seconds (1 minute)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task {
                await fetchRoomStatus()
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Upcoming Events Widget
struct UpcomingEventsWidgetView: View {
    let widget: Widget

    @State private var nextEvent: LocariusEvent?
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdate: Date?
    @State private var refreshTimer: Timer?
    @State private var countdownTimer: Timer?
    @State private var currentTime = Date()
    
    var body: some View {
        Group {
            if isLoading && nextEvent == nil {
                loadingView
            } else if let error = error {
                errorView(error: error)
            } else if let event = nextEvent {
                eventView(event: event)
            } else {
                placeholderView
            }
        }
        .onAppear {
            Task {
                await fetchNextEvent()
            }
            startRefreshTimer()
            startCountdownTimer()
        }
        .onDisappear {
            stopRefreshTimer()
            stopCountdownTimer()
        }
    }

    // MARK: - Countdown Helpers
    private func isEventToday(_ event: LocariusEvent) -> Bool {
        guard let eventDate = event.startDate else { return false }
        let calendar = Calendar.current
        return calendar.isDateInToday(eventDate)
    }

    private func eventEndDate(_ event: LocariusEvent) -> Date? {
        guard let startDate = event.startDate else { return nil }
        // Assume 4-hour duration
        return calendar.date(byAdding: .hour, value: 4, to: startDate)
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private func isEventHappeningNow(_ event: LocariusEvent) -> Bool {
        guard let startDate = event.startDate,
              let endDate = eventEndDate(event) else { return false }
        let now = currentTime
        return now >= startDate && now < endDate
    }

    private func timeUntilEvent(_ event: LocariusEvent) -> TimeInterval? {
        guard let startDate = event.startDate else { return nil }
        return startDate.timeIntervalSince(currentTime)
    }

    private func shouldShowCountdown(_ event: LocariusEvent) -> Bool {
        isEventToday(event) && !isEventHappeningNow(event)
    }

    private func formatCountdown(_ event: LocariusEvent) -> String {
        guard let timeRemaining = timeUntilEvent(event), timeRemaining > 0 else {
            return ""
        }

        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) / 60 % 60
        let seconds = Int(timeRemaining) % 60

        // If more than 1 hour away, show "X hr Y min"
        if timeRemaining > 3600 {
            if minutes > 0 {
                return "\(hours) hr \(minutes) min"
            } else {
                return "\(hours) hr"
            }
        } else {
            // Within 1 hour, show "MM:SS"
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Event Display
    private func eventView(event: LocariusEvent) -> some View {
        VStack(spacing: 16) {
            Spacer()

            // Calendar icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 80, height: 80)

                Image(systemName: isEventHappeningNow(event) ? "calendar.badge.exclamationmark" : "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundColor(isEventHappeningNow(event) ? .green : .blue)
            }

            // Event name (with line breaks at : and ( )
            Text(formatEventName(event.name))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 20)

            // Countdown or Date display
            if isEventHappeningNow(event) {
                // Show "Happening now" when event is in progress
                Text("Happening now")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            } else if shouldShowCountdown(event) {
                // Show countdown when event is today
                Text(formatCountdown(event))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .padding(.horizontal, 20)
            } else {
                // Show normal date and time for future events
                Text(event.displayDate)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Last update time
            if let lastUpdate = lastUpdate {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                    Text("Updated: \(timeAgo(from: lastUpdate))")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Helper Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            
            Text("Loading Events...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Error Loading Events")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal)
            
            Button {
                Task {
                    await fetchNextEvent()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Upcoming Events")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Configure API token to load events")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Data Fetching
    private func fetchNextEvent() async {
        print("🎯 UpcomingEventsWidget: Starting fetchNextEvent()")
        
        isLoading = true
        error = nil
        
        do {
            print("🔑 UpcomingEventsWidget: Getting token from AppConfig...")
            let token = AppConfig.shared.locariusAPIToken
            print("✅ UpcomingEventsWidget: Token received (length: \(token.count))")
            
            print("📡 UpcomingEventsWidget: Calling LocariusEventService.fetchUpcomingEvents...")
            let events = try await LocariusEventService.shared.fetchUpcomingEvents(token: token)
            print("✅ UpcomingEventsWidget: Received \(events.count) events")
            
            print("🔍 UpcomingEventsWidget: Finding next event...")
            let next = LocariusEventService.shared.getNextEvent(from: events)
            
            if let next = next {
                print("✅ UpcomingEventsWidget: Found next event: \(next.name)")
            } else {
                print("⚠️ UpcomingEventsWidget: No next event found")
            }
            
            await MainActor.run {
                print("🎨 UpcomingEventsWidget: Updating UI on MainActor")
                self.nextEvent = next
                self.lastUpdate = Date()
                self.isLoading = false
                print("✅ UpcomingEventsWidget: UI updated successfully")
            }
        } catch {
            print("❌ UpcomingEventsWidget: Error occurred: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
                print("❌ UpcomingEventsWidget: Error state set in UI")
            }
        }
        
        print("🏁 UpcomingEventsWidget: fetchNextEvent() completed")
    }
    
    // MARK: - Auto-refresh
    private func startRefreshTimer() {
        // Refresh every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
            Task {
                await fetchNextEvent()
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Countdown Timer
    private func startCountdownTimer() {
        // Update every second for countdown
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    // MARK: - Helpers
    private func timeAgo(from date: Date) -> String {
        let halifax = TimeZone(identifier: "America/Halifax") ?? .current
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = halifax
        let timeString = formatter.string(from: date)
        let abbreviation = halifax.abbreviation(for: date) ?? "AST"
        return "\(timeString) \(abbreviation)"
    }
    
    private func formatEventName(_ name: String) -> String {
        // Replace : with newline for better formatting
        var formatted = name.replacingOccurrences(of: ": ", with: "\n")
        
        // Replace opening parenthesis with newline
        formatted = formatted.replacingOccurrences(of: " (", with: "\n(")
        
        return formatted
    }
}

// MARK: - Countries Served Widget
struct CountriesServedWidgetView: View {
    let widget: Widget
    @Environment(\.colorScheme) private var colorScheme

    private var selectedCountries: [Country] {
        let countryService = CountryDataService.shared
        let countryIds = widget.configuration?.countriesServed ?? ["CA"]
        return countryIds.compactMap { countryService.getCountry(byId: $0) }
    }

    private var countryCount: Int {
        selectedCountries.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header section
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.title2)
                        .foregroundColor(.blue)

                    Text("\(countryCount) \(countryCount == 1 ? "Country" : "Countries") Served")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 16)

                // Default location indicator
                if selectedCountries.contains(where: { $0.id == "CA" }) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("Charlottetown, PEI")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            // World map visualization with fade edges
            GeometryReader { geometry in
                ZStack {
                    // World map background (flat representation)
                    Rectangle()
                        .fill(Color.white.opacity(0.05))

                    // Country markers on flat map
                    ForEach(selectedCountries) { country in
                        let position = projectToFlatMap(
                            lat: country.latitude,
                            lon: country.longitude,
                            width: geometry.size.width,
                            height: geometry.size.height
                        )

                        // Marker with country name
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(country.id == "CA" ? Color.red : Color.blue)
                                    .frame(width: country.id == "CA" ? 16 : 12, height: country.id == "CA" ? 16 : 12)

                                if country.id == "CA" {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 6))
                                }
                            }

                            #if os(tvOS)
                            // Show country names on TV
                            Text(country.name)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.6))
                                )
                            #endif
                        }
                        .position(position)
                    }
                }
                .mask(
                    // Radial gradient mask for fade-out edges
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white, location: 0.4),
                            .init(color: .white, location: 0.7),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.7
                    )
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.teal.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // Project lat/lon to flat map coordinates (Equirectangular projection)
    // Adjusted for proper world positioning: NA left, Asia middle, Australia bottom-right
    private func projectToFlatMap(lat: Double, lon: Double, width: CGFloat, height: CGFloat) -> CGPoint {
        // Convert longitude (-180 to 180) to x position (0 to width)
        let x = (lon + 180) * Double(width) / 360

        // Convert latitude (90 to -90) to y position (0 to height)
        // Inverted so north is up
        let y = (90 - lat) * Double(height) / 180

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Placeholder Widget (for unimplemented types)
struct PlaceholderWidgetView: View {
    let widget: Widget
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: widget.type.icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(widget.type.displayName)
                .font(.title3)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - Widget Factory
/// Returns the appropriate view for each widget type
@ViewBuilder
func createWidgetView(for widget: Widget) -> some View {
    switch widget.type {
    case .companyLogo:
        LogoWidgetView(widget: widget)
        
    case .customerCount:
        CustomerCounterWidgetView(widget: widget)
        
    case .instagramFollowers:
        InstagramFollowersWidgetView(widget: widget)
        
    case .locationsMap:
        LocationMapWidgetView(widget: widget)
        
    case .yearsInBusiness:
        YearsInBusinessWidgetView(widget: widget)
        
    case .daysSinceIncident:
        DaysSinceIncidentWidgetView(widget: widget)
        
    case .hiringBadge:
        HiringBadgeWidgetView(widget: widget)
    
    case .roomStatus:
        RoomStatusWidgetView(widget: widget)
    
    case .upcomingEvents:
        UpcomingEventsWidgetView(widget: widget)

    case .countriesServed:
        CountriesServedWidgetView(widget: widget)

    // TODO: Implement remaining widgets
    default:
        PlaceholderWidgetView(widget: widget)
    }
}

// MARK: - Widget Container (Common styling)
struct WidgetContainer<Content: View>: View {
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
