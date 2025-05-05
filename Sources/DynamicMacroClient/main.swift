import DynamicMacro
import SwiftUI


@Hashable
@Equatable
class MyClassModelUser {
    
}


@Hashable
@Equatable
class MyClass: ObservableObject {
    
}

@Equatable
@Hashable
enum MyCases {
    case first(Int)
    case second(Binding<Int>)
    case viewSecond(MyClassModelUser)
}

// Example 1: Simple struct
@Hashable
@Equatable
@Identifiable
struct User {
    let id: String
    let name: String
    let age: Int
}

// Example 2: More complex model
@Hashable
@Equatable
struct Point {
    let x: Double
    let y: Double
}

// Test the conformances
func testConformances() {
    print("=== Testing User ===")
    let user1 = User(id: "1", name: "Alice", age: 30)
    let user2 = User(id: "2", name: "Bob", age: 25)
    
    // Equatable
    print("Equatable test:", user1 == user2) // false
    
    // Hashable
    var hasher = Hasher()
    user1.hash(into: &hasher)
    let hash1 = hasher.finalize()
    user2.hash(into: &hasher)
    let hash2 = hasher.finalize()
    print("Hashable test:", hash1 == hash2) // false
    
    // Identifiable
    print("Identifiable test:", user1.id) // "1"
    
    print("\n=== Testing Point ===")
    let point1 = Point(x: 1.0, y: 2.0)
    let point2 = Point(x: 1.0, y: 2.0)
    print("Equatable test:", point1 == point2) // true
}

testConformances()

// Show macro expansions
print("\n=== Macro Expansions ===")
print("""
Original:
@DynamicHashable
struct User {
    let id: String
    let name: String
    let age: Int
}

Expanded:
extension User: Hashable {}
struct User {
    let id: String
    let name: String
    let age: Int
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id && 
               lhs.name == rhs.name && 
               lhs.age == rhs.age
    }
}
extension User: Identifiable {}
""")
