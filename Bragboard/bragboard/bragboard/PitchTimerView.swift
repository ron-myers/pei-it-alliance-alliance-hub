//
//  PitchTimerView.swift
//  bragboard
//
//  Full-screen pitch clock for ITA pitch competitions.
//  Driven by a timekeeper on the Siri Remote, shown on one screen that both the
//  presenter and the judges can see.
//

#if os(tvOS)
import SwiftUI
import UIKit

// MARK: - Palette
/// Spark Tank yellow throughout. The screen never changes colour — a phase ending is
/// signalled by the phase itself changing, not by the background.
private enum TimerPalette {
    static let brand = Color(red: 0.949, green: 0.816, blue: 0.298)
    /// White on this yellow is about 1.7:1 and unreadable, so type is ink
    static let ink = Color(red: 0.106, green: 0.098, blue: 0.078)
}

// MARK: - View
struct PitchTimerView: View {
    let onDone: () -> Void

    @State private var clock = PitchClock()

    var body: some View {
        // 4 Hz is plenty for a seconds clock and keeps the redraw scoped to this view
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            ZStack {
                TimerPalette.brand.ignoresSafeArea()

                VStack(spacing: 0) {
                    Text(clock.phase.label)
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .tracking(14)
                        .foregroundColor(TimerPalette.ink.opacity(0.8))

                    Text(clockText(clock.remaining(at: context.date)))
                        .font(.system(size: 300, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(TimerPalette.ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    statusLine
                }
                .padding(.horizontal, 60)

                logo
            }
        }
        .task {
            // Handing over is a state change, so it is driven here rather than from the
            // body, where mutating state during evaluation is undefined behaviour.
            while !Task.isCancelled {
                let now = Date()
                if clock.hasExpired(at: now) { clock.advance(at: now) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        .focusable(true)
        // Matches how the dashboard already detects a Select press on the remote
        .onLongPressGesture(minimumDuration: 0.01) { clock.toggle(at: Date()) }
        .onPlayPauseCommand { clock.toggle(at: Date()) }
        .onMoveCommand { direction in
            switch direction {
            case .right: clock.advance(at: Date())
            case .left: clock.back()
            default: break
            }
        }
        .onExitCommand(perform: onDone)
        .onAppear {
            // An Apple TV dozing off mid-question would be the worst possible failure
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func clockText(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Remote hints are on the same screen as the judges, so they only show while the
    /// clock is stopped — never during a pitch.
    @ViewBuilder
    private var statusLine: some View {
        if clock.isRunning {
            Text(" ")
                .font(.system(size: 40, weight: .bold, design: .rounded))
        } else {
            Text(hint)
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .foregroundColor(TimerPalette.ink.opacity(0.55))
        }
    }

    private var hint: String {
        let click = clock.isAtFullTime ? "Click to start" : "Click to resume"

        switch clock.phase {
        case .ready: return "Click to start the pitch"
        case .pitch: return "\(click)  ·  Swipe right for questions  ·  Swipe left to go back"
        case .questions: return "\(click)  ·  Swipe right for the next team  ·  Swipe left to go back"
        }
    }

    /// Black artwork straight onto the yellow, the way it sits on the Spark Tank poster.
    /// Tinting it white is not an option — the bridge badge has opaque white detail inside
    /// it, so template rendering flattens the badge into a solid disc.
    private var logo: some View {
        VStack {
            HStack {
                Spacer()
                Image("PIA logo-02")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 230)
                    .padding(.trailing, 90)
                    .padding(.top, 62)
            }
            Spacer()
        }
    }
}
#endif
