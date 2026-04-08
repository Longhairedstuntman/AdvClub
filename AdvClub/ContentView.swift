//
//  ContentView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    @Query(sort: \PDFDocumentRecord.sortOrder, order: .forward)
    private var documents: [PDFDocumentRecord]

    @StateObject private var securityManager = AdminSecurityManager()

    @State private var showingImporter = false
    @State private var pendingImportURL: URL?
    @State private var pendingTitle = ""
    @State private var showingTitlePrompt = false
    @State private var errorMessage: String?

    @State private var showingPINPrompt = false
    @State private var pendingAdminAction: AdminAction?

    @State private var documentToRename: PDFDocumentRecord?
    @State private var renameTitle = ""

    @State private var documentToReplace: PDFDocumentRecord?

    @State private var documentToDelete: PDFDocumentRecord?
    @State private var showingDeleteConfirmation = false

    enum AdminAction {
        case importPDF
        case enterEditMode
        case rename(PDFDocumentRecord)
        case replace(PDFDocumentRecord)
        case delete(PDFDocumentRecord)
    }

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "No Files Yet",
                        systemImage: "doc.text",
                        description: Text("Tap Import PDF to add your first document.")
                    )
                } else {
                    List {
                        ForEach(documents) { document in
                            NavigationLink {
                                PDFViewerScreen(document: document)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(document.title)
                                        .font(.headline)

                                    Text("Updated \(document.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .contextMenu {
                                Button("Rename") {
                                    requestAdminAccess(for: .rename(document))
                                }

                                Button("Replace PDF") {
                                    requestAdminAccess(for: .replace(document))
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if securityManager.isUnlocked && editMode?.wrappedValue == .active {
                                    Button(role: .destructive) {
                                        documentToDelete = document
                                        showingDeleteConfirmation = true
                                        securityManager.extendUnlockWindow()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .onMove(perform: moveDocuments)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("How-To Adventure")
            .background {
                Image("appBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.12)
            }
            .onAppear {
                securityManager.refreshUnlockState()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        if editMode?.wrappedValue == .active {
                            editMode?.wrappedValue = .inactive
                        } else {
                            requestAdminAccess(for: .enterEditMode)
                        }
                    } label: {
                        Text(editMode?.wrappedValue == .active ? "Done" : "Edit")
                    }

                    if securityManager.isUnlocked {
                        Button("Lock") {
                            securityManager.lock()
                            editMode?.wrappedValue = .inactive
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        requestAdminAccess(for: .importPDF)
                    } label: {
                        Label("Import PDF", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Name This PDF", isPresented: $showingTitlePrompt) {
                TextField("Display name", text: $pendingTitle)

                Button("Save") {
                    savePendingImport()
                }
                .disabled(
                    pendingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    pendingImportURL == nil
                )

                Button("Cancel", role: .cancel) {
                    pendingImportURL = nil
                    pendingTitle = ""
                }
            } message: {
                Text("Choose the name users will see in the list.")
            }
            .alert("Rename PDF", isPresented: Binding(
                get: { documentToRename != nil },
                set: { isPresented in
                    if !isPresented {
                        documentToRename = nil
                        renameTitle = ""
                    }
                }
            )) {
                TextField("Display name", text: $renameTitle)

                Button("Save") {
                    saveRename()
                }

                Button("Cancel", role: .cancel) {
                    documentToRename = nil
                    renameTitle = ""
                }
            } message: {
                Text("Enter the new name for this PDF.")
            }
            .confirmationDialog(
                "Delete PDF?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    confirmDelete()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the PDF from the app.")
            }
            .sheet(isPresented: $showingPINPrompt) {
                AdminPinPromptView(securityManager: securityManager) {
                    performPendingAdminAction()
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error.")
            }
        }
    }
    
    private func moveDocuments(from source: IndexSet, to destination: Int) {
        securityManager.refreshUnlockState()

        guard securityManager.isUnlocked else {
            editMode?.wrappedValue = .inactive
            errorMessage = "Admin access timed out. Please enter the PIN again."
            return
        }

        var reordered = documents
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, document) in reordered.enumerated() {
            document.sortOrder = index
            document.updatedAt = Date()
        }

        do {
            try modelContext.save()
            securityManager.extendUnlockWindow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestAdminAccess(for action: AdminAction) {
        securityManager.refreshUnlockState()
        pendingAdminAction = action

        if securityManager.isUnlocked {
            securityManager.extendUnlockWindow()
            performPendingAdminAction()
        } else {
            showingPINPrompt = true
        }
    }

    private func performPendingAdminAction() {
        guard let action = pendingAdminAction else { return }
        pendingAdminAction = nil

        switch action {
        case .importPDF:
            showingImporter = true

        case .enterEditMode:
            editMode?.wrappedValue = .active
            securityManager.extendUnlockWindow()

        case .rename(let document):
            documentToRename = document
            renameTitle = document.title

        case .replace(let document):
            documentToReplace = document
            showingImporter = true

        case .delete(let document):
            documentToDelete = document
            showingDeleteConfirmation = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let firstURL = urls.first else { return }

            if let documentToReplace {
                replacePDF(documentToReplace, with: firstURL)
                self.documentToReplace = nil
            } else {
                pendingImportURL = firstURL
                pendingTitle = firstURL.deletingPathExtension().lastPathComponent
                showingTitlePrompt = true
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            documentToReplace = nil
        }
    }

    private func savePendingImport() {
        guard let importURL = pendingImportURL else { return }

        let cleanedTitle = pendingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else {
            errorMessage = "Please enter a name for the PDF."
            return
        }

        do {
            let storedFilename = try PDFStorage.saveImportedPDF(from: importURL)

            let record = PDFDocumentRecord(
                title: cleanedTitle,
                storedFilename: storedFilename,
                sortOrder: documents.count
            )

            modelContext.insert(record)
            try modelContext.save()

            pendingImportURL = nil
            pendingTitle = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveRename() {
        guard let document = documentToRename else { return }

        let cleanedTitle = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else {
            errorMessage = "Please enter a name for the PDF."
            return
        }

        document.title = cleanedTitle
        document.updatedAt = Date()

        do {
            try modelContext.save()
            documentToRename = nil
            renameTitle = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replacePDF(_ document: PDFDocumentRecord, with newURL: URL) {
        do {
            let newStoredFilename = try PDFStorage.replacePDF(
                from: newURL,
                existingStoredFilename: document.storedFilename
            )

            document.storedFilename = newStoredFilename
            document.updatedAt = Date()

            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmDelete() {
        guard let document = documentToDelete else { return }

        do {
            try PDFStorage.deleteFile(named: document.storedFilename)
            modelContext.delete(document)
            try modelContext.save()
            documentToDelete = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
