//
//  Item.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
