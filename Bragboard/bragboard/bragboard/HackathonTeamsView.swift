//
//  HackathonTeamsView.swift
//  bragboard
//
//  Team announcements board for the Tech Week hackathon.
//  Static — the roster lives in HackathonTeams.swift, so there are no timers here.
//

#if os(tvOS)
import SwiftUI

private enum HackathonTheme {
    static let backgroundTop = Color(red: 0.15, green: 0.08, blue: 0.30)
    static let backgroundBottom = Color(red: 0.06, green: 0.03, blue: 0.14)
    /// Picks out the row numbers and the rule under the title
    static let accent = Color(red: 0.55, green: 0.47, blue: 1.0)
    static let project = Color.white.opacity(0.78)
    static let undecided = Color.white.opacity(0.45)
}

struct HackathonTeamsView: View {
    let teams: [HackathonTeam]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header

                if teams.isEmpty {
                    Spacer()
                    Text("Teams to be announced")
                        .font(.system(size: 40, weight: .medium, design: .rounded))
                        .foregroundColor(HackathonTheme.undecided)
                    Spacer()
                } else {
                    roster
                }
            }
            .padding(.horizontal, 80)
            .padding(.top, 54)
            .padding(.bottom, 82) // clears the dashboard's own page indicator
        }
    }

    /// A deep gradient with a soft bloom behind the title, echoing the burst on the slide
    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [HackathonTheme.backgroundTop, HackathonTheme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [HackathonTheme.accent.opacity(0.28), .clear],
                center: .init(x: 0.5, y: 0.06),
                startRadius: 0,
                endRadius: 950
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 14) {
            Text("PEI TECH WEEK  ·  HACKATHON")
                .font(.system(size: 22, weight: .semibold))
                .tracking(7)
                .foregroundColor(HackathonTheme.accent)

            Text("TEAM ANNOUNCEMENTS")
                .font(.system(size: 58, weight: .black))
                .tracking(4)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Capsule()
                .fill(HackathonTheme.accent)
                .frame(width: 132, height: 5)
                .padding(.top, 4)
        }
        .padding(.bottom, 22)
    }

    // MARK: - Rows
    private var roster: some View {
        VStack(spacing: 0) {
            ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                row(team, number: index + 1)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func row(_ team: HackathonTeam, number: Int) -> some View {
        HStack(spacing: 26) {
            Text(String(format: "%02d", number))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(HackathonTheme.accent)
                .frame(width: 50, alignment: .leading)

            Text(team.name)
                .font(.system(size: 31, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 300, alignment: .leading)

            if team.isUndecided {
                undecidedChip
                Spacer(minLength: 0)
            } else {
                Text(team.project)
                    .font(.system(size: 25, weight: .regular))
                    .foregroundColor(HackathonTheme.project)
                    // Roughly 105 characters fit on one line; anything longer wraps to a
                    // second rather than shrinking out of step with the rows around it
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(number.isMultiple(of: 2) ? Color.white.opacity(0.05) : .clear)
        )
    }

    /// A quiet chip rather than plain text, so undecided rows read as pending
    /// instead of looking like the project is literally called "TBD"
    private var undecidedChip: some View {
        Text("TBD")
            .font(.system(size: 22, weight: .semibold))
            .tracking(3)
            .foregroundColor(HackathonTheme.undecided)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 2)
            )
    }
}
#endif
