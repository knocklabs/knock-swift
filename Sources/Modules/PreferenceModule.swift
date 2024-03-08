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
    
    /**
     Retrieve all user's preference sets. Will always return an empty preference set object, even if it does not currently exist for the user.
     https://docs.knock.app/reference#get-preferences-user#get-preferences-user

     */
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
    
    /**
     Retrieve a user's preference set. Will always return an empty preference set object, even if it does not currently exist for the user.
     https://docs.knock.app/reference#get-preferences-user#get-preferences-user

     - Parameters:
        - preferenceId: The preferenceId for the PreferenceSet.
     */
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
    
    /**
     Sets preferences within the given preference set. This is a destructive operation and will replace any existing preferences with the preferences given.

     If no user exists in the current environment for the current user, Knock will create the user entry as part of this request.

     The preference set :id can be either "default" or a tenant.id. Learn more about per-tenant preference sets in our preferences guide.
     https://docs.knock.app/send-and-manage-data/preferences#preference-sets
     https://docs.knock.app/reference#get-preferences-user#set-preferences-user
     
     - Parameters:
        - preferenceId: The preferenceId for the PreferenceSet.
        - preferenceSet: PreferenceSet with updated properties.
     */
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
