//
//  HomeView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var clubContentManager: ClubContentManager

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                spotlightSection

                VStack(spacing: 20) {
                    eventsAndUpdatesSection
                    upcomingReservationsSection
                }
            }
            .padding(20)
        }
        .background(Color.appBackgroundColor)
        .foregroundStyle(.white)
    }

    private var spotlightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SPOTLIGHT")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.72))

            if let post = clubContentManager.spotlightPost {
                Text(post.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                if post.type == .event, let startDate = post.startDate {
                    Text(dateFormatter.string(from: startDate))
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                } else {
                    Text(post.type.displayName)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                }

                Text(post.summary)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))

                HStack(spacing: 12) {
                    chip(text: post.type.displayName)

                    if post.isFeatured {
                        chip(text: "Featured")
                    }

                    if post.type == .event {
                        chip(text: "Upcoming")
                    }
                }
            } else {
                Text("No spotlighted content yet.")
                    .font(.headline)

                Text("Once an admin adds an upcoming event or featured update, it will appear here.")
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var eventsAndUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Events & Club Updates")
                .font(.title2)
                .fontWeight(.semibold)

            if clubContentManager.publishedPosts.isEmpty {
                Text("No events or updates have been published yet.")
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(clubContentManager.publishedPosts.prefix(6)) { post in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(post.title)
                                .font(.headline)

                            Spacer()

                            Text(post.type.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        if post.type == .event, let startDate = post.startDate {
                            Text(dateFormatter.string(from: startDate))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Text(post.summary)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)

                    if post.id != clubContentManager.publishedPosts.prefix(6).last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var upcomingReservationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Upcoming Reservations")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Moab Weekend")
                            .font(.headline)
                        Text("Apr 18 – Apr 20")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                    Text("Confirmed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bear Lake Day Trip")
                            .font(.headline)
                        Text("May 2")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                    Text("Pending")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func chip(text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(ClubContentManager())
    }
}

