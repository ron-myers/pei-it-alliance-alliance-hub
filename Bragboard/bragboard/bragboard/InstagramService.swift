//
//  InstagramService.swift
//  bragboard
//
//  Instagram follower scraping service
//  Based on SubShow UltraThink approach - HTML scraping from Instagram profile pages
//

import Foundation

struct InstagramProfileData {
    let username: String
    let fullName: String?
    let followerCount: Int
    let followingCount: Int
    let postCount: Int
    let bio: String?
    let profileImageURL: String?
}

enum InstagramError: Error {
    case invalidURL
    case networkError
    case parsingError
    case noData
    case rateLimited

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid Instagram URL"
        case .networkError:
            return "Network connection failed"
        case .parsingError:
            return "Could not parse Instagram data"
        case .noData:
            return "No data received from Instagram"
        case .rateLimited:
            return "Rate limited by Instagram - please try again later"
        }
    }
}

class InstagramService {
    static let shared = InstagramService()

    private init() {}

    func fetchProfile(username: String) async throws -> InstagramProfileData {
        return try await fetchViaScraping(username: username)
    }

    private func fetchViaScraping(username: String) async throws -> InstagramProfileData {
        print("\n📸 ========== STARTING INSTAGRAM SCRAPE ==========")

        let cleanUsername = username.hasPrefix("@") ? String(username.dropFirst()) : username
        let profileURL = "https://www.instagram.com/\(cleanUsername)/"

        print("👤 Username: \(cleanUsername)")
        print("🔗 URL: \(profileURL)")

        guard let url = URL(string: profileURL) else {
            throw InstagramError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0

        print("📡 Fetching HTML...")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstagramError.networkError
        }

        print("📊 HTTP Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw InstagramError.rateLimited
            }
            throw InstagramError.networkError
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw InstagramError.parsingError
        }

        print("✅ HTML received: \(html.count) characters")

        // Parse all data from meta tags first (most reliable)
        let stats = parseStatsFromMetaTag(from: html)
        let followerCount = stats.followers
        let followingCount = stats.following
        let postCount = stats.posts

        print("✅ Parsed from meta tag - Followers: \(followerCount), Following: \(followingCount), Posts: \(postCount)")

        // If meta tag parsing failed, throw error
        if followerCount == 0 && followingCount == 0 && postCount == 0 {
            print("❌ Meta tag parsing failed, trying GraphQL patterns...")
            // Fallback to GraphQL patterns
            let graphQLStats = try parseStatsFromGraphQL(from: html)
            let fullName = parseFullName(from: html)
            let bio = parseBio(from: html)
            let profileImageURL = parseProfileImageURL(from: html)

            return InstagramProfileData(
                username: cleanUsername,
                fullName: fullName,
                followerCount: graphQLStats.followers,
                followingCount: graphQLStats.following,
                postCount: graphQLStats.posts,
                bio: bio,
                profileImageURL: profileImageURL
            )
        }

        let fullName = parseFullName(from: html)
        let bio = parseBio(from: html)
        let profileImageURL = parseProfileImageURL(from: html)

        print("========== SCRAPE COMPLETE ==========\n")

        return InstagramProfileData(
            username: cleanUsername,
            fullName: fullName,
            followerCount: followerCount,
            followingCount: followingCount,
            postCount: postCount,
            bio: bio,
            profileImageURL: profileImageURL
        )
    }

    // MARK: - Meta Tag Parsing (Primary Method)

    private func parseStatsFromMetaTag(from html: String) -> (followers: Int, following: Int, posts: Int) {
        print("\n🔍 Parsing stats from meta tag...")

        // Pattern to match the ACTUAL Instagram format (lowercase, with HTML entities)
        // Example: content="551 followers, 676 following, 4 posts &#x2013; see Instagram..."
        let pattern = "<meta\\s+property=\"og:description\"\\s+content=\"([0-9,]+)\\s+followers?,\\s*([0-9,]+)\\s+following,\\s*([0-9,]+)\\s+posts?"

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           match.numberOfRanges == 4 {

            // Extract all three numbers
            if let followersRange = Range(match.range(at: 1), in: html),
               let followingRange = Range(match.range(at: 2), in: html),
               let postsRange = Range(match.range(at: 3), in: html) {

                let followersStr = String(html[followersRange]).replacingOccurrences(of: ",", with: "")
                let followingStr = String(html[followingRange]).replacingOccurrences(of: ",", with: "")
                let postsStr = String(html[postsRange]).replacingOccurrences(of: ",", with: "")

                print("   Found in meta tag: \(followersStr) followers, \(followingStr) following, \(postsStr) posts")

                let followers = Int(followersStr) ?? 0
                let following = Int(followingStr) ?? 0
                let posts = Int(postsStr) ?? 0

                if followers > 0 || following > 0 || posts > 0 {
                    print("✅ Meta tag parsing successful!")
                    return (followers, following, posts)
                }
            }
        }

        print("⚠️ Meta tag parsing failed")
        return (0, 0, 0)
    }

    // MARK: - GraphQL Parsing (Fallback Method)

    private func parseStatsFromGraphQL(from html: String) throws -> (followers: Int, following: Int, posts: Int) {
        print("\n🔍 Parsing stats from GraphQL data...")

        var followers = 0
        var following = 0
        var posts = 0

        // Try to parse follower count
        let followerPatterns = [
            "\"edge_followed_by\"[\\s\\S]{0,100}\"count\"[\\s\\S]{0,20}([0-9]+)",
            "\"follower_count\"[\\s\\S]{0,20}([0-9]+)",
        ]

        for pattern in followerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html),
               let count = Int(String(html[range])) {
                followers = count
                print("   Found followers in GraphQL: \(count)")
                break
            }
        }

        // Try to parse following count
        let followingPatterns = [
            "\"edge_follow\"[\\s\\S]{0,100}\"count\"[\\s\\S]{0,20}([0-9]+)",
            "\"following_count\"[\\s\\S]{0,20}([0-9]+)",
        ]

        for pattern in followingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html),
               let count = Int(String(html[range])) {
                following = count
                print("   Found following in GraphQL: \(count)")
                break
            }
        }

        // Try to parse post count
        let postPatterns = [
            "\"edge_owner_to_timeline_media\"[\\s\\S]{0,100}\"count\"[\\s\\S]{0,20}([0-9]+)",
            "\"media_count\"[\\s\\S]{0,20}([0-9]+)",
        ]

        for pattern in postPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html),
               let count = Int(String(html[range])) {
                posts = count
                print("   Found posts in GraphQL: \(count)")
                break
            }
        }

        if followers == 0 && following == 0 && posts == 0 {
            print("❌ GraphQL parsing also failed")
            throw InstagramError.parsingError
        }

        print("✅ GraphQL parsing successful!")
        return (followers, following, posts)
    }

    // MARK: - Additional Data Parsing

    private func parseFullName(from html: String) -> String? {
        // Try meta tag first - matches the ACTUAL format
        // Example: "551 followers, 676 following, 4 posts &#x2013; see Instagram photos and videos from Wheels Speed (&#064;lrh.04)"
        let metaPattern = "<meta\\s+property=\"og:description\"\\s+content=\"[^\"]*(?:see|See)\\s+Instagram\\s+photos\\s+and\\s+videos\\s+from\\s+([^(]+)\\s*\\("

        if let regex = try? NSRegularExpression(pattern: metaPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: html) {
            var name = String(html[range]).trimmingCharacters(in: .whitespaces)
            // Decode HTML entities
            name = name.replacingOccurrences(of: "&#064;", with: "@")
            name = name.replacingOccurrences(of: "&quot;", with: "\"")
            name = name.replacingOccurrences(of: "&amp;", with: "&")
            if !name.isEmpty {
                return name
            }
        }

        // Fallback patterns
        let patterns = [
            "\"full_name\"[\\s\\S]{0,20}\"([^\"]+)\"",
            "<meta property=\"og:title\" content=\"([^\"]+)\"",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                let name = String(html[range])
                    .replacingOccurrences(of: " \\(@.*\\)", with: "", options: .regularExpression)
                    .replacingOccurrences(of: " on Instagram", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !name.isEmpty && name.count < 100 {
                    return name
                }
            }
        }

        return nil
    }

    private func parseBio(from html: String) -> String? {
        // Try to extract from meta tag - format: "... on Instagram: "bio text here""
        // Note: Instagram uses lowercase "on instagram:"
        let metaPattern = "<meta\\s+property=\"og:description\"\\s+content=\"[^\"]*on\\s+Instagram:\\s*&quot;([^&]+)(?:&quot;|$)"

        if let regex = try? NSRegularExpression(pattern: metaPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: html) {
            var bio = String(html[range])
            // Decode HTML entities
            bio = bio.replacingOccurrences(of: "&#064;", with: "@")
            bio = bio.replacingOccurrences(of: "&quot;", with: "\"")
            bio = bio.replacingOccurrences(of: "&amp;", with: "&")
            // Decode hex entities like &#x1f3eb; (emojis)
            bio = decodeHexEntities(bio)
            bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

            if !bio.isEmpty && bio.count < 500 {
                return bio
            }
        }

        // Fallback patterns
        let patterns = [
            "\"biography\"[\\s\\S]{0,20}\"((?:[^\"\\\\]|\\\\.)*)\"",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                let bio = String(html[range])
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\/", with: "/")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !bio.isEmpty && bio.count < 500 {
                    return bio
                }
            }
        }

        return nil
    }

    // Helper function to decode hex HTML entities (like &#x1f3eb; for emojis)
    private func decodeHexEntities(_ string: String) -> String {
        var result = string

        // Pattern for hex entities: &#xHHHH; or &#xHHHHHH;
        let pattern = "&#x([0-9A-Fa-f]+);"

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))

            // Process matches in reverse to maintain string indices
            for match in matches.reversed() {
                if match.numberOfRanges > 1,
                   let hexRange = Range(match.range(at: 1), in: string),
                   let fullRange = Range(match.range, in: string) {
                    let hexString = String(string[hexRange])

                    if let codePoint = UInt32(hexString, radix: 16),
                       let scalar = UnicodeScalar(codePoint) {
                        let character = String(scalar)
                        result = result.replacingCharacters(in: fullRange, with: character)
                    }
                }
            }
        }

        return result
    }

    private func parseProfileImageURL(from html: String) -> String? {
        let patterns = [
            "<meta property=\"og:image\" content=\"([^\"]+)\"",
            "\"profile_pic_url_hd\"[\\s\\S]{0,20}\"([^\"]+)\"",
            "\"profile_pic_url\"[\\s\\S]{0,20}\"([^\"]+)\"",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                let urlString = String(html[range])
                    .replacingOccurrences(of: "\\/", with: "/")
                    .replacingOccurrences(of: "\\u0026", with: "&")
                    .replacingOccurrences(of: "&amp;", with: "&")

                if urlString.hasPrefix("http") {
                    return urlString
                }
            }
        }

        return nil
    }
}
