/// Automatically synthesizes `Hashable` conformance for the annotated type.
///
/// - What it does:
///   - Adds `extension YourType: Hashable {}`
///   - Generates a `func hash(into hasher: inout Hasher)` that combines all stored properties.
/// - Supported on:
///   - Structs
///   - Classes
///   - Enums (including associated values of any `Hashable` type)
///
/// ```swift
/// @Hashable
/// struct Person {
///   var name: String
///   var age: Int
/// }
/// // Person is now Hashable without any boilerplate
/// ```
///
/// - Note: Requires Swift 5.9+ and the Swift compiler plugin.
@attached(member, names: named(hash))
@attached(extension, conformances: Hashable)
public macro Hashable() = #externalMacro(
  module: "DynamicMacroMacros",
  type:   "HashableMacro"
)

/// Automatically synthesizes `Equatable` conformance for the annotated type.
///
/// - What it does:
///   - Generates a `static func ==(lhs: Self, rhs: Self) -> Bool`
///     that compares all stored properties for equality.
/// - Supported on:
///   - Structs
///   - Classes
///   - Enums (including associated values of any `Equatable` type)
///
/// ```swift
/// @Equatable
/// class Widget {
///   var id: UUID
/// }
/// // Widget now conforms to Equatable automatically
/// ```
///
/// - Note: Requires Swift 5.9+ and the Swift compiler plugin.
@attached(member, names: named(==))
public macro Equatable() = #externalMacro(
  module: "DynamicMacroMacros",
  type:   "EquatableMacro"
)
/// Automatically synthesizes `Identifiable` conformance for the annotated type.
///
/// - What it does:
///   - Adds `extension YourType: Identifiable {}`
///   - If no `id` property exists, injects an appropriate identifier property:
///     - Default: `public var id: String = UUID().uuidString`
///     - Optional: `public var id: String? = nil` (when `optional: true`)
///     - Custom type: `public var id: YourType = defaultValue` (when `idType` specified)
///   - If you already have an `id` property, it will simply adopt that as the identifier
///   - For simple enums (without associated values), uses `self` as the identifier
///
/// - Parameters:
///   - idType: The type to use for the identifier (defaults to `String.self`)
///   - optional: Whether the identifier should be optional (defaults to `false`)
///
/// - Supported on:
///   - Structs
///   - Classes
///   - Enums
///
/// ```swift
/// // Basic usage (String ID)
/// @Identifiable
/// struct Order {
///   var product: String
///   // Synthesizes: public var id: String = UUID().uuidString
/// }
///
/// // Custom ID type
/// @Identifiable(idType: Int.self)
/// struct User {
///   var name: String
///   // Synthesizes: public var id: Int = Int.random(in: 1..<Int.max)
/// }
///
/// // Optional ID
/// @Identifiable(optional: true)
/// struct Task {
///   var title: String
///   // Synthesizes: public var id: String? = nil
/// }
///
/// // Simple enum (uses self as ID)
/// @Identifiable
/// enum Status {
///   case pending, completed
///   // Synthesizes: public var id: Self { self }
/// }
/// ```
///
/// - Note: Requires Swift 5.9+ and the Swift compiler plugin.
@attached(extension, conformances: Identifiable)
@attached(member, names: named(id))
public macro Identifiable(idType: Any.Type = String.self, optional: Bool = false) = #externalMacro(
    module: "DynamicMacroMacros",
    type: "IdentifiableMacro"
)
