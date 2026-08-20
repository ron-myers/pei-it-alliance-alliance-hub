//
//  TechWeekSlideshowView.swift
//  bragboard
//
//  Full-screen Tech Week programme slideshow.
//  Poster on the left (straight from the Locarius API), session detail and a live RSVP QR on the right.
//

#if os(tvOS)
import SwiftUI

// MARK: - Slideshow Timing
enum TechWeekSlideshow {
    /// The page keeps advancing at this rate for as long as the rotation leaves it on screen
    static let slideDuration: TimeInterval = 15
}

// MARK: - Slideshow Page
struct TechWeekSlideshowView: View {
    let schedule: TechWeekSchedule
    let isVisible: Bool

    @State private var slideIndex = 0
    @State private var now = Date()
    @State private var slideTimer: Timer?
    @State private var clockTimer: Timer?
    @State private var poster: TechWeekPoster?
    @State private var palette: TechWeekPalette = .brand

    private var sessions: [LocariusEvent] {
        schedule.liveSessions(at: now)
    }

    private var currentSession: LocariusEvent? {
        guard !sessions.isEmpty else { return nil }
        return sessions[slideIndex % sessions.count]
    }

    var body: some View {
        ZStack {
            palette.gradient.ignoresSafeArea()

            if let session = currentSession {
                VStack(spacing: 0) {
                    header
                    sessionSlide(session)
                        .id(session.id)
                        // Push rather than crossfade, so outgoing and incoming text never overlap
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    footer
                }
            } else {
                emptyState
            }
        }
        .task(id: currentSession?.url) {
            await loadPoster(for: currentSession)
        }
        .onAppear {
            startClockTimer()
            if isVisible { startSlideTimer() }
        }
        .onDisappear {
            stopSlideTimer()
            stopClockTimer()
        }
        .onChange(of: isVisible) { _, visible in
            if visible {
                startSlideTimer()
            } else {
                stopSlideTimer()
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 30) {
            VStack(alignment: .leading, spacing: 10) {
                Text("PEI TECH WEEK")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text(headerSubtitle)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(palette.accent)
            }

            Spacer()

            dayRail
        }
        .padding(.horizontal, 80)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    private var headerSubtitle: String {
        let daysAway = schedule.daysUntilStart(at: now)
        if daysAway > 0 {
            return "\(schedule.dateRangeLabel)  ·  \(daysAway) \(daysAway == 1 ? "day" : "days") to go"
        }
        return schedule.dateRangeLabel
    }

    /// Sun → Fri strip showing which day the current slide belongs to
    private var dayRail: some View {
        HStack(spacing: 12) {
            ForEach(schedule.days, id: \.self) { day in
                let isCurrent = isDayOfCurrentSlide(day)

                VStack(spacing: 2) {
                    Text(dayLabel(day, format: "EEE").uppercased())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(dayLabel(day, format: "d"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                }
                .foregroundColor(isCurrent ? palette.bottom : .white)
                .frame(width: 74, height: 74)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isCurrent ? Color.white : Color.white.opacity(0.18))
                )
            }
        }
    }

    // MARK: - Slide
    private func sessionSlide(_ session: LocariusEvent) -> some View {
        HStack(alignment: .center, spacing: 50) {
            posterView
                .frame(maxWidth: .infinity)

            detail(for: session)
                .frame(width: 640, alignment: .leading)
        }
        .padding(.horizontal, 80)
        .frame(maxHeight: .infinity)
    }

    private var posterView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.25))

            if let image = poster?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("PIA logo-02")
                    .resizable()
                    .scaledToFit()
                    .padding(80)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
    }

    /// Loads the current poster, then warms the next two so the following transitions are instant
    private func loadPoster(for session: LocariusEvent?) async {
        guard let session else { return }

        let loaded = await TechWeekPosterCache.shared.poster(for: session.logo)

        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.8)) {
            poster = loaded
            palette = loaded?.palette ?? .brand
        }

        for upcoming in nextSessions(count: 2) {
            _ = await TechWeekPosterCache.shared.poster(for: upcoming.logo)
        }
    }

    private func nextSessions(count: Int) -> [LocariusEvent] {
        guard !sessions.isEmpty else { return [] }
        return (1...count).map { sessions[(slideIndex + $0) % sessions.count] }
    }

    private func detail(for session: LocariusEvent) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(dayHeadline(for: session))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(palette.accent)
                .tracking(2)

            Text(session.techWeekTitle)
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(session.timeOfDay)  ·  \(session.capacityLine)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            statusBadge(for: session)

            Text(session.summary)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            rsvpBlock(for: session)
        }
    }

    private func statusBadge(for session: LocariusEvent) -> some View {
        let happeningNow = session.isHappeningNow(at: now)

        return HStack(spacing: 12) {
            Circle()
                .fill(happeningNow ? Color.green : palette.accent)
                .frame(width: 14, height: 14)

            Text(statusText(for: session))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(happeningNow ? Color.green.opacity(0.28) : Color.black.opacity(0.22))
        )
    }

    private func rsvpBlock(for session: LocariusEvent) -> some View {
        HStack(spacing: 24) {
            if let qr = TechWeekQRCode.image(for: session.url) {
                Image(uiImage: qr)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Scan to RSVP")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("peiitalliance.com/tech-week/2026")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 14) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, _ in
                Capsule()
                    .fill(index == slideIndex % max(1, sessions.count)
                          ? Color.white
                          : Color.white.opacity(0.35))
                    .frame(width: index == slideIndex % max(1, sessions.count) ? 34 : 12, height: 10)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 75) // clears the dashboard's own page indicator
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: slideIndex)
    }

    private var emptyState: some View {
        VStack(spacing: 26) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 140))
            Text("Tech Week Wrapped")
                .font(.system(size: 60, weight: .bold, design: .rounded))
            Text("See you next year")
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .opacity(0.8)
        }
        .foregroundColor(.white)
    }

    // MARK: - Formatting
    private func statusText(for session: LocariusEvent) -> String {
        guard let start = session.startDate else { return "" }

        if session.isHappeningNow(at: now) { return "HAPPENING NOW" }

        let secondsAway = start.timeIntervalSince(now)

        if secondsAway > 0 && secondsAway < 3600 {
            let minutes = max(1, Int(secondsAway) / 60)
            return "STARTS IN \(minutes) MIN"
        }

        if Calendar.current.isDateInToday(start) {
            return "TODAY  ·  \(session.timeOfDay)"
        }

        if Calendar.current.isDateInTomorrow(start) {
            return "TOMORROW  ·  \(session.timeOfDay)"
        }

        let calendar = Calendar.current
        let daysAway = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: start).day ?? 0
        return "IN \(daysAway) DAYS"
    }

    private func dayHeadline(for session: LocariusEvent) -> String {
        guard let start = session.startDate else { return "" }
        return dayLabel(start, format: "EEEE, MMM d").uppercased()
    }

    private func dayLabel(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func isDayOfCurrentSlide(_ day: Date) -> Bool {
        guard let start = currentSession?.startDate else { return false }
        return Calendar.current.isDate(start, inSameDayAs: day)
    }

    // MARK: - Timers
    private func startSlideTimer() {
        stopSlideTimer()
        slideTimer = Timer.scheduledTimer(withTimeInterval: TechWeekSlideshow.slideDuration, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                slideIndex += 1
            }
        }
    }

    private func stopSlideTimer() {
        slideTimer?.invalidate()
        slideTimer = nil
    }

    private func startClockTimer() {
        stopClockTimer()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            now = Date()
        }
    }

    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
}
#endif
