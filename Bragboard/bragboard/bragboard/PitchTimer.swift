//
//  PitchTimer.swift
//  bragboard
//
//  Clock behind the pitch competition timer. Kept free of SwiftUI so the arithmetic
//  can be exercised on its own.
//

import Foundation

// MARK: - Phases
enum PitchPhase {
    case ready
    case pitch
    case questions

    // Spark Tank format. Change these two lines for a different format.
    static let pitchDuration: TimeInterval = 3 * 60
    static let questionsDuration: TimeInterval = 5 * 60

    var label: String {
        switch self {
        case .ready: return "READY"
        case .pitch: return "PITCH"
        case .questions: return "QUESTIONS"
        }
    }

    /// What the clock reads when this phase starts
    var duration: TimeInterval {
        switch self {
        case .ready, .pitch: return Self.pitchDuration
        case .questions: return Self.questionsDuration
        }
    }

    /// Questions wraps back to ready, so the timekeeper is set up for the next team
    var next: PitchPhase {
        switch self {
        case .ready: return .pitch
        case .pitch: return .questions
        case .questions: return .ready
        }
    }
}

// MARK: - Clock
/// Time is held as a deadline rather than a counter that gets decremented, so the clock
/// cannot drift no matter how often the view redraws.
///
/// A phase ends either when the timekeeper says so or when it runs out, whichever comes
/// first — so finishing early is the normal path, not a special case, and nothing ever
/// runs into overtime.
struct PitchClock {
    private(set) var phase: PitchPhase = .ready
    private(set) var isRunning = false

    private var deadline = Date()
    private var pausedRemaining = PitchPhase.ready.duration

    /// Where the previous phase stood when it was left, so a mis-swipe is recoverable
    private var undo: (phase: PitchPhase, remaining: TimeInterval)?

    /// Never negative — a phase that reaches zero hands over instead of overrunning
    func remaining(at now: Date) -> TimeInterval {
        max(0, isRunning ? deadline.timeIntervalSince(now) : pausedRemaining)
    }

    /// A running phase that has reached zero and is due to hand over to the next one
    func hasExpired(at now: Date) -> Bool {
        isRunning && deadline <= now
    }

    /// True when the phase is sitting at its full time, untouched
    var isAtFullTime: Bool {
        !isRunning && pausedRemaining == phase.duration
    }

    /// Select / Play-Pause — starts the pitch from ready, otherwise pauses and resumes
    mutating func toggle(at now: Date) {
        if phase == .ready {
            advance(at: now)
        }

        if isRunning {
            pausedRemaining = deadline.timeIntervalSince(now)
            isRunning = false
        } else {
            deadline = now.addingTimeInterval(pausedRemaining)
            isRunning = true
        }
    }

    /// Swipe right, or the phase running out. Either way the new phase parks paused rather
    /// than starting itself — whether someone finished early or ran to the buzzer, the room
    /// is still resettling, so the timekeeper starts it when everyone is actually ready.
    mutating func advance(at now: Date) {
        undo = (phase, remaining(at: now))
        phase = phase.next
        pausedRemaining = phase.duration
        isRunning = false
    }

    /// Swipe left — go back. The first press restores the previous phase exactly where it
    /// was left, which undoes an accidental swipe without losing the elapsed time. A
    /// second press refills the current phase for a clean restart after a false start.
    mutating func back() {
        if let undo {
            phase = undo.phase
            pausedRemaining = undo.remaining
            self.undo = nil
        } else {
            pausedRemaining = phase.duration
        }

        isRunning = false
    }
}
