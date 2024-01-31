//
//  PreferenceService.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

internal class PreferenceService: KnockAPIService {
    
    internal func getAllUserPreferences() async throws -> [Knock.PreferenceSet] {
        try await get(path: "/users/\(getSafeUserId())/preferences", queryItems: nil)
    }
    
    internal func getUserPreferences(preferenceId: String) async throws -> Knock.PreferenceSet {
        try await get(path: "/users/\(getSafeUserId())/preferences/\(preferenceId)", queryItems: nil)
    }
    
    internal func setUserPreferences(preferenceId: String, preferenceSet: Knock.PreferenceSet) async throws -> Knock.PreferenceSet {
        try await put(path: "/users/\(getSafeUserId())/preferences/\(preferenceId)", body: preferenceSet)
    }
}
