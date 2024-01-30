//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
  
    func getAllUserPreferences(completionHandler: @escaping ((Result<[PreferenceSet], Error>) -> Void)) {
        performActionWithUserId( { userId, completion in
            self.api.decodeFromGet([PreferenceSet].self, path: "/users/\(userId)/preferences", queryItems: nil, then: completion)
        }, completionHandler: completionHandler)
    }
    
    func getUserPreferences(preferenceId: String, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        performActionWithUserId( { userId, completion in
            self.api.decodeFromGet(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", queryItems: nil, then: completion)
        }, completionHandler: completionHandler)
    }
    
    func setUserPreferences(preferenceId: String, preferenceSet: PreferenceSet, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        performActionWithUserId( { userId, completion in
            let payload = preferenceSet
            self.api.decodeFromPut(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", body: payload, then: completion)
        }, completionHandler: completionHandler)
    }
}
