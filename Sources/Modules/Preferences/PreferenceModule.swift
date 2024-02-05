//
//  PreferenceModule.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation
import OSLog

internal class PreferenceModule {
    let preferenceService = PreferenceService()
        
    internal func getAllUserPreferences() async throws -> [Knock.PreferenceSet] {
        do {
            let set = try await preferenceService.getAllUserPreferences(userId: Knock.shared.environment.getSafeUserId())
            Knock.shared.log(type: .debug, category: .preferences, message: "getAllUserPreferences", status: .success)
            return set
        } catch let error {
            Knock.shared.log(type: .error, category: .preferences, message: "getAllUserPreferences", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    internal func getUserPreferences(preferenceId: String) async throws -> Knock.PreferenceSet {
        do {
            let set = try await preferenceService.getUserPreferences(userId: Knock.shared.environment.getSafeUserId(), preferenceId: preferenceId)
            Knock.shared.log(type: .debug, category: .preferences, message: "getUserPreferences", status: .success)
            return set
        } catch let error {
            Knock.shared.log(type: .error, category: .preferences, message: "getUserPreferences", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    internal func setUserPreferences(preferenceId: String, preferenceSet: Knock.PreferenceSet) async throws -> Knock.PreferenceSet {
        do {
            let set = try await preferenceService.setUserPreferences(userId: Knock.shared.environment.getSafeUserId(), preferenceId: preferenceId, preferenceSet: preferenceSet)
            Knock.shared.log(type: .debug, category: .preferences, message: "setUserPreferences", status: .success)
            return set
        } catch let error {
            Knock.shared.log(type: .error, category: .preferences, message: "setUserPreferences", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
}

public extension Knock {
    func getAllUserPreferences() async throws -> [Knock.PreferenceSet] {
        try await self.preferenceModule.getAllUserPreferences()
    }
    
    func getAllUserPreferences(completionHandler: @escaping ((Result<[PreferenceSet], Error>) -> Void)) {
        Task {
            do {
                let preferences = try await getAllUserPreferences()
                completionHandler(.success(preferences))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func getUserPreferences(preferenceId: String) async throws -> Knock.PreferenceSet {
        try await self.preferenceModule.getUserPreferences(preferenceId: preferenceId)
    }
    
    func getUserPreferences(preferenceId: String, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        Task {
            do {
                let preferences = try await getUserPreferences(preferenceId: preferenceId)
                completionHandler(.success(preferences))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func setUserPreferences(preferenceId: String, preferenceSet: PreferenceSet) async throws -> Knock.PreferenceSet {
        try await self.preferenceModule.setUserPreferences(preferenceId: preferenceId, preferenceSet: preferenceSet)
    }
    
    func setUserPreferences(preferenceId: String, preferenceSet: PreferenceSet, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        Task {
            do {
                let preferences = try await setUserPreferences(preferenceId: preferenceId, preferenceSet: preferenceSet)
                completionHandler(.success(preferences))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
}
