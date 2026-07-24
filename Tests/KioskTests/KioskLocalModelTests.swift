import Foundation
import Kiosk
import XCTest

final class KioskLocalModelTests: XCTestCase {
  func testSingleImportExposesDictionaryAndValueMacros() {
    let payload = LocalPayload(fromDict: ["name": "Kiosk", "kind": "primary"])
    let dictionary = payload.toDict()
    let decoded = LocalPayload(fromDict: dictionary)

    XCTAssertEqual(dictionary["name"] as? String, "Kiosk")
    XCTAssertEqual(dictionary["kind"] as? String, "primary")
    XCTAssertEqual(decoded.name, payload.name)
    XCTAssertEqual(decoded.kind, payload.kind)
  }

  func testSingleImportExposesSerializationMacros() throws {
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

  func testSingleImportExposesValidationMacros() {
    let valid = LocalProfile(name: "Kiosk", tags: ["swift"], email: "hello@kiosk.dev")
    let missingName = LocalProfile(name: nil, tags: ["swift"], email: "hello@kiosk.dev")
    let emptyTags = LocalProfile(name: "Kiosk", tags: [], email: "hello@kiosk.dev")
    let invalidEmail = LocalProfile(name: "Kiosk", tags: ["swift"], email: "not-email")

    XCTAssertNoThrow(try valid.validate())
    XCTAssertThrowsError(try missingName.validate()) { error in
      XCTAssertEqual((error as? ValidationError)?.field, "name")
    }
    XCTAssertThrowsError(try emptyTags.validate()) { error in
      XCTAssertEqual((error as? ValidationError)?.field, "tags")
    }
    XCTAssertThrowsError(try invalidEmail.validate()) { error in
      XCTAssertEqual((error as? ValidationError)?.field, "email")
    }
  }
}

@Dict
struct LocalPayload: Equatable {
  var name: String
  @UseValue var kind: LocalKind
}

@Valuable(String.self)
enum LocalKind: Equatable {
  @Value("primary")
  case primary
}

@Serializable
struct LocalRecord: Equatable {
  @Field("display_name") var name: String
  @Format(.string) var enabled: Bool
  @Default(3) var count: Int
}

@Validatable
struct LocalProfile {
  @Required var name: String?
  @NonEmpty var tags: [String]
  @Pattern(.email) var email: String?
}
