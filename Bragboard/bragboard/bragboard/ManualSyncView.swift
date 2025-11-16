//
//  ManualSyncView.swift
//  bragboard
//
//  Manual CloudKit to SwiftData sync tool
//
#if os(tvOS)
import SwiftUI
import SwiftData
import CloudKit

struct ManualSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    
    @State private var syncLog: [String] = []
    @State private var isSyncing = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Manual CloudKit Sync")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current SwiftData Items: \(items.count)")
                            .font(.title2)
                            .foregroundColor(.yellow)
                        
                        Button("Fetch from CloudKit and Import") {
                            fetchAndImport()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSyncing)
                        
                        if isSyncing {
                            ProgressView("Syncing...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .foregroundColor(.white)
                        }
                        
                        Divider().background(Color.white)
                        
                        Text("Sync Log:")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        ForEach(syncLog, id: \.self) { log in
                            Text(log)
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func fetchAndImport() {
        isSyncing = true
        syncLog.removeAll()
        addLog("🔄 Starting manual sync...")
        
        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        
        addLog("📡 Fetching ALL records from CloudKit zone (full sync)...")
        
        // Create configuration WITHOUT previous change token to force full fetch
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = nil // Force full fetch from beginning!
        
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )
        
        var fetchedRecords: [CKRecord] = []
        
        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                if record.recordType == "CD_Item" {
                    DispatchQueue.main.async {
                        self.addLog("📥 Found: \(record["CD_title"] as? String ?? "Untitled")")
                    }
                    fetchedRecords.append(record)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.addLog("⚠️ Error fetching record: \(error.localizedDescription)")
                }
            }
        }
        
        operation.recordZoneFetchResultBlock = { zoneID, result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.addLog("✅ Fetched \(fetchedRecords.count) records from CloudKit")
                    if fetchedRecords.isEmpty {
                        self.addLog("⚠️ No records found! Trying alternate method...")
                        self.fetchUsingQuery()
                    } else {
                        self.importRecords(fetchedRecords)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.addLog("❌ Error: \(error.localizedDescription)")
                    
                    // If zone doesn't exist yet, try the old query method
                    if (error as NSError).code == CKError.zoneNotFound.rawValue {
                        self.addLog("⚠️ Zone not found, trying alternate method...")
                        self.fetchUsingQuery()
                    } else {
                        self.isSyncing = false
                    }
                }
            }
        }
        
        operation.fetchRecordZoneChangesResultBlock = { result in
            switch result {
            case .success:
                break // Already handled in recordZoneFetchResultBlock
            case .failure(let error):
                DispatchQueue.main.async {
                    self.addLog("❌ Overall fetch error: \(error.localizedDescription)")
                    self.addLog("🔄 Trying alternate query method...")
                    self.fetchUsingQuery()
                }
            }
        }
        
        database.add(operation)
    }
    
    // Fallback method using query
    private func fetchUsingQuery() {
        addLog("📡 Trying basic query method...")
        
        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        
        let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_timestamp", ascending: false)]
        
        database.perform(query, inZoneWith: zoneID) { records, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog("❌ Query error: \(error.localizedDescription)")
                    self.isSyncing = false
                    return
                }
                
                guard let records = records else {
                    self.addLog("❌ No records returned")
                    self.isSyncing = false
                    return
                }
                
                self.addLog("✅ Query fetched \(records.count) records")
                self.importRecords(records)
            }
        }
    }
    
    private func importRecords(_ records: [CKRecord]) {
        // Get existing item IDs to avoid duplicates
        let existingTitles = Set(items.map { $0.title })
        var importedCount = 0
        
        for record in records {
            // Extract data from CloudKit record
            guard let timestamp = record["CD_timestamp"] as? Date else {
                addLog("⚠️ Skipping record without timestamp")
                continue
            }
            
            let title = (record["CD_title"] as? String) ?? ""
            
            // Check if we already have this item (by title - not perfect but works)
            if existingTitles.contains(title) && !title.isEmpty {
                addLog("⏭️ Skipping duplicate: \(title.isEmpty ? "Untitled" : title)")
                continue
            }
            
            // Get image data if it exists
            var imageData: Data? = nil
            
            // Try to get as CKAsset first (preferred method)
            if let asset = record["CD_imageData_ckAsset"] as? CKAsset,
               let assetURL = asset.fileURL {
                imageData = try? Data(contentsOf: assetURL)
                addLog("📸 Loaded image asset for: \(title.isEmpty ? "Untitled" : title)")
            }
            // Fallback to bytes if no asset
            else if let bytes = record["CD_imageData"] as? Data {
                imageData = bytes
                addLog("📸 Loaded image bytes for: \(title.isEmpty ? "Untitled" : title)")
            }
            
            // Create new SwiftData item
            let newItem = Item(
                timestamp: timestamp,
                title: title,
                imageData: imageData
            )
            
            modelContext.insert(newItem)
            importedCount += 1
            addLog("✅ Imported: \(title.isEmpty ? "Untitled" : title)")
        }
        
        // Save to SwiftData
        if importedCount > 0 {
            do {
                try modelContext.save()
                addLog("💾 Saved \(importedCount) new items to SwiftData")
                addLog("🎉 Sync complete! Total items now: \(items.count + importedCount)")
            } catch {
                addLog("❌ Error saving: \(error.localizedDescription)")
            }
        } else {
            addLog("ℹ️ No new items to import")
            addLog("✅ Already up to date!")
        }
        
        isSyncing = false
    }
    
    private func addLog(_ message: String) {
        syncLog.append(message)
        print(message)
    }
}

#Preview {
    ManualSyncView()
        .modelContainer(for: Item.self)
}
#endif
