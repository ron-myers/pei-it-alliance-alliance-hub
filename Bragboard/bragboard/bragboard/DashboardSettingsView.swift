//
//  DashboardSettingsView.swift
//  bragboard
//
//  Full-screen settings for the auto-rotation: which pages are in it, how long each
//  one holds, and whether the page indicator is drawn.
//

#if os(tvOS)
import SwiftUI

struct DashboardSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    let settings: DashboardSettings
    let onDone: () -> Void

    private var textColor: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            // Each block is its own focus section, so the remote can always move between them.
            // Without this the buttons don't line up in a column — Page indicator sits right,
            // Done sits left — and once most rows are switched off the focus engine finds
            // nothing below and traps you in the list.
            VStack(spacing: 6) {
                ForEach(DashboardPage.allCases) { page in
                    row(for: page)
                }
            }
            .focusSection()

            loopSummary

            Divider()
                .padding(.vertical, 24)

            pageDotsRow
                .focusSection()

            Spacer()

            HStack {
                Button("Done", action: onDone)
                    .font(.system(size: 30, weight: .semibold))
                    .buttonStyle(.card)

                Spacer()
            }
            .focusSection()
        }
        .padding(.horizontal, 120)
        .padding(.vertical, 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background((colorScheme == .dark ? Color.black : Color(white: 0.95)).ignoresSafeArea())
        // Menu on the remote always closes this, whatever the focus is doing
        .onExitCommand(perform: onDone)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rotation")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(textColor)

            Text("Pick which pages the screen cycles through, and how much of the loop each one gets. One unit is 30 seconds, and the units always add up to \(DashboardSettings.total).")
                .font(.system(size: 24))
                .foregroundColor(textColor.opacity(0.6))
                .frame(maxWidth: 1100, alignment: .leading)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Page Row
    private func row(for page: DashboardPage) -> some View {
        let isOn = settings.isEnabled(page)

        return HStack(spacing: 26) {
            Image(systemName: page.icon)
                .font(.system(size: 28, weight: .medium))
                .frame(width: 44)

            Text(page.title)
                .font(.system(size: 30, weight: .medium))
                .frame(width: 260, alignment: .leading)

            Button {
                settings.toggle(page)
            } label: {
                Text(isOn ? "On" : "Off")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 100, height: 56)
            }
            .buttonStyle(.card)
            // The rotation always keeps at least one page
            .disabled(isOn && settings.rotation.count == 1)

            stepper(for: page)
                .opacity(isOn ? 1 : 0.35)

            Text(isOn ? settings.durationLabel(page) : "not in rotation")
                .font(.system(size: 24))
                .foregroundColor(textColor.opacity(0.6))
                .frame(width: 240, alignment: .leading)
        }
        .foregroundColor(textColor)
        .opacity(isOn ? 1 : 0.55)
    }

    private func stepper(for page: DashboardPage) -> some View {
        HStack(spacing: 16) {
            Button {
                settings.decrease(page)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 68, height: 56)
            }
            .buttonStyle(.card)
            .disabled(!settings.canDecrease(page))

            Text(settings.isEnabled(page) ? "\(settings.ratio(page))" : "0")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 54)

            Button {
                settings.increase(page)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 68, height: 56)
            }
            .buttonStyle(.card)
            .disabled(!settings.canIncrease(page))
        }
    }

    // MARK: - Summary
    private var loopSummary: some View {
        let seconds = Int(Double(DashboardSettings.total) * DashboardSettings.unitDuration)

        return Text("Full loop: \(DashboardSettings.total) units · \(seconds / 60) minutes")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(textColor.opacity(0.6))
            .padding(.top, 28)
    }

    // MARK: - Page Dots
    private var pageDotsRow: some View {
        HStack(spacing: 26) {
            Image(systemName: "circle.grid.3x1.fill")
                .font(.system(size: 28, weight: .medium))
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Page indicator")
                    .font(.system(size: 30, weight: .medium))
                Text("The row of dots along the bottom showing which page is on screen")
                    .font(.system(size: 22))
                    .foregroundColor(textColor.opacity(0.6))
            }
            .frame(width: 700, alignment: .leading)

            Button {
                settings.showPageDots.toggle()
            } label: {
                Text(settings.showPageDots ? "On" : "Off")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 100, height: 56)
            }
            .buttonStyle(.card)

            Spacer()
        }
        .foregroundColor(textColor)
    }
}
#endif
