//
//  PreferenceService.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

internal class PreferenceService: KnockAPIService {
    
    internal func getAllUserPreferences(userId: String) async throws -> [Knock.PreferenceSet] {
        try await get(path: "/users/\(userId)/preferences", queryItems: nil)
    }
    
    internal func getUserPreferences(userId: String, preferenceId: String) async throws -> Knock.PreferenceSet {
        try await get(path: "/users/\(userId)/preferences/\(preferenceId)", queryItems: nil)
    }
    
    internal func setUserPreferences(userId: String, preferenceId: String, preferenceSet: Knock.PreferenceSet) async throws -> Knock.PreferenceSet {
        try await put(path: "/users/\(userId)/preferences/\(preferenceId)", body: preferenceSet)
    }
}
