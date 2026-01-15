import Foundation
import SwiftData

@Model
final class AlbumPhoto {
    var id: UUID = UUID()
    var imageData: Data?
    var caption: String = ""
    var uploadDate: Date = Date()
    var displayOrder: Int = 0

    init(id: UUID = UUID(), imageData: Data? = nil, caption: String = "", displayOrder: Int = 0) {
        self.id = id
        self.imageData = imageData
        self.caption = caption
        self.uploadDate = Date()
        self.displayOrder = displayOrder
    }
}
