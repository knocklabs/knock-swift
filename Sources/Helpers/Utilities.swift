//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

internal extension Knock {
    static func encodeGenericDataToJSON(data: [String: AnyCodable]?) -> String? {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        var jsonString: String?
        
        if let triggerData = try? encoder.encode(data) {
            jsonString = String(data: triggerData, encoding: .utf8)
        }
        
        return jsonString
    }
}

struct DynamicCodingKey: CodingKey {
    var intValue: Int? = nil
    var stringValue: String = ""
    
    init?(intValue: Int) {
        self.intValue = intValue
    }
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
}


