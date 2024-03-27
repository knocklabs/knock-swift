//
//  FeedItemTests.swift
//
//
//  Created by Matt Gardner on 3/22/24.
//

import Foundation
import XCTest
@testable import Knock

final class FeedItemTests: XCTestCase {
    
    func testContentBlockDecoding() throws {
        let decoder = JSONDecoder()

        let jsonString = 
        """
        {
            "__cursor": "g3QAAAABZAALaW5zZXJ0ZWRfYXR0AAAADWQACl",
            "__typename": "FeedItem",
            "activities": [],
            "actors": [],
            "archived_at": null,
            "blocks": [
                {
                    "content": "asdf",
                    "name": "body",
                    "rendered": "asdf",
                    "type": "markdown"
                },
                {
                    "buttons": [
                        {
                            "action": "/action-url",
                            "label": "Primary",
                            "name": "primary"
                        }
                    ],
                    "name": "actions",
                    "type": "button_set"
                }
            ],
            "clicked_at": null,
            "data": null,
            "id": "2e36JCjQAu5trvYtvmW9O14odis",
            "inserted_at": null,
            "interacted_at": null,
            "link_clicked_at": null,
            "read_at": null,
            "seen_at": null,
            "source": {
                "__typename": "NotificationSource",
                "categories": [],
                "key": "in-app",
                "version_id": "a4c43e19-056d-46f9-b4da-20c55c8c0bf7"
            },
            "tenant": "team-a",
            "total_activities": 1,
            "total_actors": 1,
            "updated_at": null
        }
        """

        let jsonData = jsonString.data(using: .utf8)!
        
        let item = try decoder.decode(Knock.FeedItem.self, from: jsonData)
         
        XCTAssertTrue(item.blocks.count == 2)
        XCTAssertTrue(item.blocks[0] is Knock.MarkdownContentBlock)
        XCTAssertTrue(item.blocks[1] is Knock.ButtonSetContentBlock)

        
        let encoder = JSONEncoder()
        let reencodedJSON = try encoder.encode(item)
        let reencodedString = String(data: reencodedJSON, encoding: .utf8)!
        
        XCTAssertTrue(reencodedString.contains("tenant"))
    }
}
