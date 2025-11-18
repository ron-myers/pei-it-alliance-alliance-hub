//
//  ContentView.swift
//  bragboard
//
//  Created by RH Lee on 30/10/2025.
//

#if os(iOS)
import SwiftUI
import SwiftData
import PhotosUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingAddSheet = false
    @State private var newItemTitle = ""
    @State private var selectedImageData: Data?

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        HStack(spacing: 12) {
                            // Thumbnail
                            if let imageData = item.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title.isEmpty ? "Untitled" : item.title)
                                    .font(.headline)
                                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Bragboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: DiagnosticsView()) {
                        Label("Diagnostics", systemImage: "stethoscope")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Photo", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddPhotoView(isPresented: $showingAddSheet)
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// Separate view for adding photos
struct AddPhotoView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var title = ""
    @State private var baseImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var filterPreviews: [FilterOption: UIImage] = [:]
    @State private var selectedFilter: FilterOption = .original
    @State private var isGeneratingPreviews = false
    
    private let ciContext = CIContext()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    VStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Group {
                                if let previewImage {
                                    Image(uiImage: previewImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .contentTransition(.opacity)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(maxWidth: .infinity, minHeight: 200)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo.on.rectangle")
                                                    .font(.system(size: 28, weight: .medium))
                                                    .foregroundColor(.gray)
                                                Text("Select Photo")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        if baseImage != nil {
                            FilterCarousel(
                                filterPreviews: filterPreviews,
                                selectedFilter: selectedFilter,
                                isGenerating: isGeneratingPreviews,
                                onSelect: { option in
                                    apply(filter: option)
                                }
                            )
                            .animation(.easeInOut(duration: 0.2), value: selectedFilter)
                        }
                    }
                }
                
                Section("Details") {
                    TextField("Title (optional)", text: $title)
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPhoto()
                    }
                    .disabled(selectedImageData == nil)
                }
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                guard let newValue else {
                    resetSelection()
                    return
                }
                
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            baseImage = uiImage
                            apply(filter: .original)
                            generateFilterPreviews(for: uiImage)
                        }
                    } else {
                        await MainActor.run {
                            resetSelection()
                        }
                    }
                }
            }
        }
    }
    
    private func apply(filter option: FilterOption) {
        guard let baseImage else { return }
        selectedFilter = option
        
        guard let renderedImage = FilterRenderer.render(image: baseImage, with: option, context: ciContext) else {
            previewImage = baseImage
            selectedImageData = baseImage.jpegData(compressionQuality: 0.9)
            return
        }
        
        previewImage = renderedImage
        selectedImageData = renderedImage.jpegData(compressionQuality: 0.9)
    }
    
    private func generateFilterPreviews(for image: UIImage) {
        filterPreviews = [:]
        isGeneratingPreviews = true
        let previewBase = image.preparingThumbnail(of: CGSize(width: 220, height: 220)) ?? image
        
        Task.detached(priority: .userInitiated) {
            let previewContext = CIContext()
            var previews: [FilterOption: UIImage] = [:]
            
            for option in FilterOption.allCases {
                if let preview = FilterRenderer.render(image: previewBase, with: option, context: previewContext) {
                    previews[option] = preview
                }
            }
            
            await MainActor.run {
                self.filterPreviews = previews
                self.isGeneratingPreviews = false
            }
        }
    }
    
    private func resetSelection() {
        baseImage = nil
        previewImage = nil
        selectedImageData = nil
        filterPreviews = [:]
        selectedFilter = .original
        isGeneratingPreviews = false
    }
    
    private func addPhoto() {
        guard let imageData = selectedImageData else { return }
        
        withAnimation {
            let newItem = Item(
                timestamp: Date(),
                title: title,
                imageData: imageData
            )
            modelContext.insert(newItem)
            print("📱 iPhone: Added new photo - '\(title.isEmpty ? "Untitled" : title)'")
            print("📱 iPhone: Image size: \(imageData.count / 1024)KB")
            
            // Force save to trigger CloudKit sync
            do {
                try modelContext.save()
                print("✅ iPhone: Saved to SwiftData successfully")
            } catch {
                print("❌ iPhone: Error saving: \(error)")
            }
        }
        
        isPresented = false
    }
}

private struct FilterCarousel: View {
    let filterPreviews: [FilterOption: UIImage]
    let selectedFilter: FilterOption
    let isGenerating: Bool
    let onSelect: (FilterOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Filters")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterOption.allCases) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            FilterPreviewTile(
                                option: option,
                                preview: filterPreviews[option],
                                isSelected: option == selectedFilter,
                                isGenerating: isGenerating && filterPreviews[option] == nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct FilterPreviewTile: View {
    let option: FilterOption
    let preview: UIImage?
    let isSelected: Bool
    let isGenerating: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 72, height: 72)
                        .overlay {
                            if isGenerating {
                                ProgressView()
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
                        }
                }
            }
            
            Text(option.displayName)
                .font(.caption2)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 72)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

private enum FilterOption: String, CaseIterable, Identifiable {
    case original
    case noir
    case instant
    case mono
    case fade
    case chrome
    case sepia
    case bloom
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .original: return "Original"
        case .noir: return "Noir"
        case .instant: return "Instant"
        case .mono: return "Mono"
        case .fade: return "Fade"
        case .chrome: return "Chrome"
        case .sepia: return "Sepia"
        case .bloom: return "Bloom"
        }
    }
}

private enum FilterRenderer {
    static func render(image: UIImage, with option: FilterOption, context: CIContext) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let output = option.outputImage(for: ciImage) ?? ciImage
        let cropped = output.cropped(to: ciImage.extent)
        
        guard let cgImage = context.createCGImage(cropped, from: cropped.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

private extension FilterOption {
    func outputImage(for input: CIImage) -> CIImage? {
        switch self {
        case .original:
            return input
        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = input
            return filter.outputImage
        case .instant:
            let filter = CIFilter.photoEffectInstant()
            filter.inputImage = input
            return filter.outputImage
        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = input
            return filter.outputImage
        case .fade:
            let filter = CIFilter.photoEffectFade()
            filter.inputImage = input
            return filter.outputImage
        case .chrome:
            let filter = CIFilter.photoEffectChrome()
            filter.inputImage = input
            return filter.outputImage
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.intensity = 0.85
            filter.inputImage = input
            return filter.outputImage
        case .bloom:
            let filter = CIFilter.bloom()
            filter.radius = 5
            filter.intensity = 0.8
            filter.inputImage = input
            return filter.outputImage
        }
    }
}

// Detail view for individual items
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
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if !item.title.isEmpty {
                        Text(item.title)
                            .font(.title2)
                            .bold()
                    }
                    
                    Text("Added: \(item.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(item.title.isEmpty ? "Photo" : item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
#endif
