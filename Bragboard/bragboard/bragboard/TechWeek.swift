//
//  TechWeek.swift
//  bragboard
//
//  Tech Week schedule model, branding and QR generation.
//  Everything here is derived from the Locarius API — no hardcoded dates.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tech Week Branding
/// Colours taken from the PEI IT Alliance event posters
enum TechWeekTheme {
    static let coral = Color(red: 0.95, green: 0.35, blue: 0.24)
    static let salmon = Color(red: 0.93, green: 0.47, blue: 0.38)
    static let cream = Color(red: 0.97, green: 0.85, blue: 0.47)

    static var gradient: LinearGradient {
        LinearGradient(colors: [coral, salmon], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Per-Poster Palette
/// Background colours pulled out of the poster itself, so each slide takes on its own artwork
struct TechWeekPalette: Equatable {
    let top: Color
    let bottom: Color
    let accent: Color

    /// Used before a poster has loaded, and for sessions with no artwork
    static let brand = TechWeekPalette(
        top: TechWeekTheme.coral,
        bottom: TechWeekTheme.salmon,
        accent: TechWeekTheme.cream
    )

    var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Finds the poster's DOMINANT colour, not its average.
    ///
    /// Averaging cancels opposing hues — a vivid pink-and-green poster averages to mud. Instead this
    /// downsamples to 24×24, drops greys and blown-out pixels, and buckets what's left into a hue
    /// histogram weighted by how vivid each pixel is. The winning hue is the colour the poster actually
    /// reads as. Brightness is then pinned to a fixed band so white body text stays legible on top.
    init(poster: UIImage) {
        guard let cgImage = poster.cgImage else { self = .brand; return }

        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)

        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { self = .brand; return }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        let bucketCount = 24
        var weights = [Double](repeating: 0, count: bucketCount)
        var hueSums = [Double](repeating: 0, count: bucketCount)
        var saturationSums = [Double](repeating: 0, count: bucketCount)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let color = UIColor(
                red: CGFloat(pixels[index]) / 255.0,
                green: CGFloat(pixels[index + 1]) / 255.0,
                blue: CGFloat(pixels[index + 2]) / 255.0,
                alpha: 1
            )

            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { continue }

            // Ignore greys, near-black and blown-out whites — they carry no hue information
            guard saturation > 0.18, brightness > 0.12, brightness < 0.97 else { continue }

            let bucket = min(bucketCount - 1, Int(hue * CGFloat(bucketCount)))
            let weight = Double(saturation) * Double(brightness)

            weights[bucket] += weight
            hueSums[bucket] += Double(hue) * weight
            saturationSums[bucket] += Double(saturation) * weight
        }

        guard let winner = weights.indices.max(by: { weights[$0] < weights[$1] }),
              weights[winner] > 0 else { self = .brand; return }

        let hue = CGFloat(hueSums[winner] / weights[winner])
        let richness = min(1.0, max(0.45, CGFloat(saturationSums[winner] / weights[winner]) * 1.15))

        self.init(
            top: Color(UIColor(hue: hue, saturation: richness, brightness: 0.64, alpha: 1)),
            bottom: Color(UIColor(hue: hue, saturation: richness, brightness: 0.36, alpha: 1)),
            accent: Color(UIColor(hue: hue, saturation: min(0.26, richness), brightness: 0.97, alpha: 1))
        )
    }

    private init(top: Color, bottom: Color, accent: Color) {
        self.top = top
        self.bottom = bottom
        self.accent = accent
    }
}

// MARK: - Poster Cache
struct TechWeekPoster {
    let image: UIImage
    let palette: TechWeekPalette
}

/// Downloads each poster once and keeps it, with its derived palette, in memory.
/// Replaces AsyncImage so slides never re-fetch or re-analyse on a redraw.
@MainActor
final class TechWeekPosterCache {
    static let shared = TechWeekPosterCache()

    private var cache: [String: TechWeekPoster] = [:]

    private init() {}

    func cached(_ urlString: String) -> TechWeekPoster? { cache[urlString] }

    func poster(for urlString: String?) async -> TechWeekPoster? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        if let hit = cache[urlString] { return hit }

        guard let poster = await Self.download(url) else { return nil }

        cache[urlString] = poster
        return poster
    }

    /// Deliberately nonisolated: download, decode and colour analysis all happen off the main thread.
    /// UIImage decodes lazily on first draw, which would otherwise stutter the slide transition.
    nonisolated private static func download(_ url: URL) async -> TechWeekPoster? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }

        let decoded = image.preparingForDisplay() ?? image
        return TechWeekPoster(image: decoded, palette: TechWeekPalette(poster: decoded))
    }
}

// MARK: - Tech Week Event Helpers
extension LocariusEvent {
    /// True when the organiser explicitly branded this event as Tech Week
    var hasTechWeekPrefix: Bool {
        name.lowercased().contains("tech week")
    }

    /// Event name with the "PEI Tech Week - " / "Tech Week: " prefix removed
    var techWeekTitle: String {
        let prefixes = ["pei tech week - ", "pei tech week: ", "tech week - ", "tech week: "]
        let lowered = name.lowercased()
        for prefix in prefixes where lowered.hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }

    /// The API has no end time, so assume the same 4-hour duration used elsewhere in the app
    var endDateEstimate: Date? {
        guard let startDate else { return nil }
        return Calendar.current.date(byAdding: .hour, value: 4, to: startDate)
    }

    func isHappeningNow(at now: Date) -> Bool {
        guard let startDate, let endDate = endDateEstimate else { return false }
        return now >= startDate && now < endDate
    }

    /// "Free · 60 spots"
    var capacityLine: String {
        let spots = "\(capacity) spots"
        return is_free ? "Free · \(spots)" : spots
    }

    var timeOfDay: String {
        guard let startDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }
}

// MARK: - Tech Week Schedule
/// Groups the Locarius feed into the Tech Week programme.
///
/// A session counts as Tech Week when it is either branded "Tech Week" itself, or falls on a day
/// that already contains a branded session. The second rule picks up the recurring sessions that run
/// during the week without the prefix (AI Together), and it means the whole feature switches itself
/// off once the week has passed without any code change.
struct TechWeekSchedule {
    let sessions: [LocariusEvent]
    let days: [Date]

    init(events: [LocariusEvent]) {
        let calendar = Calendar.current

        let brandedDays = Set(
            events
                .filter { $0.hasTechWeekPrefix }
                .compactMap { $0.startDate }
                .map { calendar.startOfDay(for: $0) }
        )

        let matching: [LocariusEvent] = events.filter { event in
            guard let date = event.startDate else { return false }
            return brandedDays.contains(calendar.startOfDay(for: date))
        }

        sessions = matching.sorted { first, second in
            let firstDate = first.startDate ?? Date.distantFuture
            let secondDate = second.startDate ?? Date.distantFuture
            return firstDate < secondDate
        }

        let sessionDays: [Date] = sessions.compactMap { $0.startDate }.map { calendar.startOfDay(for: $0) }
        days = Set(sessionDays).sorted()
    }

    var isEmpty: Bool { sessions.isEmpty }

    var startDate: Date? { days.first }
    var endDate: Date? { days.last }

    /// "Aug 9 – 14" — shown in the slideshow header
    var dateRangeLabel: String {
        guard let startDate, let endDate else { return "" }
        let month = DateFormatter()
        month.dateFormat = "MMM d"
        let day = DateFormatter()
        day.dateFormat = "d"
        return "\(month.string(from: startDate)) – \(day.string(from: endDate))"
    }

    func isTechWeekDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return days.contains(startOfDay)
    }

    /// Sessions still worth showing — finished ones drop out as the week runs.
    /// Falls back to the full programme so the page never goes blank mid-week.
    func liveSessions(at now: Date) -> [LocariusEvent] {
        let remaining = sessions.filter { ($0.endDateEstimate ?? .distantPast) > now }
        return remaining.isEmpty ? sessions : remaining
    }

    /// Days remaining until the first session (0 once the week has started)
    func daysUntilStart(at now: Date) -> Int {
        guard let startDate else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: startDate).day ?? 0
        return max(0, days)
    }
}

// MARK: - QR Codes
/// Generates a QR code per session so a scan lands on that session's own RSVP page.
enum TechWeekQRCode {
    private static var cache: [String: UIImage] = [:]
    private static let context = CIContext()

    static func image(for string: String) -> UIImage? {
        if let cached = cache[string] { return cached }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let image = UIImage(cgImage: cgImage)
        cache[string] = image
        return image
    }
}
