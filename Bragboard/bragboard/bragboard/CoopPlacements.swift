//
//  CoopPlacements.swift
//  bragboard
//
//  Co-op Placements roster, branding and headshot loading.
//  Students come from coop-students.json in the CoopStudents folder — drop new form
//  responses into the JSON and their headshot file next to it, no code changes needed.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Co-op Branding
/// Deep blue look so the co-op page reads distinctly from Tech Week's coral
enum CoopTheme {
    static let top = Color(red: 0.12, green: 0.23, blue: 0.47)
    static let bottom = Color(red: 0.06, green: 0.10, blue: 0.24)
    static let accent = Color(red: 0.55, green: 0.78, blue: 1.0)

    static var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Student
/// One Google Form response. Keys mirror the form's questions.
struct CoopStudent: Identifiable, Decodable {
    let name: String
    let education: String
    let experience: String?
    let skills: String
    let website: String?
    let linkedin: String?
    let headshot: String?

    var id: String { name }

    /// Skills arrive as one comma-separated line on the form
    var skillList: [String] {
        skills
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Students without a placement yet leave the experience box empty — treat whitespace as none
    var experienceText: String? {
        guard let trimmed = experience?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// The QR lands on the portfolio site when there is one, else LinkedIn
    var qrURL: String? {
        [website, linkedin]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    /// "yosefmekonnen.dev" — shown under the QR so people know where the scan goes
    var qrLabel: String? {
        guard let qrURL else { return nil }
        return qrURL
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Fallback monogram for students whose headshot is missing
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }

    /// Reads coop-students.json out of the bundle. A missing or malformed file just means
    /// an empty roster, which switches the page off — same pattern as Tech Week ending.
    static func loadRoster() -> [CoopStudent] {
        guard let url = Bundle.main.url(forResource: "coop-students", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let students = try? JSONDecoder().decode([CoopStudent].self, from: data) else {
            return []
        }
        return students
    }
}

#if canImport(UIKit)
// MARK: - Headshots
/// Headshot files ship loose in the bundle (from the CoopStudents folder),
/// decoded once and kept — same idea as TechWeekPosterCache.
@MainActor
enum CoopHeadshots {
    private static var cache: [String: UIImage] = [:]

    static func image(named filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        if let hit = cache[filename] { return hit }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext),
              let image = UIImage(contentsOfFile: url.path) else { return nil }

        let decoded = image.preparingForDisplay() ?? image
        cache[filename] = decoded
        return decoded
    }
}
#endif
