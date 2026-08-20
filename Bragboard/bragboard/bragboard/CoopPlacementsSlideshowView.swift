//
//  CoopPlacementsSlideshowView.swift
//  bragboard
//
//  Full-screen Co-op Placements slideshow. Two students per slide —
//  headshot top-left, QR bottom-left, everything else on the right.
//

#if os(tvOS)
import SwiftUI

// MARK: - Slideshow Timing
enum CoopPlacementsSlideshow {
    /// The page keeps advancing at this rate for as long as the rotation leaves it on screen
    static let slideDuration: TimeInterval = 15
}

// MARK: - Slideshow Page
struct CoopPlacementsSlideshowView: View {
    let students: [CoopStudent]
    let isVisible: Bool

    @State private var slideIndex = 0
    @State private var slideTimer: Timer?

    /// Two students per slide, the last one alone when the count is odd
    private var pairs: [[CoopStudent]] {
        stride(from: 0, to: students.count, by: 2).map {
            Array(students[$0..<min($0 + 2, students.count)])
        }
    }

    private var currentPair: [CoopStudent] {
        guard !pairs.isEmpty else { return [] }
        return pairs[slideIndex % pairs.count]
    }

    var body: some View {
        ZStack {
            CoopTheme.gradient.ignoresSafeArea()

            if currentPair.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    header
                    slide(currentPair)
                        .id(slideIndex % max(1, pairs.count))
                        // Push rather than crossfade, so outgoing and incoming cards never overlap
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    footer
                }
            }
        }
        .onAppear {
            if isVisible { startSlideTimer() }
        }
        .onDisappear {
            stopSlideTimer()
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
                Text("CO-OP PLACEMENTS")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("Students looking for co-op placements  ·  Scan a code to connect")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(CoopTheme.accent)
            }

            Spacer()

            Text("\(students.count) \(students.count == 1 ? "STUDENT" : "STUDENTS")")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.white.opacity(0.16)))
        }
        .padding(.horizontal, 80)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    // MARK: - Slide
    private func slide(_ pair: [CoopStudent]) -> some View {
        HStack(alignment: .top, spacing: 40) {
            ForEach(pair) { student in
                studentCard(student)
            }

            // Keep a lone last student at half width instead of stretching across the screen
            if pair.count == 1 {
                Color.clear.frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 80)
        .frame(maxHeight: .infinity)
    }

    private func studentCard(_ student: CoopStudent) -> some View {
        HStack(alignment: .top, spacing: 30) {
            // Left column: headshot on top, QR at the bottom
            VStack(spacing: 0) {
                headshot(student)

                Spacer(minLength: 20)

                qrBlock(student)
            }
            .frame(width: 250)

            // Right column: everything else
            VStack(alignment: .leading, spacing: 22) {
                Text(student.name)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                section("EDUCATION") {
                    Text(student.education)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Students without a placement yet simply have no section —
                // education and skills take the room instead
                if let experience = student.experienceText {
                    section("EXPERIENCE") {
                        Text(experience)
                            .font(.system(size: 21, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                section("SKILLS") {
                    SkillFlowLayout(spacing: 10) {
                        ForEach(student.skillList, id: \.self) { skill in
                            Text(skill)
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.14)))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(CoopTheme.accent)
                .tracking(2)

            content()
        }
    }

    private func headshot(_ student: CoopStudent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.25))

            if let image = CoopHeadshots.image(named: student.headshot) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(student.initials)
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: 250, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private func qrBlock(_ student: CoopStudent) -> some View {
        VStack(spacing: 10) {
            if let url = student.qrURL, let qr = TechWeekQRCode.image(for: url) {
                Image(uiImage: qr)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

                if let label = student.qrLabel {
                    Text(label)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 14) {
            ForEach(pairs.indices, id: \.self) { index in
                Capsule()
                    .fill(index == slideIndex % max(1, pairs.count)
                          ? Color.white
                          : Color.white.opacity(0.35))
                    .frame(width: index == slideIndex % max(1, pairs.count) ? 34 : 12, height: 10)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 75) // clears the dashboard's own page indicator
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: slideIndex)
    }

    private var emptyState: some View {
        VStack(spacing: 26) {
            Image(systemName: "graduationcap")
                .font(.system(size: 140))
            Text("Co-op Placements")
                .font(.system(size: 60, weight: .bold, design: .rounded))
            Text("No students yet")
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .opacity(0.8)
        }
        .foregroundColor(.white)
    }

    // MARK: - Timers
    private func startSlideTimer() {
        stopSlideTimer()
        slideTimer = Timer.scheduledTimer(withTimeInterval: CoopPlacementsSlideshow.slideDuration, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                slideIndex += 1
            }
        }
    }

    private func stopSlideTimer() {
        slideTimer?.invalidate()
        slideTimer = nil
    }
}

// MARK: - Skill Chips Layout
/// Left-aligned wrapping row — SwiftUI has no built-in flow layout, and the
/// skills list is exactly the kind of content that needs one.
struct SkillFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, in: proposal.width ?? .infinity)
        let height = rows.last.map { $0.minY + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, in: bounds.width)
        for (subview, frame) in zip(subviews, rows) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    /// One frame per subview, wrapped into rows within `maxWidth`
    private func arrange(_ subviews: Subviews, in maxWidth: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return frames
    }
}
#endif
