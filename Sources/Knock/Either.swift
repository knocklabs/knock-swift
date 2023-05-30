//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation

public enum Either<T, U> {
    case left(T)
    case right(U)
    
    public func leftValue() -> T? {
        switch self {
        case .left(let value):
            return value
        default:
            return nil
        }
    }

    public func rightValue() -> U? {
        switch self {
        case .right(let value):
            return value
        default:
            return nil
        }
    }
}

extension Either: Decodable where T: Decodable, U: Decodable {
    public init(from decoder: Decoder) throws {
        if let value = try? T(from: decoder) {
            self = .left(value)
        }
        else if let value = try? U(from: decoder) {
            self = .right(value)
        }
        else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode \(T.self) or \(U.self)")
            throw DecodingError.dataCorrupted(context)
        }
    }
}

extension Either: Encodable where T: Encodable, U: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .left(let value):
            try container.encode(value)
        case .right(let value):
            try container.encode(value)
        }
    }
}
