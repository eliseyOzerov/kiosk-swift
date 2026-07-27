import Foundation
import Kiosk
import XCTest

final class KioskLocalModelTests: XCTestCase {
  func testSingleImportExposesWireMacros() throws {
    let data = #"{"display_name":"Kiosk","enabled":"yes"}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LocalRecord.self, from: data)

    XCTAssertEqual(decoded.name, "Kiosk")
    XCTAssertTrue(decoded.enabled)
    XCTAssertEqual(decoded.count, 3)

    let encoded = try JSONEncoder().encode(decoded)
    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )

    XCTAssertEqual(object["display_name"] as? String, "Kiosk")
    XCTAssertEqual(object["enabled"] as? String, "true")
    XCTAssertEqual(object["count"] as? Int, 3)
  }

  func testWireSpecDrivesLocalModelCoding() throws {
    let spec = WireSpec.json(
      fields: .snakeCase,
      values: .jsonDefault
        .date(.secondsSince1970)
        .bool(.string),
      defaults: WireDefaults()
        .setting(Bool.self, false)
        .setting(Array.self, [])
        .setting(Dictionary.self, [:])
        .setting(Set<Int>.self, [])
    )
    let data = #"{"display_name":"Kiosk","created_at":1000,"enabled":"yes"}"#
      .data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.userInfo[.wireSpec] = spec

    let decoded = try decoder.decode(ContextualRecord.self, from: data)

    XCTAssertEqual(decoded.displayName, "Kiosk")
    XCTAssertEqual(decoded.createdAt, Date(timeIntervalSince1970: 1000))
    XCTAssertTrue(decoded.enabled)
    XCTAssertFalse(decoded.notifications)
    XCTAssertEqual(decoded.tags, [])
    XCTAssertEqual(decoded.scores, [])
    XCTAssertEqual(decoded.labels, [:])

    let encoder = JSONEncoder()
    encoder.userInfo[.wireSpec] = spec

    let encoded = try encoder.encode(decoded)
    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )

    XCTAssertEqual(object["display_name"] as? String, "Kiosk")
    XCTAssertEqual((object["created_at"] as? NSNumber)?.doubleValue, 1000)
    XCTAssertEqual(object["enabled"] as? String, "true")
    XCTAssertEqual(object["notifications"] as? String, "false")
    XCTAssertEqual(object["tags"] as? [String], [])
    XCTAssertEqual(object["scores"] as? [Int], [])
    XCTAssertEqual(object["labels"] as? [String: String], [:])
  }
}

@Wire
struct LocalRecord: Equatable {
  @Field("display_name") var name: String
  @Format(.string) var enabled: Bool
  @Default(3) var count: Int
}

@Wire
struct ContextualRecord: Equatable {
  var displayName: String
  var createdAt: Date
  var enabled: Bool
  var notifications: Bool
  var tags: [String]
  var scores: Set<Int>
  var labels: [String: String]
}
