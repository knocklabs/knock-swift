//
//  Block.swift
//  
//
//  Created by Matt Gardner on 1/18/24.
//

import Foundation

public protocol ContentBlockBase: Codable {
    var name: String { get }
    var type: ContentBlockType { get }
}

public enum ContentBlockType: String, Codable {
    case markdown // MarkdownContentBlock
    case text // TextContentBlock
    case buttonSet = "button_set" // ButtonSetContentBlock
}

public extension Knock {

    struct ButtonSetContentBlock: ContentBlockBase {
        public let name: String
        public let type: ContentBlockType = .buttonSet
        public let buttons: [BlockActionButton]
        
        enum CodingKeys: String, CodingKey {
            case name
            case type
            case buttons
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.buttons = try container.decode([BlockActionButton].self, forKey: .buttons)
        }
        
        public init(name: String, buttons: [BlockActionButton]) {
            self.name = name
            self.buttons = buttons
        }
    }

    struct TextContentBlock: ContentBlockBase {
        public let name: String
        public let type: ContentBlockType = .text
        public let content: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case type
            case content
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.content = try container.decode(String.self, forKey: .content)
        }
        
        public init(name: String, content: String) {
            self.name = name
            self.content = content
        }
    }

    struct MarkdownContentBlock: ContentBlockBase {
        public let name: String
        public let type: ContentBlockType = .markdown
        public let content: String
        public let rendered: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case type
            case content
            case rendered
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
            self.rendered = try container.decodeIfPresent(String.self, forKey: .rendered) ?? ""
        }
        
        public init(name: String, content: String, rendered: String) {
            self.name = name
            self.content = content
            self.rendered = rendered
        }
    }
    
    struct BlockActionButton: Codable {
        public let label: String
        public let name: String
        public let action: String
        
        enum CodingKeys: String, CodingKey {
            case label
            case name
            case action
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.label = try container.decode(String.self, forKey: .label)
            self.name = try container.decode(String.self, forKey: .name)
            self.action = try container.decode(String.self, forKey: .action)
        }
        
        public init(label: String, name: String, action: String) {
            self.label = label
            self.name = name
            self.action = action
        }
    }
}
