#if os(iOS)
import SwiftUI
import SwiftData

struct PhotoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var photo: AlbumPhoto

    @FocusState private var isCaptionFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let imageData = photo.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Caption")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    TextField("Add a caption for this photo", text: $photo.caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .focused($isCaptionFocused)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text("Uploaded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(photo.uploadDate, style: .date)
                            .font(.subheadline)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(photo.uploadDate, style: .time)
                            .font(.subheadline)
                    }

                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.secondary)
                        Text("Display Order")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(photo.displayOrder)")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Edit Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PhotoEditView(photo: AlbumPhoto(
            imageData: nil,
            caption: "Sample caption",
            displayOrder: 0
        ))
    }
    .modelContainer(for: AlbumPhoto.self, inMemory: true)
}
#endif
