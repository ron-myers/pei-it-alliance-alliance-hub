//
//  WidgetManagementView.swift
//  bragboard
//
//  iOS interface for managing widgets
//

#if os(iOS)
import SwiftUI
import SwiftData
import PhotosUI

struct WidgetManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Widget.position) private var widgets: [Widget]
    @State private var showingAddWidget = false
    
    var body: some View {
        NavigationStack {
            List {
                // Group by category
                ForEach(WidgetCategory.allCases, id: \.self) { category in
                    let categoryWidgets = widgets.filter { $0.type.category == category }
                    
                    if !categoryWidgets.isEmpty {
                        Section(category.rawValue) {
                            ForEach(categoryWidgets) { widget in
                                NavigationLink {
                                    WidgetConfigView(widget: widget)
                                } label: {
                                    WidgetRowView(widget: widget)
                                }
                            }
                            .onDelete { indexSet in
                                deleteWidgets(categoryWidgets: categoryWidgets, at: indexSet)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Widgets")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWidget = true
                    } label: {
                        Label("Add Widget", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWidget) {
                AddWidgetView()
            }
            .overlay {
                if widgets.isEmpty {
                    ContentUnavailableView(
                        "No Widgets",
                        systemImage: "rectangle.3.group",
                        description: Text("Add your first widget to get started")
                    )
                }
            }
        }
    }
    
    private func deleteWidgets(categoryWidgets: [Widget], at offsets: IndexSet) {
        for index in offsets {
            let widget = categoryWidgets[index]
            modelContext.delete(widget)
        }
    }
}

// MARK: - Widget Row
struct WidgetRowView: View {
    @Bindable var widget: Widget
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: widget.type.icon)
                .font(.title2)
                .foregroundColor(widget.isEnabled ? .blue : .gray)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(widget.type.displayName)
                    .font(.headline)
                
                HStack {
                    Text(widget.type.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !widget.type.isImplemented {
                        Text("• Coming Soon")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if widget.type.isImplemented && (widget.type == .instagramFollowers || widget.type == .locationsMap) {
                        Text("• Sample Data")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $widget.isEnabled)
                .labelsHidden()
        }
    }
}

// MARK: - Add Widget Sheet
struct AddWidgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingWidgets: [Widget]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(WidgetCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(widgetTypes(for: category), id: \.self) { type in
                            Button {
                                addWidget(type: type)
                            } label: {
                                HStack {
                                    Image(systemName: type.icon)
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .frame(width: 40)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(type.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        if !type.isImplemented {
                                            Text("Coming Soon")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        } else if type == .instagramFollowers || type == .locationsMap {
                                            Text("Sample Data")
                                                .font(.caption)
                                                .foregroundColor(.yellow)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if widgetExists(type) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .disabled(widgetExists(type))
                        }
                    }
                }
            }
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func widgetTypes(for category: WidgetCategory) -> [WidgetType] {
        WidgetType.allCases.filter { $0.category == category }
    }
    
    private func widgetExists(_ type: WidgetType) -> Bool {
        existingWidgets.contains { $0.type == type }
    }
    
    private func addWidget(type: WidgetType) {
        let newWidget = Widget(type: type, position: existingWidgets.count)
        let config = WidgetConfiguration()
        
        // Set default values based on type
        switch type {
        case .customerCount:
            config.counterValue = 0
            config.counterLabel = "Customers Served"
        case .instagramFollowers:
            config.counterValue = MockDataService.shared.getInstagramFollowers()
        case .locationsMap:
            config.locationNames = MockDataService.shared.getLocationNames()
            config.locationCount = MockDataService.shared.getLocationCount()
        case .yearsInBusiness:
            config.startDate = Date()
        case .daysSinceIncident:
            config.incidentDate = Date()
            config.incidentLabel = "Last Incident"
        default:
            break
        }
        
        newWidget.configuration = config
        modelContext.insert(newWidget)
        
        dismiss()
    }
}

// MARK: - Widget Configuration View
struct WidgetConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var widget: Widget
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        Form {
            Section("Display") {
                Toggle("Enabled", isOn: $widget.isEnabled)
                
                if !widget.type.isImplemented {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("This widget is not yet implemented")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Type-specific configuration
            configurationSection
            
            // Delete section
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Delete Widget", systemImage: "trash")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(widget.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Widget?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(widget)
                dismiss()
            }
        } message: {
            Text("This will remove the \(widget.type.displayName) widget from your dashboard.")
        }
    }
    
    @ViewBuilder
    private var configurationSection: some View {
        switch widget.type {
        case .companyLogo:
            logoConfiguration
            
        case .customerCount:
            counterConfiguration
            
        case .instagramFollowers:
            socialMediaConfiguration
            
        case .locationsMap:
            locationConfiguration
            
        case .yearsInBusiness:
            yearsInBusinessConfiguration
            
        case .daysSinceIncident:
            daysSinceIncidentConfiguration
            
        default:
            Section("Configuration") {
                Text("Configuration options coming soon")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var logoConfiguration: some View {
        Section("Logo Image") {
            if let imageData = widget.configuration?.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Select Logo", systemImage: "photo")
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        if widget.configuration == nil {
                            widget.configuration = WidgetConfiguration()
                        }
                        widget.configuration?.imageData = data
                    }
                }
            }
        }
    }
    
    private var counterConfiguration: some View {
        Section("Counter Settings") {
            // Editable label
            HStack {
                Text("Label")
                Spacer()
                TextField("e.g. Customers Served", text: Binding(
                    get: { widget.configuration?.counterLabel ?? "Customers Served" },
                    set: { newValue in
                        ensureConfiguration()
                        widget.configuration?.counterLabel = newValue
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .multilineTextAlignment(.trailing)
            }
            
            // Quick label suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Labels")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["Customers Served", "Dogs Saved", "Cars Sold", "Happy Clients", "Projects Completed", "Members"], id: \.self) { suggestion in
                            Button(suggestion) {
                                ensureConfiguration()
                                widget.configuration?.counterLabel = suggestion
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                }
            }
            
            Divider()
            
            // Counter value
            VStack(alignment: .leading, spacing: 8) {
                Text("Count: \(widget.configuration?.counterValue ?? 0)")
                    .font(.headline)
                
                Stepper("Adjust",
                        value: Binding(
                            get: { widget.configuration?.counterValue ?? 0 },
                            set: { newValue in
                                ensureConfiguration()
                                widget.configuration?.counterValue = newValue
                            }
                        ),
                        in: 0...9_999_999,
                        step: 1)
                
                // Quick increment buttons
                HStack(spacing: 12) {
                    Button("+1") { incrementCounter(by: 1) }
                    Button("+10") { incrementCounter(by: 10) }
                    Button("+100") { incrementCounter(by: 100) }
                    Button("+1000") { incrementCounter(by: 1000) }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }
    
    private func ensureConfiguration() {
        if widget.configuration == nil {
            widget.configuration = WidgetConfiguration()
        }
    }
    
    private func incrementCounter(by amount: Int) {
        ensureConfiguration()
        widget.configuration?.counterValue = (widget.configuration?.counterValue ?? 0) + amount
    }
    
    private var socialMediaConfiguration: some View {
        Section("Instagram") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.yellow)
                Text("Showing sample data. Connect Instagram API when ready.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Current Count: \(MockDataService.formatNumber(widget.configuration?.counterValue ?? 0))")
                .font(.headline)
        }
    }
    
    private var locationConfiguration: some View {
        Section("Locations") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.yellow)
                Text("Showing sample data. Add real locations when ready.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(widget.configuration?.locationNames ?? [], id: \.self) { location in
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.green)
                    Text(location)
                }
            }
        }
    }
    
    private var yearsInBusinessConfiguration: some View {
        Section("Business Start Date") {
            DatePicker(
                "Founded",
                selection: Binding(
                    get: { widget.configuration?.startDate ?? Date() },
                    set: { newValue in
                        ensureConfiguration()
                        widget.configuration?.startDate = newValue
                    }
                ),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            
            if let startDate = widget.configuration?.startDate {
                let years = Calendar.current.dateComponents([.year], from: startDate, to: Date()).year ?? 0
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(max(0, years))")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text(years == 1 ? "Year" : "Years")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Since \(startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var daysSinceIncidentConfiguration: some View {
        Group {
            Section("Incident Label") {
                TextField("e.g. Last Workplace Accident", text: Binding(
                    get: { widget.configuration?.incidentLabel ?? "Last Incident" },
                    set: { newValue in
                        ensureConfiguration()
                        widget.configuration?.incidentLabel = newValue
                    }
                ))
                .textFieldStyle(.roundedBorder)
                
                // Quick label suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Labels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Last Workplace Accident", "Last Safety Incident", "Last Customer Complaint", "Last Downtime", "Last Error"], id: \.self) { suggestion in
                                Button(suggestion) {
                                    ensureConfiguration()
                                    widget.configuration?.incidentLabel = suggestion
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            
            Section("Last Incident Date") {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { widget.configuration?.incidentDate ?? Date() },
                        set: { newValue in
                            ensureConfiguration()
                            widget.configuration?.incidentDate = newValue
                        }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                
                if let incidentDate = widget.configuration?.incidentDate {
                    let days = Calendar.current.dateComponents([.day], from: incidentDate, to: Date()).day ?? 0
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(max(0, days))")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                            Text(days == 1 ? "Day" : "Days")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Since \(widget.configuration?.incidentLabel ?? "Last Incident")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
}

#Preview {
    WidgetManagementView()
        .modelContainer(for: Widget.self, inMemory: true)
}
#endif
