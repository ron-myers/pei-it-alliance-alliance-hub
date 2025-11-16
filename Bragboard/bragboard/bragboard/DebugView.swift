//
//  DebugView.swift
//  bragboard
//
//  Debug view to see what SwiftData is seeing
//
#if os(tvOS)
import SwiftUI
import SwiftData

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @State private var debugInfo: [String] = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("SwiftData Debug Info")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Items Count: \(items.count)")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        Divider().background(Color.white)
                        
                        if items.isEmpty {
                            Text("No items found in SwiftData @Query")
                                .foregroundColor(.red)
                                .font(.title3)
                        } else {
                            Text("Items from @Query:")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(index + 1). \(item.title.isEmpty ? "Untitled" : item.title)")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Text("   Date: \(item.timestamp.formatted())")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("   Has image: \(item.imageData != nil ? "Yes (\(item.imageData?.count ?? 0) bytes)" : "No")")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        
                        Divider().background(Color.white)
                        
                        Text("Debug Actions:")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.top)
                        
                        Button("Force Refresh Query") {
                            // This forces SwiftData to re-fetch
                            do {
                                try modelContext.save()
                                debugInfo.append("Saved context - query should refresh")
                            } catch {
                                debugInfo.append("Error: \(error)")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Print All Items to Console") {
                            print("🔍 DEBUG: Total items in @Query: \(items.count)")
                            for (index, item) in items.enumerated() {
                                print("🔍 Item \(index + 1):")
                                print("   Title: \(item.title)")
                                print("   Timestamp: \(item.timestamp)")
                                print("   Has image: \(item.imageData != nil)")
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        if !debugInfo.isEmpty {
                            Divider().background(Color.white)
                            Text("Debug Log:")
                                .font(.title3)
                                .foregroundColor(.white)
                            ForEach(debugInfo, id: \.self) { info in
                                Text(info)
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            print("🔍 DebugView appeared")
            print("🔍 Items count from @Query: \(items.count)")
        }
    }
}

#Preview {
    DebugView()
        .modelContainer(for: Item.self)
}
#endif
