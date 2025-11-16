//
//  Item.swift
//  bragboard
//
//  Created by RH Lee on 30/10/2025.
//

import Foundation
import SwiftData
import UIKit

@Model
final class Item {
    var timestamp: Date = Date()
    var title: String = ""
    var imageData: Data?
    
    init(timestamp: Date = Date(), title: String = "", imageData: Data? = nil) {
        self.timestamp = timestamp
        self.title = title
        self.imageData = imageData
    }
    
    // Helper computed property to get UIImage from data
    var image: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
}
