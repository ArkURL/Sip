//
//  IntakeEntry.swift
//  Sip
//

import Foundation

struct IntakeEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let amountML: Int
    let timestamp: Date

    init(id: UUID = UUID(), amountML: Int, timestamp: Date = Date()) {
        self.id = id
        self.amountML = amountML
        self.timestamp = timestamp
    }
}
