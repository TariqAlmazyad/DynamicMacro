import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(DynamicMacroMacros)
import DynamicMacroMacros

let testMacros: [String: Macro.Type] = [
    "Hashable":   HashableMacro.self,
    "Equatable":  EquatableMacro.self,
    "Identifiable": IdentifiableMacro.self,
]
#endif

final class DynamicMacroTests: XCTestCase {
    
    // MARK: — Hashable on Struct
    
    func testHashableOnStruct() throws {
        #if canImport(DynamicMacroMacros)
        assertMacroExpansion(
            """
            @Hashable
            struct Point {
              let x: Int
              let y: Int
            }
            """,
            expandedSource:
            """
            struct Point {
              let x: Int
              let y: Int
            }
            extension Point: Hashable {}
            extension Point {
              public func hash(into hasher: inout Hasher) {
                hasher.combine(x)
                hasher.combine(y)
              }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    // MARK: — Hashable on Enum
    
    func testHashableOnEnum() throws {
        #if canImport(DynamicMacroMacros)
        assertMacroExpansion(
            """
            @Hashable
            enum Direction {
              case north
              case custom(degrees: Double)
            }
            """,
            expandedSource:
            """
            enum Direction {
              case north
              case custom(degrees: Double)
            }
            extension Direction: Hashable {}
            extension Direction {
              public func hash(into hasher: inout Hasher) {
                switch self {
                case .north:
                  hasher.combine(0)
                case .custom(let degrees):
                  hasher.combine(1)
                  hasher.combine(degrees)
                }
              }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    // MARK: — Equatable on Class
    
    func testEquatableOnClass() throws {
        #if canImport(DynamicMacroMacros)
        assertMacroExpansion(
            """
            @Equatable
            class Widget {
              var id: UUID
              var name: String
              
              init(name: String) {
                self.id = UUID()
                self.name = name
              }
            }
            """,
            expandedSource:
            """
            class Widget {
              var id: UUID
              var name: String
              
              init(name: String) {
                self.id = UUID()
                self.name = name
              }
            }
            extension Widget {
              public static func ==(lhs: Widget, rhs: Widget) -> Bool {
                return lhs.id == rhs.id &&
                       lhs.name == rhs.name
              }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    // MARK: — Equatable on Enum
    
    func testEquatableOnEnum() throws {
        #if canImport(DynamicMacroMacros)
        assertMacroExpansion(
            """
            @Equatable
            enum Status {
              case ok
              case error(code: Int)
            }
            """,
            expandedSource:
            """
            enum Status {
              case ok
              case error(code: Int)
            }
            extension Status {
              public static func ==(lhs: Status, rhs: Status) -> Bool {
                switch (lhs, rhs) {
                case (.ok, .ok):
                  return true
                case let (.error(l), .error(r)):
                  return l == r
                default:
                  return false
                }
              }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    // MARK: — Identifiable on Struct
    
    func testIdentifiableOnStruct() throws {
        #if canImport(DynamicMacroMacros)
        assertMacroExpansion(
            """
            @Identifiable
            struct Order {
              var product: String
            }
            """,
            expandedSource:
            """
            struct Order {
              var product: String
            }
            extension Order: Identifiable {}
            extension Order {
              public var id: UUID {
                return _id
              }
              private var _id: UUID {
                if let existing = ObjectiveC.getAssociatedObject(self, forKey: &Order._idKey) as? UUID {
                  return existing
                }
                let new = UUID()
                ObjectiveC.setAssociatedObject(self, forKey: &Order._idKey, value: new)
                return new
              }
              private static var _idKey = "Order.id"
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    // MARK: — Identifiable on Class
    
    func testIdentifiableOnClass() throws {
        #if canImport(DynamicMacroMacros)
        assertMacroExpansion(
            """
            @Identifiable
            class UserViewModel: ObservableObject {
              @Published var name: String
            }
            """,
            expandedSource:
            """
            class UserViewModel: ObservableObject {
              @Published var name: String
            }
            extension UserViewModel: Identifiable {}
            extension UserViewModel {
              public var id: UUID {
                return _id
              }
              private var _id: UUID {
                if let existing = ObjectiveC.getAssociatedObject(self, forKey: &UserViewModel._idKey) as? UUID {
                  return existing
                }
                let new = UUID()
                ObjectiveC.setAssociatedObject(self, forKey: &UserViewModel._idKey, value: new)
                return new
              }
              private static var _idKey = "UserViewModel.id"
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
