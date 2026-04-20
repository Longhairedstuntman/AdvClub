//
//  AppUser.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import Foundation

struct AppUser: Identifiable, Codable, Hashable {
    let id: String
    var email: String
    var displayName: String
    var role: UserRole
    var isActive: Bool
    var quarterlyAllowance: Int
}
