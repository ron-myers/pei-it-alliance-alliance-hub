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
        VStack(spacing: 16) {
            Spacer()
            
            // Counter value
            Text(MockDataService.formatNumber(
                widget.configuration?.counterValue ?? 0,
                style: .full
            ))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            // Custom label
            Text(label)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Decorative icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue.opacity(0.6))
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
        .background(Color.black.opacity(0.3))
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
            let components = calendar.dateComponents([.month, .day], from: startDate, to: Date())
            let months = components.month ?? 0
            let days = components.day ?? 0
            let monthText = months == 1 ? "Month" : "Months"
            let dayText = days == 1 ? "Day" : "Days"
            return "\(max(0, months)) \(monthText) \(max(0, days)) \(dayText)"
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
            return "" // Already included in timeValue
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Calendar icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            // Time count
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
            
            Text(widget.configuration?.timeDisplayFormat.unitLabel ?? "In Business")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Decorative icon
            Image(systemName: "star.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow.opacity(0.6))
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
        }
        .onDisappear {
            stopRoomCycleTimer()
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
                Text("Updated \(RoomStatusService.relativeTime(from: data.timestamp))")
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
        VStack(spacing: 14) {
            // Compact header
            HStack {
                Image(systemName: "door.left.hand.open")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Room Status")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                // Summary
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("\(data.availableCount)")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                        Text("\(data.occupiedCount)")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.bottom, 2)
            
            // All rooms with professional layout
            VStack(spacing: 10) {
                ForEach(data.rooms) { room in
                    professionalRoomCard(room: room)
                }
            }
            
            Spacer(minLength: 0)
            
            // Compact footer
            Text("Updated \(RoomStatusService.relativeTime(from: data.timestamp))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
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
        VStack(spacing: 0) {
            // Top: Room name & status
            HStack(spacing: 8) {
                // Status dot
                Circle()
                    .fill(statusColor(for: room.status))
                    .frame(width: 8, height: 8)
                
                // Room number & name
                VStack(alignment: .leading, spacing: 1) {
                    Text(room.roomNumber)
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.6))
                    Text(room.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status badge
                Text(room.status.displayName)
                    .font(.caption2.bold())
                    .foregroundColor(statusColor(for: room.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(for: room.status).opacity(0.15))
                    .cornerRadius(6)
            }
            
            // Bottom: Current booking (always show if exists)
            if let booking = room.currentBooking {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 6)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text(booking.title)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let timeRemaining = RoomStatusService.timeRemaining(until: booking.endTime) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text(timeRemaining)
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                        }
                    }
                }
            } else {
                // Show "Available now" for empty rooms
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 6)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text("Available now")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.9))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
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
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Error Loading Data")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
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
