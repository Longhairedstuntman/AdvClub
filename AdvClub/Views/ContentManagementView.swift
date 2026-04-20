//
//  ContentManagementView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct ContentManagementView: View {
    @EnvironmentObject private var clubContentManager: ClubContentManager

    @State private var title = ""
    @State private var summary = ""
    @State private var details = ""
    @State private var selectedType: ClubPostType = .event
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isPublished = true
    @State private var isFeatured = false

    private var sortedPosts: [ClubPost] {
        clubContentManager.posts.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                createContentSection
                contentListSection
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("Content Management")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var createContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Event or Update")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                TextField("Enter title", text: $title)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                TextField("Enter summary", text: $summary)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Details")
                TextEditor(text: $details)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Picker("Type", selection: $selectedType) {
                ForEach(ClubPostType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if selectedType == .event {
                DatePicker("Start Date", selection: $startDate)
                DatePicker("End Date", selection: $endDate)
            }

            Toggle("Published", isOn: $isPublished)
            Toggle("Featured", isOn: $isFeatured)

            Button {
                clubContentManager.createPost(
                    title: title,
                    summary: summary,
                    details: details,
                    type: selectedType,
                    startDate: selectedType == .event ? startDate : nil,
                    endDate: selectedType == .event ? endDate : nil,
                    isPublished: isPublished,
                    isFeatured: isFeatured
                )
                resetForm()
            } label: {
                Text("Save Content")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var contentListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Existing Content")
                .font(.title2)
                .fontWeight(.semibold)

            if sortedPosts.isEmpty {
                Text("No content has been created yet.")
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(sortedPosts) { post in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(post.title)
                                .font(.headline)

                            Spacer()

                            Button(role: .destructive) {
                                clubContentManager.deletePost(id: post.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }

                        Text(post.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))

                        Text(post.summary)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(.vertical, 8)

                    if post.id != sortedPosts.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func resetForm() {
        title = ""
        summary = ""
        details = ""
        selectedType = .event
        startDate = Date()
        endDate = Date()
        isPublished = true
        isFeatured = false
    }
}

#Preview {
    NavigationStack {
        ContentManagementView()
            .environmentObject(ClubContentManager())
    }
}
