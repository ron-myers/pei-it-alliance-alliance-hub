//
//  DashboardSettings.swift
//  bragboard
//
//  Which pages the auto-rotation visits, how long each one holds, and whether the
//  page indicator is drawn. Stored on this Apple TV only.
//

import Foundation

// MARK: - Pages
/// The pages the dashboard can show, in the order they sit on screen.
/// The raw value IS the page index used by `currentPage`.
enum DashboardPage: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case logo = 1
    case calendar = 2
    case photos = 3
    case countdown = 4
    case techWeek = 5
    case coopPlacements = 6
    case hackathon = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .logo: return "Logo"
        case .calendar: return "Calendar"
        case .photos: return "Photos"
        case .countdown: return "Countdown"
        case .techWeek: return "Tech Week"
        case .coopPlacements: return "Co-op Placements"
        case .hackathon: return "Hackathon Teams"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .logo: return "building.2"
        case .calendar: return "calendar"
        case .photos: return "photo.on.rectangle.angled"
        case .countdown: return "timer"
        case .techWeek: return "sparkles.tv"
        case .coopPlacements: return "graduationcap"
        case .hackathon: return "person.3.fill"
        }
    }
}

// MARK: - Settings
/// One ratio unit is 30 seconds of screen time, and the ratios of the pages that are
/// switched on always add up to 10 — so a page's ratio is literally its share of a
/// five-minute loop. Keeping that invariant in the model means the settings screen can
/// never be left in a state the rotation has to interpret.
@Observable
final class DashboardSettings {
    /// Ratio units in one full loop
    static let total = 10
    /// Screen time one ratio unit buys
    static let unitDuration: TimeInterval = 30

    private static let ratiosKey = "rotation.ratios"
    private static let enabledKey = "rotation.enabled"
    private static let pageDotsKey = "rotation.showPageDots"

    /// Share of the loop, per page. Meaningful for switched-on pages; for switched-off
    /// pages it is remembered so the ratio comes back when the page is switched on again.
    private var ratios: [Int]
    private var enabled: [Bool]

    var showPageDots: Bool {
        didSet { UserDefaults.standard.set(showPageDots, forKey: Self.pageDotsKey) }
    }

    /// Dashboard 1 : Calendar 2 : Tech Week 3 : Co-op 2 : Hackathon 2, with the other
    /// three pages available from the sidebar but out of the rotation.
    private static let defaultRatios = [1, 1, 2, 1, 1, 3, 2, 2]
    private static let defaultEnabled = [true, false, true, false, false, true, true, true]

    init() {
        let defaults = UserDefaults.standard
        let count = DashboardPage.allCases.count

        let storedRatios = defaults.array(forKey: Self.ratiosKey) as? [Int] ?? []
        let storedEnabled = defaults.array(forKey: Self.enabledKey) as? [Bool] ?? []

        ratios = storedRatios.count == count ? storedRatios : Self.defaultRatios
        enabled = storedEnabled.count == count ? storedEnabled : Self.defaultEnabled

        showPageDots = defaults.object(forKey: Self.pageDotsKey) as? Bool ?? true
    }

    // MARK: Reading
    func isEnabled(_ page: DashboardPage) -> Bool { enabled[page.rawValue] }

    func ratio(_ page: DashboardPage) -> Int { ratios[page.rawValue] }

    /// Switched-on pages, in screen order — this is the rotation itself
    var rotation: [DashboardPage] {
        DashboardPage.allCases.filter { enabled[$0.rawValue] }
    }

    /// How long a page holds before the rotation moves on
    func duration(_ page: DashboardPage) -> TimeInterval {
        Double(ratios[page.rawValue]) * Self.unitDuration
    }

    /// "3m 30s" — shown next to the ratio so the number means something
    func durationLabel(_ page: DashboardPage) -> String {
        let seconds = Int(duration(page))
        let minutes = seconds / 60
        let remainder = seconds % 60

        if minutes == 0 { return "\(remainder)s" }
        if remainder == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remainder)s"
    }

    // MARK: Editing
    /// A page can only go up if some other switched-on page has a unit to spare
    func canIncrease(_ page: DashboardPage) -> Bool {
        enabled[page.rawValue] && donor(excluding: page.rawValue) != nil
    }

    /// Never let a switched-on page fall to zero — switching it off is what zero means
    func canDecrease(_ page: DashboardPage) -> Bool {
        enabled[page.rawValue] && ratios[page.rawValue] > 1 && receiver(excluding: page.rawValue) != nil
    }

    func increase(_ page: DashboardPage) {
        guard let donor = donor(excluding: page.rawValue), enabled[page.rawValue] else { return }
        ratios[donor] -= 1
        ratios[page.rawValue] += 1
        save()
    }

    func decrease(_ page: DashboardPage) {
        guard canDecrease(page), let receiver = receiver(excluding: page.rawValue) else { return }
        ratios[page.rawValue] -= 1
        ratios[receiver] += 1
        save()
    }

    /// Switching a page off frees its units to the rest; switching it back on takes them
    /// again, as far as the other pages can afford without any of them hitting zero.
    func toggle(_ page: DashboardPage) {
        let index = page.rawValue

        if enabled[index] {
            guard rotation.count > 1 else { return } // the rotation always keeps one page
            let freed = ratios[index]
            enabled[index] = false
            for _ in 0..<freed {
                guard let receiver = receiver(excluding: index) else { break }
                ratios[receiver] += 1
            }
        } else {
            let wanted = max(1, ratios[index])
            enabled[index] = true
            ratios[index] = 0
            for _ in 0..<wanted {
                guard let donor = donor(excluding: index) else { break }
                ratios[donor] -= 1
                ratios[index] += 1
            }
        }

        save()
    }

    /// The switched-on page with the most to give, ignoring `index`
    private func donor(excluding index: Int) -> Int? {
        ratios.indices
            .filter { $0 != index && enabled[$0] && ratios[$0] > 1 }
            .max { ratios[$0] < ratios[$1] }
    }

    /// The switched-on page with the least, ignoring `index` — spreads freed units around
    private func receiver(excluding index: Int) -> Int? {
        ratios.indices
            .filter { $0 != index && enabled[$0] }
            .min { ratios[$0] < ratios[$1] }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(ratios, forKey: Self.ratiosKey)
        defaults.set(enabled, forKey: Self.enabledKey)
    }
}
