//
//  RoomStatusService.swift
//  bragboard
//
//  Service for fetching and managing room status data from The Foundry Room Hub API
//

import Foundation

// MARK: - Base44 API Models (Alternative data source)
struct Base44Room: Codable {
    let id: String
    let name: String
    let roomNumber: String
    let floor: String
    let capacity: Int
    let amenities: [String]?
    let description: String?
    let isActive: Bool
    let maxBookingDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, floor, capacity, amenities, description
        case roomNumber = "room_number"
        case isActive = "is_active"
        case maxBookingDuration = "max_booking_duration"
    }
}

struct Base44Booking: Codable {
    let id: String
    let roomId: String
    let title: String
    let description: String?
    let startTime: String
    let endTime: String
    let status: String
    let attendees: [String]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status, attendees, notes
        case roomId = "room_id"
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: startTime)
    }
    
    var endDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: endTime)
    }
    
    // Check if this booking is currently active
    func isCurrentlyActive(at currentTime: Date = Date()) -> Bool {
        guard let start = startDate, let end = endDate else {
            print("⚠️ Could not parse dates for booking: \(id)")
            return false
        }
        
        let isActive = currentTime >= start && currentTime <= end
        
        // Debug logging
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        
        print("🔍 Booking '\(title)' (ID: \(id.prefix(8))...)")
        print("   Start: \(formatter.string(from: start))")
        print("   End: \(formatter.string(from: end))")
        print("   Now: \(formatter.string(from: currentTime))")
        print("   Status: \(isActive ? "✅ ACTIVE" : "⏸️ NOT ACTIVE")")
        
        return isActive
    }
    
    // Check if this booking is in the future
    func isFuture(from currentTime: Date = Date()) -> Bool {
        guard let start = startDate else { return false }
        return start > currentTime
    }
}

// MARK: - Room Status Models
struct RoomStatusResponse: Codable {
    let timestamp: String
    let roomCount: Int
    let availableCount: Int
    let occupiedCount: Int
    let rooms: [RoomInfo]
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case roomCount = "room_count"
        case availableCount = "available_count"
        case occupiedCount = "occupied_count"
        case rooms
    }
}

struct RoomInfo: Codable, Identifiable {
    let id: String
    let name: String
    let roomNumber: String
    let floor: String
    let capacity: Int
    let status: RoomStatus
    let currentBooking: BookingInfo?
    let nextBooking: BookingInfo?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case roomNumber = "room_number"
        case floor, capacity, status
        case currentBooking = "current_booking"
        case nextBooking = "next_booking"
    }
}

enum RoomStatus: String, Codable {
    case available = "available"
    case occupied = "occupied"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .occupied: return "Occupied"
        case .maintenance: return "Maintenance"
        }
    }
    
    var colorName: String {
        switch self {
        case .available: return "green"
        case .occupied: return "red"
        case .maintenance: return "orange"
        }
    }
}

struct BookingInfo: Codable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    var startDate: Date? {
        ISO8601DateFormatter().date(from: startTime)
    }
    
    var endDate: Date? {
        ISO8601DateFormatter().date(from: endTime)
    }
}

// MARK: - Display Options (for user configuration)
struct RoomDisplayOptions: Codable {
    var showRoomNumber: Bool = false
    var showFloor: Bool = false
    var showCapacity: Bool = false
    var showCurrentBooking: Bool = false
    var showNextBooking: Bool = false
    
    // Determine if widget needs 2x size
    var needsExpandedSize: Bool {
        showRoomNumber || showFloor || showCapacity || showCurrentBooking || showNextBooking
    }
}

// MARK: - Room Status Service
class RoomStatusService {
    static let shared = RoomStatusService()
    
    // Base44 API endpoints
    private let base44RoomsEndpoint = "https://base44.app/api/apps/689cceadf2c7408b283ab894/entities/Room?q=%7B%22is_active%22:true%7D"
    private let base44BookingsEndpoint = "https://base44.app/api/apps/689cceadf2c7408b283ab894/entities/Booking?q=%7B%22status%22:%22confirmed%22%7D"
    
    private init() {}
    
    /// Fetch current room status from the Base44 API
    func fetchRoomStatus() async throws -> RoomStatusResponse {
        print("🔗 Attempting Base44 API (rooms + bookings)...")
        return try await fetchBase44RoomStatus()
    }
    
    /// Fetch and combine room + booking data from Base44 API
    private func fetchBase44RoomStatus() async throws -> RoomStatusResponse {
        // Fetch rooms and bookings concurrently
        async let roomsData = fetchBase44Rooms()
        async let bookingsData = fetchBase44Bookings()
        
        let (rooms, bookings) = try await (roomsData, bookingsData)

        // Only show floor 2 rooms (202-A through 202-D)
        let filteredRooms = rooms.filter { $0.roomNumber.hasPrefix("202") }

        print("✅ Fetched \(filteredRooms.count) rooms (of \(rooms.count)) and \(bookings.count) bookings from Base44")

        // Filter bookings to only current and future ones
        let relevantBookings = filterRelevantBookings(bookings)
        print("📅 Filtered to \(relevantBookings.count) current/future bookings")
        
        // Combine rooms with booking data
        return combineRoomsWithBookings(rooms: filteredRooms, bookings: relevantBookings)
    }
    
    /// Fetch rooms from Base44
    private func fetchBase44Rooms() async throws -> [Base44Room] {
        guard let url = URL(string: base44RoomsEndpoint) else {
            throw RoomStatusError.invalidURL
        }

        let token = AppConfig.shared.base44APIToken
        guard !token.isEmpty else {
            throw RoomStatusError.allEndpointsFailed
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("689cceadf2c7408b283ab894", forHTTPHeaderField: "x-app-id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15

        let session = URLSession.shared
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw RoomStatusError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Base44Room].self, from: data)
    }
    
    /// Fetch bookings from Base44
    private func fetchBase44Bookings() async throws -> [Base44Booking] {
        guard let url = URL(string: base44BookingsEndpoint) else {
            throw RoomStatusError.invalidURL
        }

        let token = AppConfig.shared.base44APIToken
        guard !token.isEmpty else {
            throw RoomStatusError.allEndpointsFailed
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("689cceadf2c7408b283ab894", forHTTPHeaderField: "x-app-id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15

        let session = URLSession.shared
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw RoomStatusError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Base44Booking].self, from: data)
    }
    
    /// Filter bookings to only keep current and near-future ones
    private func filterRelevantBookings(_ bookings: [Base44Booking]) -> [Base44Booking] {
        let now = Date()
        let twentyFourHoursLater = now.addingTimeInterval(24 * 60 * 60)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        
        //print("\n🔍 Filtering Bookings:")
        //print("   Current time: \(timeFormatter.string(from: now))")
        //print("   24h cutoff: \(timeFormatter.string(from: twentyFourHoursLater))")
        //print("   Total bookings to filter: \(bookings.count)\n")
        
        let filtered = bookings.filter { booking in
            guard let startDate = booking.startDate, let endDate = booking.endDate else {
                //print("   ❌ Skipped (invalid dates): \(booking.title)")
                return false
            }

            // Keep if:
            // 1. End time is in the future (includes currently active bookings)
            // 2. Starts within the next 24 hours
            let endInFuture = endDate > now
            let startsWithin24h = startDate < twentyFourHoursLater
            let shouldKeep = endInFuture && startsWithin24h

            //let status = shouldKeep ? "✅ KEEP" : "❌ DROP"
            //print("   \(status): '\(booking.title)'")
            //print("      Start: \(timeFormatter.string(from: startDate))")
            //print("      End: \(timeFormatter.string(from: endDate))")

            //if !endInFuture {
            //    print("      Reason: Already ended")
            //} else if !startsWithin24h {
            //    print("      Reason: Starts more than 24h in future")
            //}
            //print("")

            return shouldKeep
        }

        //print("📊 Filtering result: Kept \(filtered.count) of \(bookings.count) bookings\n")
        return filtered
    }
    
    /// Combine room data with booking data to create RoomStatusResponse
    private func combineRoomsWithBookings(rooms: [Base44Room], bookings: [Base44Booking]) -> RoomStatusResponse {
        let now = Date()
        
        // Log current time in local timezone
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .long
        timeFormatter.timeZone = TimeZone.current
        
        //print("\n⏰ Current Time Analysis:")
        //print("   Local Time: \(timeFormatter.string(from: now))")
        //print("   Timezone: \(TimeZone.current.identifier) (UTC\(TimeZone.current.secondsFromGMT() / 3600))")
        //print("   Processing \(bookings.count) bookings for \(rooms.count) rooms\n")
        
        var availableCount = 0
        var occupiedCount = 0
        
        let roomInfos = rooms.map { room -> RoomInfo in
            //print("🏢 Processing room: \(room.name) (ID: \(room.id))")

            // Find bookings for this room
            let roomBookings = bookings.filter { $0.roomId == room.id }
            //print("   Found \(roomBookings.count) booking(s) for this room")

            // Find current booking (if any)
            let currentBooking = roomBookings.first { booking in
                guard let start = booking.startDate, let end = booking.endDate else {
                    //print("   ⚠️ Skipping booking with invalid dates: \(booking.id)")
                    return false
                }
                let isActive = now >= start && now <= end

                //if isActive {
                //    print("   ✅ CURRENT BOOKING FOUND: '\(booking.title)'")
                //    print("      Ends at: \(timeFormatter.string(from: end))")
                //}

                return isActive
            }

            // Find next booking (earliest future booking)
            let futureBookings = roomBookings.filter { booking in
                guard let start = booking.startDate else { return false }
                return start > now
            }.sorted { booking1, booking2 in
                guard let start1 = booking1.startDate, let start2 = booking2.startDate else { return false }
                return start1 < start2
            }
            let nextBooking = futureBookings.first

            //if let next = nextBooking, let nextStart = next.startDate {
            //    print("   📅 Next booking: '\(next.title)' at \(timeFormatter.string(from: nextStart))")
            //} else {
            //    print("   📅 No upcoming bookings")
            //}

            // Determine status
            let status: RoomStatus = currentBooking != nil ? .occupied : .available

            if status == .available {
                availableCount += 1
                //print("   🟢 Status: AVAILABLE\n")
            } else {
                occupiedCount += 1
                //print("   🔴 Status: OCCUPIED\n")
            }
            
            // Convert Base44 bookings to RoomInfo format
            let currentBookingInfo = currentBooking.map { booking in
                BookingInfo(
                    id: booking.id,
                    title: booking.title,
                    startTime: booking.startTime,
                    endTime: booking.endTime
                )
            }
            
            let nextBookingInfo = nextBooking.map { booking in
                BookingInfo(
                    id: booking.id,
                    title: booking.title,
                    startTime: booking.startTime,
                    endTime: booking.endTime
                )
            }
            
            return RoomInfo(
                id: room.id,
                name: room.name,
                roomNumber: room.roomNumber,
                floor: room.floor,
                capacity: room.capacity,
                status: status,
                currentBooking: currentBookingInfo,
                nextBooking: nextBookingInfo
            )
        }
        
        //print("📊 Final Summary:")
        //print("   Total Rooms: \(roomInfos.count)")
        //print("   Available: \(availableCount)")
        //print("   Occupied: \(occupiedCount)\n")
        
        return RoomStatusResponse(
            timestamp: ISO8601DateFormatter().string(from: now),
            roomCount: roomInfos.count,
            availableCount: availableCount,
            occupiedCount: occupiedCount,
            rooms: roomInfos
        )
    }
    
    /// Get formatted timestamp from ISO string
    static func formatTimestamp(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "Unknown"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, h:mm a"
        return displayFormatter.string(from: date)
    }
    
    /// Get relative time (e.g., "1:00 p.m. AST" or "1:00 p.m. ADT" during DST)
    static func relativeTime(from isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: isoString) else {
            return "Unknown"
        }

        let halifax = TimeZone(identifier: "America/Halifax") ?? .current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        timeFormatter.timeZone = halifax
        let timeString = timeFormatter.string(from: date)
        let abbreviation = halifax.abbreviation(for: date) ?? "AST"
        return "\(timeString) \(abbreviation)"
    }
    
    /// Get time remaining until end of booking
    static func timeRemaining(until endTime: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let endDate = formatter.date(from: endTime) else {
            return nil
        }
        
        let now = Date()
        let interval = endDate.timeIntervalSince(now)
        
        if interval < 0 {
            return nil
        }
        
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Errors
enum RoomStatusError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case allEndpointsFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .httpError(let code):
            if code == 401 || code == 403 {
                return "Room status API requires authentication (HTTP \(code))"
            }
            return "HTTP error: \(code)"
        case .allEndpointsFailed:
            return "Room status data is currently unavailable"
        }
    }
}
