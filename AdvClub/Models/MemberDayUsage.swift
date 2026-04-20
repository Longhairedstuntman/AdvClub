//
//  MemberDayUsage.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import Foundation

struct MemberDayUsage: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var usedFor: String
    var startDate: Date
    var endDate: Date
    var daysUsed: Int
}
