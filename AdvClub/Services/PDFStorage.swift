//
//  PDFStorage.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import Foundation
import UniformTypeIdentifiers

enum PDFStorageError: LocalizedError {
    case invalidPDF
    case copyFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "The selected file is not a valid PDF."
        case .copyFailed:
            return "The PDF could not be copied into app storage."
        case .fileNotFound:
            return "The requested PDF file could not be found."
        }
    }
}

enum PDFStorage {
    private static let folderName = "PDFLibrary"

    static func storageDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folder = appSupport.appendingPathComponent(folderName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        return folder
    }

    static func saveImportedPDF(from sourceURL: URL) throws -> String {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let values = try sourceURL.resourceValues(forKeys: [.contentTypeKey])
        if let contentType = values.contentType {
            guard contentType.conforms(to: .pdf) else {
                throw PDFStorageError.invalidPDF
            }
        } else if sourceURL.pathExtension.lowercased() != "pdf" {
            throw PDFStorageError.invalidPDF
        }

        let destinationFolder = try storageDirectory()
        let storedFilename = "\(UUID().uuidString).pdf"
        let destinationURL = destinationFolder.appendingPathComponent(storedFilename)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return storedFilename
        } catch {
            throw PDFStorageError.copyFailed
        }
    }

    static func replacePDF(from sourceURL: URL, existingStoredFilename: String) throws -> String {
        let newStoredFilename = try saveImportedPDF(from: sourceURL)

        do {
            try deleteFile(named: existingStoredFilename)
        } catch {
            // Keep the newly imported file even if old delete fails.
        }

        return newStoredFilename
    }

    static func fileURL(for storedFilename: String) throws -> URL {
        let url = try storageDirectory().appendingPathComponent(storedFilename)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFStorageError.fileNotFound
        }

        return url
    }

    static func deleteFile(named storedFilename: String) throws {
        let url = try storageDirectory().appendingPathComponent(storedFilename)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
