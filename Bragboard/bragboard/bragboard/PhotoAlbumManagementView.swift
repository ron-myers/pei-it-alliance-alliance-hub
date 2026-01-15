#if os(iOS)
import SwiftUI
import SwiftData
import PhotosUI

struct PhotoAlbumManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlbumPhoto.displayOrder) private var photos: [AlbumPhoto]

    @State private var showingPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    emptyStateView
                } else {
                    photosList
                }
            }
            .navigationTitle("Photo Album")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Add Photos", systemImage: "plus")
                    }
                }
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, newPhotos in
                addPhotos(newPhotos)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("No Photos Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add photos to display them on your Apple TV")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingPhotoPicker = true
            } label: {
                Label("Add Photos", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photosList: some View {
        List {
            ForEach(photos) { photo in
                NavigationLink {
                    PhotoEditView(photo: photo)
                } label: {
                    PhotoRowView(photo: photo)
                }
            }
            .onDelete(perform: deletePhotos)
        }
    }

    private func addPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let photo = AlbumPhoto(
                        imageData: data,
                        displayOrder: photos.count
                    )
                    modelContext.insert(photo)
                }
            }
            selectedPhotos = []
        }
    }

    private func deletePhotos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(photos[index])
        }
    }
}

struct PhotoRowView: View {
    let photo: AlbumPhoto

    var body: some View {
        HStack(spacing: 16) {
            if let imageData = photo.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                if !photo.caption.isEmpty {
                    Text(photo.caption)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text("No caption")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Text(photo.uploadDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PhotoAlbumManagementView()
        .modelContainer(for: AlbumPhoto.self, inMemory: true)
}
#endif
