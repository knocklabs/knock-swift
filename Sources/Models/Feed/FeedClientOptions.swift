//
//  FeedClientOptions.swift
//  
//
//  Created by Matt Gardner on 1/23/24.
//

import Foundation

extension Knock {
    public struct FeedClientOptions: Codable {
        public var before: String?
        public var after: String?
        public var page_size: Int?
        public var status: FeedItemScope?
        public var source: String? // Optionally scope all notifications to a particular source only
        public var tenant: String?  // Optionally scope all requests to a particular tenant
        public var has_tenant: Bool? // Optionally scope to notifications with any tenancy or no tenancy
        public var archived: FeedItemArchivedScope? // Optionally scope to a given archived status (defaults to `exclude`)
        public var trigger_data: [String: AnyCodable]? // GenericData
        public var locale: String? // Optionally scope to a particular locale
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<FeedClientOptions.CodingKeys> = try decoder.container(keyedBy: FeedClientOptions.CodingKeys.self)
            self.before = try container.decodeIfPresent(String.self, forKey: FeedClientOptions.CodingKeys.before)
            self.after = try container.decodeIfPresent(String.self, forKey: FeedClientOptions.CodingKeys.after)
            self.page_size = try container.decodeIfPresent(Int.self, forKey: FeedClientOptions.CodingKeys.page_size)
            self.status = try container.decodeIfPresent(Knock.FeedItemScope.self, forKey: FeedClientOptions.CodingKeys.status)
            self.source = try container.decodeIfPresent(String.self, forKey: FeedClientOptions.CodingKeys.source)
            self.tenant = try container.decodeIfPresent(String.self, forKey: FeedClientOptions.CodingKeys.tenant)
            self.has_tenant = try container.decodeIfPresent(Bool.self, forKey: FeedClientOptions.CodingKeys.has_tenant)
            self.archived = try container.decodeIfPresent(Knock.FeedItemArchivedScope.self, forKey: FeedClientOptions.CodingKeys.archived)
            self.trigger_data = try container.decodeIfPresent([String : AnyCodable].self, forKey: FeedClientOptions.CodingKeys.trigger_data)
            self.locale = try container.decodeIfPresent(String.self, forKey: FeedClientOptions.CodingKeys.locale)
        }
        
        public init(before: String? = nil, after: String? = nil, page_size: Int? = nil, status: FeedItemScope? = nil, source: String? = nil, tenant: String? = nil, has_tenant: Bool? = nil, archived: FeedItemArchivedScope? = nil, trigger_data: [String : AnyCodable]? = nil, locale: String? = nil) {
            self.before = before
            self.after = after
            self.page_size = page_size
            self.status = status
            self.source = source
            self.tenant = tenant
            self.has_tenant = has_tenant
            self.archived = archived
            self.trigger_data = trigger_data
            self.locale = locale
        }
        
        /**
         Returns a new struct of type `FeedClientOptions` with the options passed as the parameter merged into it.
         
         - Parameters:
            - options: the options to merge with the current struct, if they are nil, only a copy of `self` will be returned
         */
        public func mergeOptions(options: FeedClientOptions? = nil) -> FeedClientOptions {
            // initialize a new `mergedOptions` struct with all the properties of the `self` struct
            var mergedOptions = FeedClientOptions(
                before: self.before,
                after: self.after,
                page_size: self.page_size,
                status: self.status,
                source: self.source,
                tenant: self.tenant,
                has_tenant: self.has_tenant,
                archived: self.archived,
                trigger_data: self.trigger_data,
                locale: self.locale
            )
            
            // check if the passed options are not nil
            guard let options = options else {
                return mergedOptions
            }
            
            // for each one of the properties `not nil` in the parameter `options`, override the ones in the new struct
            if options.before != nil {
                mergedOptions.before = options.before
            }
            if options.after != nil {
                mergedOptions.after = options.after
            }
            if options.page_size != nil {
                mergedOptions.page_size = options.page_size
            }
            if options.status != nil {
                mergedOptions.status = options.status
            }
            if options.source != nil {
                mergedOptions.source = options.source
            }
            if options.tenant != nil {
                mergedOptions.tenant = options.tenant
            }
            if options.has_tenant != nil {
                mergedOptions.has_tenant = options.has_tenant
            }
            if options.archived != nil {
                mergedOptions.archived = options.archived
            }
            if options.trigger_data != nil {
                mergedOptions.trigger_data = options.trigger_data
            }
            if options.locale != nil {
                mergedOptions.locale = options.locale
            }
            
            return mergedOptions
        }
    }
}
