//
//  WidgetViews.swift
//  bragboard
//
//  Reusable view components for each widget type
//  ✨ NEW: We're Hiring widget added
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Widget View Protocol
protocol WidgetViewProtocol: View {
    var widget: Widget { get }
}

// MARK: - Company Logo Widget
struct LogoWidgetView: View {
    let widget: Widget
    
    var body: some View {
        VStack {
            Spacer()
            if let imageData = widget.configuration?.imageData {
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                }
                #elseif os(tvOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                }
                #endif
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "building.2")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Add Logo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - Customer Counter Widget
struct CustomerCounterWidgetView: View {
    let widget: Widget
    
    private var label: String {
        let configLabel = widget.configuration?.counterLabel ?? ""
        return configLabel.isEmpty ? "Customers Served" : configLabel
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Counter value
            Text(MockDataService.formatNumber(
                widget.configuration?.counterValue ?? 0,
                style: .full
            ))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            // Custom label
            Text(label)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Decorative icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Instagram Followers Widget (Mock Data)
struct InstagramFollowersWidgetView: View {
    let widget: Widget
    @State private var followerCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Instagram icon (simulated)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            // Follower count
            Text(MockDataService.formatNumber(followerCount))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            // Label
            Text("Instagram Followers")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Mock data badge
            Text("SAMPLE DATA")
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color.black.opacity(0.3))
        .onAppear {
            // Load mock data
            followerCount = MockDataService.shared.getInstagramFollowers()
        }
    }
}

// MARK: - Location Map Widget (Mock Data)
struct LocationMapWidgetView: View {
    let widget: Widget
    @State private var locations: [String] = []
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Map icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            // Location count
            Text("\(locations.count)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text("Locations Worldwide")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Mock data badge
            Text("SAMPLE DATA")
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.green.opacity(0.3), Color.teal.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onAppear {
            // Load mock data
            locations = MockDataService.shared.getLocationNames()
        }
    }
}

// MARK: - Years in Business Widget
struct YearsInBusinessWidgetView: View {
    let widget: Widget
    
    private var yearsInBusiness: Int {
        guard let startDate = widget.configuration?.startDate else { return 0 }
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: startDate, to: Date()).year ?? 0
        return max(0, years)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Calendar icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            // Years count
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(yearsInBusiness)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text(yearsInBusiness == 1 ? "Year" : "Years")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text("In Business")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            
            Spacer()
            
            // Start date display
            if let startDate = widget.configuration?.startDate {
                Text("Since \(startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("Set start date")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Days Since Incident Widget
struct DaysSinceIncidentWidgetView: View {
    let widget: Widget
    
    private var daysSinceIncident: Int {
        guard let incidentDate = widget.configuration?.incidentDate else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: incidentDate, to: Date()).day ?? 0
        return max(0, days)
    }
    
    private var incidentLabel: String {
        widget.configuration?.incidentLabel ?? "Last Incident"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Safety shield icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            // Days count
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(daysSinceIncident)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text(daysSinceIncident == 1 ? "Day" : "Days")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text("Since \(incidentLabel)")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Incident date display
            if let incidentDate = widget.configuration?.incidentDate {
                Text("Last: \(incidentDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("Set incident date")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.green.opacity(0.3), Color.mint.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - ✨ NEW: We're Hiring Badge Widget
struct HiringBadgeWidgetView: View {
    let widget: Widget
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Animated icon with pulsing effect
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .scaleEffect(1 + sin(animationPhase) * 0.1)
                
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animationPhase = .pi * 2
                }
            }
            
            // Main message
            Text("WE'RE HIRING!")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            // Subtitle
            Text("Join Our Team")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            
            Spacer()
            
            // Professional badge
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                Text("Now Accepting Applications")
                    .font(.caption)
                Image(systemName: "sparkles")
                    .font(.caption)
            }
            .foregroundColor(.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.2))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            LinearGradient(
                colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Placeholder Widget (for unimplemented types)
struct PlaceholderWidgetView: View {
    let widget: Widget
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: widget.type.icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(widget.type.displayName)
                .font(.title3)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - Widget Factory
/// Returns the appropriate view for each widget type
@ViewBuilder
func createWidgetView(for widget: Widget) -> some View {
    switch widget.type {
    case .companyLogo:
        LogoWidgetView(widget: widget)
        
    case .customerCount:
        CustomerCounterWidgetView(widget: widget)
        
    case .instagramFollowers:
        InstagramFollowersWidgetView(widget: widget)
        
    case .locationsMap:
        LocationMapWidgetView(widget: widget)
        
    case .yearsInBusiness:
        YearsInBusinessWidgetView(widget: widget)
        
    case .daysSinceIncident:
        DaysSinceIncidentWidgetView(widget: widget)
        
    case .hiringBadge:
        HiringBadgeWidgetView(widget: widget)
        
    // TODO: Implement remaining widgets
    default:
        PlaceholderWidgetView(widget: widget)
    }
}

// MARK: - Widget Container (Common styling)
struct WidgetContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color.black.opacity(0.2))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
