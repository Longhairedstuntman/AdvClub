//
//  ClubPost.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import Foundation

struct ClubPost: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var summary: String
    var details: String
    var type: ClubPostType
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var isPublished: Bool
    var isFeatured: Bool
}
