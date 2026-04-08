//
//  PDFDocumentRecord.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import Foundation
import SwiftData

enum MediaType: String, Codable {
    case pdf
    case video
}

@Model
final class PDFDocumentRecord {
    var id: UUID = UUID()
    var title: String = ""
    var storedFilename: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortOrder: Int = 0
    var mediaTypeRawValue: String = MediaType.pdf.rawValue

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRawValue) ?? .pdf }
        set { mediaTypeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        storedFilename: String,
        sortOrder: Int,
        mediaType: MediaType = .pdf,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.storedFilename = storedFilename
        self.sortOrder = sortOrder
        self.mediaTypeRawValue = mediaType.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
