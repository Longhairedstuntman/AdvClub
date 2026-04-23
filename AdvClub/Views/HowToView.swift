//
//  HowToView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI
import PDFKit

struct HowToView: View {
    @EnvironmentObject private var howToManager: HowToManager
    @State private var selectedCategory: HowToCategory = .vehicles
    @State private var searchText = ""
    @State private var selectedHowTo: HowToEntry?

    init() {
        UISegmentedControl.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor(white: 0.78, alpha: 1.0)
        ], for: .normal)

        UISegmentedControl.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor.black
        ], for: .selected)
    }

    private var filteredItems: [HowToEntry] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return howToManager.howTos.filter { item in
            let matchesSearch = trimmedSearch.isEmpty
                || item.title.localizedCaseInsensitiveContains(trimmedSearch)
                || item.summary.localizedCaseInsensitiveContains(trimmedSearch)
                || item.pdfFileName.localizedCaseInsensitiveContains(trimmedSearch)

            if trimmedSearch.isEmpty {
                return item.category == selectedCategory && matchesSearch
            }

            return matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                categoryPickerSection
                searchSection
                howToListSection
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("How-To")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            howToManager.startListeningPublishedHowTos()
        }
        .sheet(item: $selectedHowTo) { item in
            NavigationStack {
                HowToPDFViewerView(item: item)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How-To Guides")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Browse guides by category and choose the instructions you need.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)

           Picker("Category", selection: $selectedCategory) {
                ForEach(HowToCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(.white)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search")
                .font(.headline)
            TextField(
                "",
                text: $searchText,
                prompt: Text("Search how-to guides")
                    .foregroundStyle(.white.opacity(0.45))
            )
            .padding()
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var howToListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory.title : "Search Results")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(filteredItems.count) guide\(filteredItems.count == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }

            if filteredItems.isEmpty {
                Text("No how-to guides match this category or search.")
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                ForEach(filteredItems) { item in
                    Button {
                        selectedHowTo = item
                    } label: {
                        howToRow(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func howToRow(for item: HowToEntry) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.category.iconName)
                .font(.title3)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text(item.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)

                Text(item.category.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 6)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct HowToPDFViewerView: View {
    @Environment(\.dismiss) private var dismiss

    let item: HowToEntry

    @State private var document: PDFDocument?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading PDF…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackgroundColor)
                    .foregroundStyle(.white)
            } else if let document {
                PDFKitView(document: document)
                    .background(Color.appBackgroundColor)
            } else {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                    Text(errorMessage ?? "Unable to load this PDF.")
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
                .background(Color.appBackgroundColor)
                .foregroundStyle(.white)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
        .task {
            await loadPDF()
        }
    }

    private func loadPDF() async {
        isLoading = true
        errorMessage = nil
        document = nil

        guard let url = URL(string: item.pdfDownloadURL) else {
            errorMessage = "The PDF URL is invalid."
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let pdfDocument = PDFDocument(data: data) else {
                errorMessage = "The PDF could not be opened."
                isLoading = false
                return
            }

            document = pdfDocument
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

#Preview {
    NavigationStack {
        HowToView()
            .environmentObject(HowToManager())
    }
}
