//
//  WidgetManagementView.swift
//  bragboard
//
//  iOS interface for managing widgets
//  ✨ UPDATED: Added 2x room status widget with validation
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
                HStack {
                    Text(widget.type.displayName)
                        .font(.headline)
                    
                    // ✨ NEW: 2x badge
                    if widget.is2x {
                        Text("2×")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Text(widget.type.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !widget.type.isImplemented {
                        Text("• Coming Soon")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if widget.type.isImplemented && widget.type == .locationsMap {
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
                                        } else if type == .locationsMap {
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
        case .roomStatus:
            config.showRoomNumber = false
            config.showFloor = false
            config.showCapacity = false
            config.showCurrentBooking = false
            config.showNextBooking = false
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
    
    // ✨ NEW: 2x validation alert
    @State private var showingCapacityAlert = false
    @Query private var allWidgets: [Widget]
    
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
        // ✨ NEW: Capacity alert for 2x toggle
        .alert("Dashboard Full", isPresented: $showingCapacityAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need 5 or fewer widgets to enable 2× mode. The dashboard can hold a maximum of 6 widget slots (3 columns × 2 rows), and a 2× widget occupies 2 vertical slots.")
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
        
        case .roomStatus:
            roomStatusConfiguration

        case .countriesServed:
            countriesServedConfiguration

        default:
            Section("Configuration") {
                Text("Configuration options coming soon")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // ✨ NEW: Helper to calculate total slots used
    private func calculateTotalSlots() -> Int {
        return allWidgets.reduce(0) { total, widget in
            total + (widget.is2x ? 2 : 1)
        }
    }
    
    // ✨ NEW: Helper to validate 2x toggle
    private func canToggleTo2x() -> Bool {
        // Calculate slots if this widget becomes 2x
        let currentSlot = widget.is2x ? 2 : 1
        let futureSlot = 2
        let otherSlots = allWidgets.filter { $0.id != widget.id }.reduce(0) { $0 + ($1.is2x ? 2 : 1) }
        let totalSlots = otherSlots + futureSlot
        
        return totalSlots <= 6
    }
    
    // ✨ NEW: Helper to ensure configuration exists
    private func ensureConfiguration() {
        if widget.configuration == nil {
            widget.configuration = WidgetConfiguration()
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
                    get: { widget.configuration?.counterLabel ?? "" },
                    set: { newValue in
                        ensureConfiguration()
                        widget.configuration?.counterLabel = newValue
                    }
                ))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
            }
            
            // Counter value
            HStack {
                Text("Count")
                Spacer()
                TextField("0", value: Binding(
                    get: { widget.configuration?.counterValue ?? 0 },
                    set: { newValue in
                        ensureConfiguration()
                        widget.configuration?.counterValue = max(0, newValue)
                    }
                ), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            }
        }
    }
    
    private var socialMediaConfiguration: some View {
        Section("Instagram Account") {
            // Username field
            HStack {
                Text("Username")
                Spacer()
                TextField("username", text: Binding(
                    get: { widget.configuration?.instagramUsername ?? "" },
                    set: { newValue in
                        ensureConfiguration()
                        // Remove @ if user includes it
                        widget.configuration?.instagramUsername = newValue.replacingOccurrences(of: "@", with: "")
                    }
                ))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            }

            // Follower count field
            HStack {
                Text("Followers")
                Spacer()
                TextField("0", value: Binding(
                    get: { widget.configuration?.instagramFollowerCount ?? 0 },
                    set: { newValue in
                        ensureConfiguration()
                        widget.configuration?.instagramFollowerCount = max(0, newValue)
                    }
                ), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            }

            // Helper text
            Text("Enter your Instagram username (without @) and current follower count")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var locationConfiguration: some View {
        Section("Location Settings") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.yellow)
                Text("This displays sample data. Real location data coming soon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var yearsInBusinessConfiguration: some View {
        Group {
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
            }
            
            // ✨ NEW: Display Format Picker
            Section("Display Format") {
                Picker("Time Unit", selection: Binding(
                    get: { widget.configuration?.timeDisplayFormat ?? .years },
                    set: { newValue in
                        ensureConfiguration()
                        widget.configuration?.timeDisplayFormat = newValue
                    }
                )) {
                    ForEach(TimeDisplayFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("Choose how to display the time since your business started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // ✨ UPDATED: Dynamic preview based on selected format
            if let startDate = widget.configuration?.startDate {
                Section("Preview") {
                    let format = widget.configuration?.timeDisplayFormat ?? .years
                    let calendar = Calendar.current
                    
                    let displayValue: String = {
                        switch format {
                        case .years:
                            let years = calendar.dateComponents([.year], from: startDate, to: Date()).year ?? 0
                            return "\(max(0, years))"
                        case .months:
                            let months = calendar.dateComponents([.month], from: startDate, to: Date()).month ?? 0
                            return "\(max(0, months))"
                        case .days:
                            let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
                            return "\(max(0, days))"
                        case .monthsAndDays:
                            let components = calendar.dateComponents([.month, .day], from: startDate, to: Date())
                            let months = components.month ?? 0
                            let days = components.day ?? 0
                            return "\(max(0, months))m \(max(0, days))d"
                        }
                    }()
                    
                    let displayUnit: String = {
                        switch format {
                        case .years:
                            let years = calendar.dateComponents([.year], from: startDate, to: Date()).year ?? 0
                            return years == 1 ? "Year" : "Years"
                        case .months:
                            let months = calendar.dateComponents([.month], from: startDate, to: Date()).month ?? 0
                            return months == 1 ? "Month" : "Months"
                        case .days:
                            let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
                            return days == 1 ? "Day" : "Days"
                        case .monthsAndDays:
                            return ""
                        }
                    }()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(displayValue)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                            if !displayUnit.isEmpty {
                                Text(displayUnit)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(format.unitLabel)
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
    }
    
    private var daysSinceIncidentConfiguration: some View {
        Group {
            Section("Incident Label") {
                TextField(
                    "Label",
                    text: Binding(
                        get: { widget.configuration?.incidentLabel ?? "Last Incident" },
                        set: { newValue in
                            ensureConfiguration()
                            widget.configuration?.incidentLabel = newValue
                        }
                    )
                )
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
    
    private var roomStatusConfiguration: some View {
        Group {
            // ✨ NEW: Widget Size Section
            Section("Widget Size") {
                Toggle(isOn: Binding(
                    get: { widget.is2x },
                    set: { newValue in
                        if newValue && !canToggleTo2x() {
                            // Show alert if can't enable 2x
                            showingCapacityAlert = true
                        } else {
                            widget.is2x = newValue
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expanded View (2×)")
                            .font(.body)
                        Text("Shows all rooms (202A-202D) vertically with status and current bookings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Current capacity info
                let currentSlots = calculateTotalSlots()
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(currentSlots <= 5 ? .blue : .orange)
                    Text("Dashboard capacity: \(currentSlots)/6 slots used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if widget.is2x {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.orange)
                        Text("This widget takes 2 vertical slots")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Section("Display Options") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text(widget.is2x ? "In 2× mode, all rooms are displayed with their status and current bookings." : "In compact mode, one room is shown at a time with automatic cycling.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Hide individual toggles in 2x mode since it shows everything
            if !widget.is2x {
                Section("Basic Information") {
                    Toggle("Show Room Number", isOn: Binding(
                        get: { widget.configuration?.showRoomNumber ?? false },
                        set: { newValue in
                            ensureConfiguration()
                            widget.configuration?.showRoomNumber = newValue
                        }
                    ))
                    
                    Toggle("Show Floor", isOn: Binding(
                        get: { widget.configuration?.showFloor ?? false },
                        set: { newValue in
                            ensureConfiguration()
                            widget.configuration?.showFloor = newValue
                        }
                    ))
                    
                    Toggle("Show Capacity", isOn: Binding(
                        get: { widget.configuration?.showCapacity ?? false },
                        set: { newValue in
                            ensureConfiguration()
                            widget.configuration?.showCapacity = newValue
                        }
                    ))
                }
                
                Section("Booking Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show Current Booking", isOn: Binding(
                            get: { widget.configuration?.showCurrentBooking ?? false },
                            set: { newValue in
                                ensureConfiguration()
                                widget.configuration?.showCurrentBooking = newValue
                            }
                        ))
                        
                        Text("Displays details of the current booking (if any)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show Next Booking", isOn: Binding(
                            get: { widget.configuration?.showNextBooking ?? false },
                            set: { newValue in
                                ensureConfiguration()
                                widget.configuration?.showNextBooking = newValue
                            }
                        ))
                        
                        Text("Displays upcoming booking information")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                    }
                }
            }
            
            Section("Data Source") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "network")
                        .foregroundColor(.green)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("The Foundry Room Hub API")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("https://thefoundryroomhub.ca/RoomStatusAPI")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("Live data • Updates automatically")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var countriesServedConfiguration: some View {
        Group {
            Section("Countries Selection") {
                NavigationLink {
                    CountrySelectionView(widget: widget)
                } label: {
                    HStack {
                        Image(systemName: "globe.americas.fill")
                            .foregroundColor(.blue)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Countries")
                                .font(.body)

                            let count = widget.configuration?.countriesServed.count ?? 1
                            Text("\(count) \(count == 1 ? "country" : "countries") selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section("Default Location") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Charlottetown, PEI, Canada")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Default location is always marked on the map")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Display") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("On Apple TV, selected countries will be displayed on a world map. The map shows all selected countries with markers indicating your service areas.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
