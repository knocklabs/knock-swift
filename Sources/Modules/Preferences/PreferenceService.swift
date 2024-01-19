//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
  
    func getAllUserPreferences(completionHandler: @escaping ((Result<[PreferenceSet], Error>) -> Void)) {
        self.api.decodeFromGet([PreferenceSet].self, path: "/users/\(userId)/preferences", queryItems: nil, then: completionHandler)
    }
    
    func getUserPreferences(preferenceId: String, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        self.api.decodeFromGet(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", queryItems: nil, then: completionHandler)
    }
    
    func setUserPreferences(preferenceId: String, preferenceSet: PreferenceSet, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        let payload = preferenceSet
        self.api.decodeFromPut(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", body: payload, then: completionHandler)
    }
}
