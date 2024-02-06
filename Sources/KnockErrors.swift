//
//  KnockErrors.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation

public extension Knock {
    enum KnockError: Error, Equatable {
        case runtimeError(String)
        case userIdNotSetError
        case knockNotSetup
        case wrongKeyError
    }

    struct NetworkError: NetworkErrorProtocol {
        public var title: String?
        public var code: Int
        public var errorDescription: String? { return _description }
        public var failureReason: String? { return _description }
        
        private var _description: String
        
        public init(title: String?, description: String, code: Int) {
            self.title = title ?? "Error"
            self._description = description
            self.code = code
        }
    }
}

extension Knock.KnockError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let message):
            return message
        case .userIdNotSetError:
            return "UserId not found. Please authenticate your userId with Knock.signIn()."
        case .knockNotSetup:
            return "Knock instance still needs to be setup. Please setup with Knock.shared.setup()."
        case .wrongKeyError:
            return "You are using your secret API key on the client. Please use the public key."
        }
    }
}

protocol NetworkErrorProtocol: LocalizedError {
    var title: String? { get }
    var code: Int { get }
}
