//
//  HackathonTeams.swift
//  bragboard
//
//  Roster for the Tech Week hackathon team announcements board.
//

import Foundation

struct HackathonTeam: Identifiable {
    let id = UUID()
    let name: String
    /// One short line describing what the team is building
    let project: String

    /// Projects that have not been decided yet come through as "TBD"
    var isUndecided: Bool {
        project.trimmingCharacters(in: .whitespaces).uppercased() == "TBD"
    }
}

enum HackathonRoster {
    /// Edit this list as teams firm up — one row per team, in screen order.
    /// Lines up to about 105 characters sit on one line; longer ones wrap to a second.
    static let teams: [HackathonTeam] = [
        HackathonTeam(name: "Academic Copilot",
                      project: "An AI-powered academic assistant that analyzes a student’s live university record to answer academic questions, find matching scholarships, and guide them through eligibility and application steps."),
        HackathonTeam(name: "Solo Ops",
                      project: "An AI agent that takes your food order and places it"),
        HackathonTeam(name: "The Guerillaz",
                      project: "AI Agent that handles appointments for you and your clients"),
        HackathonTeam(name: "Junk Claw",
                      project: "A browser extension that turns two hundred used-car listings into the three worth your evening."),
        HackathonTeam(name: "GroundWork",
                      project: "A privacy-first agent that turns confusing government letters into a clear action plan, running entirely on local models."),
        HackathonTeam(name: "Team Doug",
                      project: "An Airbnb-style booking experience for finding places to stay"),
        HackathonTeam(name: "Team Fun",
                      project: "GitLore is an AI agent skill that watches a GitHub repository and turns its daily commits, pull requests, and code changes into a fun, evidence-backed, brain-rot-style scrollable story."),
        HackathonTeam(name: "Winning Team",
                      project: "Front door AI Agent that grants access for The Foundry"),
        HackathonTeam(name: "Team Aman",
                      project: "An AI parking assistant that predicts your chances of finding a spot."),
        HackathonTeam(name: "Access Agent",
                      project: "A personalized care-giver guided workflow for configuring a mouth-controlled computer device for people with quadriplegia."),
        HackathonTeam(name: "Cron Draper",
                      project: "Ad Agency AI Agent")
    ]
}
