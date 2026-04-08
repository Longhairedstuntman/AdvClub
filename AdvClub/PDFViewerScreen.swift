//
//  PDFViewerScreen.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//
//

import SwiftUI

struct PDFViewerScreen: View {
    let document: PDFDocumentRecord
    @State private var fileURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let fileURL {
                PDFKitView(url: fileURL)
                    .ignoresSafeArea(edges: .bottom)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to Open PDF",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Loading PDF...")
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPDF()
        }
    }

    private func loadPDF() {
        do {
            fileURL = try PDFStorage.fileURL(for: document.storedFilename)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
