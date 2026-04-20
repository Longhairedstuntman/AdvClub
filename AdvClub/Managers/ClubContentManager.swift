//
//  ClubContentManager.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ClubContentManager: ObservableObject {
    @Published private(set) var posts: [ClubPost] = []

    private let postsKey = "advclub.clubposts"

    init() {
        loadPosts()
        seedSampleContentIfNeeded()
    }

    var publishedPosts: [ClubPost] {
        posts
            .filter { $0.isPublished }
            .sorted { lhs, rhs in
                if lhs.type == .event, rhs.type == .event {
                    return (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    var spotlightPost: ClubPost? {
        let now = Date()

        if let nextEvent = posts
            .filter({ $0.isPublished && $0.type == .event && ($0.startDate ?? .distantPast) >= now })
            .sorted(by: { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) })
            .first {
            return nextEvent
        }

        return posts
            .filter { $0.isPublished && $0.isFeatured }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func createPost(
        title: String,
        summary: String,
        details: String,
        type: ClubPostType,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isPublished: Bool = true,
        isFeatured: Bool = false
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTitle.isEmpty == false else { return }
        guard trimmedSummary.isEmpty == false else { return }

        let newPost = ClubPost(
            id: UUID(),
            title: trimmedTitle,
            summary: trimmedSummary,
            details: trimmedDetails,
            type: type,
            startDate: type == .event ? startDate : nil,
            endDate: type == .event ? endDate : nil,
            createdAt: Date(),
            updatedAt: Date(),
            isPublished: isPublished,
            isFeatured: isFeatured
        )

        posts.append(newPost)
        savePosts()
    }

    func updatePost(_ updatedPost: ClubPost) {
        guard let index = posts.firstIndex(where: { $0.id == updatedPost.id }) else { return }

        var copy = updatedPost
        copy.updatedAt = Date()

        posts[index] = copy
        savePosts()
    }

    func deletePost(id: UUID) {
        posts.removeAll { $0.id == id }
        savePosts()
    }

    private func loadPosts() {
        guard let data = UserDefaults.standard.data(forKey: postsKey) else {
            posts = []
            return
        }

        do {
            posts = try JSONDecoder().decode([ClubPost].self, from: data)
        } catch {
            posts = []
        }
    }

    private func savePosts() {
        do {
            let data = try JSONEncoder().encode(posts)
            UserDefaults.standard.set(data, forKey: postsKey)
        } catch {
            assertionFailure("Failed to save club posts: \(error)")
        }
    }

    private func seedSampleContentIfNeeded() {
        guard posts.isEmpty else { return }

        let now = Date()
        let calendar = Calendar.current

        let sampleEvent = ClubPost(
            id: UUID(),
            title: "Spring Trail Meet",
            summary: "Join the club for a morning trail meetup and scenic drive.",
            details: "Meet at the clubhouse parking area. We will depart at 9:00 AM, stop for lunch, and return in the afternoon.",
            type: .event,
            startDate: calendar.date(byAdding: .day, value: 5, to: now),
            endDate: calendar.date(byAdding: .day, value: 5, to: now),
            createdAt: now,
            updatedAt: now,
            isPublished: true,
            isFeatured: true
        )

        let sampleUpdate = ClubPost(
            id: UUID(),
            title: "Member Feature Update",
            summary: "Reservation improvements and club updates are rolling out this week.",
            details: "We are improving the member experience across the app, including reservations and event visibility.",
            type: .update,
            startDate: nil,
            endDate: nil,
            createdAt: now,
            updatedAt: now,
            isPublished: true,
            isFeatured: false
        )

        posts = [sampleEvent, sampleUpdate]
        savePosts()
    }
}
