//
//  WidgetViews.swift
//  bragboard
//
//  Reusable view components for each widget type
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
                        .frame(maxWidth: 600, maxHeight: 600)
                }
                #endif
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "building.2")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Add Company Logo")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
            }
        }
        .padding()
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
        VStack(spacing: 20) {
            // Counter value
            Text(MockDataService.formatNumber(
                widget.configuration?.counterValue ?? 0,
                style: .full
            ))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Custom label
            Text(label)
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
            
            // Decorative icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
        VStack(spacing: 20) {
            // Instagram icon (simulated)
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            // Follower count
            Text(MockDataService.formatNumber(followerCount))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Label
            Text("Instagram Followers")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            
            // Mock data badge
            Text("SAMPLE DATA")
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
        VStack(spacing: 24) {
            // Map icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            
            // Location count
            Text("\(locations.count)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Locations Worldwide")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
            
            // Location list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(locations, id: \.self) { location in
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.green)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(.top, 8)
            
            // Mock data badge
            Text("SAMPLE DATA")
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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

// MARK: - Placeholder Widget (for unimplemented types)
struct PlaceholderWidgetView: View {
    let widget: Widget
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: widget.type.icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(widget.type.displayName)
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Coming Soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            
            Text("TODO: Implement \(widget.type.category.rawValue) widget")
                .font(.caption)
                .foregroundColor(.yellow.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
