//
//  ClubPostType.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import Foundation

enum ClubPostType: String, Codable, Hashable, CaseIterable {
    case event
    case update

    var displayName: String {
        switch self {
        case .event:
            return "Event"
        case .update:
            return "Update"
        }
    }
}
