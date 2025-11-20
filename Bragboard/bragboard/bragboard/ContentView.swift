//
//  ContentView_Updated.swift
//  bragboard
//
//  Updated iOS interface with widget management
//  Replace your existing ContentView.swift with this file
//

#if os(iOS)
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            // Widgets tab
            WidgetManagementView()
                .tabItem {
                    Label("Widgets", systemImage: "rectangle.3.group")
                }
            
            // Legacy photos tab (for existing logo uploads)
            LegacyPhotosView()
                .tabItem {
                    Label("Photos", systemImage: "photo")
                }
        }
    }
}

// MARK: - Legacy Photos View (for existing functionality)
struct LegacyPhotosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.stack",
                        description: Text("Add photos to migrate them to the new widget system")
                    )
                } else {
                    List {
                        Section {
                            Button {
                                migratePhotosToWidgets()
                            } label: {
                                Label("Migrate to Logo Widget", systemImage: "arrow.right.circle")
                                    .foregroundColor(.blue)
                            }
                        } header: {
                            Text("Migration")
                        } footer: {
                            Text("Convert your existing photos to Logo widgets in the new system")
                        }
                        
                        Section("Existing Photos") {
                            ForEach(items) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    HStack(spacing: 12) {
                                        if let imageData = item.imageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title.isEmpty ? "Untitled" : item.title)
                                                .font(.headline)
                                            Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                }
            }
            .navigationTitle("Legacy Photos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Photo", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                // Keep your existing AddPhotoView here
                Text("Use existing AddPhotoView from ContentView.swift")
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
    
    private func migratePhotosToWidgets() {
        // Get existing widgets
        let descriptor = FetchDescriptor<Widget>()
        let existingWidgets = (try? modelContext.fetch(descriptor)) ?? []
        
        // Check if logo widget already exists
        if !existingWidgets.contains(where: { $0.type == .companyLogo }) {
            // Create logo widget from first photo
            if let firstPhoto = items.first {
                let logoWidget = Widget(type: .companyLogo, position: 0)
                let config = WidgetConfiguration()
                config.imageData = firstPhoto.imageData
                logoWidget.configuration = config
                modelContext.insert(logoWidget)
                
                // Show success message
                print("✅ Migrated photo to logo widget")
            }
        }
    }
}

// Keep your existing ItemDetailView here
struct ItemDetailView: View {
    let item: Item
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if !item.title.isEmpty {
                        Text(item.title)
                            .font(.title2)
                            .bold()
                    }
                    
                    Text("Added: \(item.timestamp.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(item.title.isEmpty ? "Photo" : item.title)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Widget.self], inMemory: true)
}
#endif
