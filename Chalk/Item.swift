//
//  Item.swift
//  Chalk
//
//  Created by Blair Myers on 10/13/26.
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
