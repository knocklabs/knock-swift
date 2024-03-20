//
//  BulkOperation.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
    struct BulkOperation: Codable {
        public let id: String
        public let name: String
        public let status: BulkOperationStatus
        public let estimated_total_rows: Int
        public let processed_rows: Int
        public let started_at: Date?
        public let completed_at: Date?
        public let failed_at: Date?
    }
    
    enum BulkOperationStatus: String, Codable {
        case queued
        case processing
        case completed
        case failed
    }
}
