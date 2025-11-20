//
//  bragboardApp_Updated.swift
//  bragboard
//
//  Updated app file with Widget support
//  Replace your existing bragboardApp.swift with this file
//

import SwiftUI
import SwiftData

@main
struct bragboardApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,           // Legacy photo model
            Widget.self,         // New widget model
            WidgetConfiguration.self  // Widget config model
        ])
        
        // Try CloudKit first
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudKitConfig])
            print("✅ ModelContainer created successfully with CloudKit")
            print("📦 Models: Item, Widget, WidgetConfiguration")
            print("☁️ CloudKit database: \(cloudKitConfig.cloudKitDatabase)")
            print("💾 Storage: \(cloudKitConfig.url)")
            return container
        } catch {
            print("⚠️ CloudKit ModelContainer failed: \(error)")
            print("⚠️ Error details: \(error.localizedDescription)")
            print("🔄 Trying fallback: Local storage only...")
            
            // Fallback: Try without CloudKit
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none  // Disable CloudKit
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                print("✅ ModelContainer created with LOCAL storage only")
                print("⚠️ CloudKit sync is DISABLED - data won't sync between devices")
                print("💾 Storage: \(localConfig.url)")
                return container
            } catch {
                print("❌ Even local storage failed: \(error)")
                fatalError("Could not create ModelContainer even without CloudKit: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
#if os(tvOS)
            TVDashboardView()
#elseif os(iOS)
            ContentView()
#endif
        }
        .modelContainer(sharedModelContainer)
    }
}
