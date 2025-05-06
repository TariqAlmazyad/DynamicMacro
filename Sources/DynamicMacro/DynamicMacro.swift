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
///   - If no `id` property exists, injects `public var id: UUID = UUID()`
///   - If you already have an `id` property, it will simply adopt that as the identifier.
/// - Supported on:
///   - Structs
///   - Classes
///
/// ```swift
/// @Identifiable
/// struct Order {
///   // id will be synthesized automatically
///   var product: String
/// }
/// ```
///
/// - Note: Requires Swift 5.9+ and the Swift compiler plugin.
@attached(extension, conformances: Identifiable)
@attached(member, names: named(id))
public macro Identifiable(idType: Any.Type = String.self) = #externalMacro(
    module: "DynamicMacroMacros",
    type: "IdentifiableMacro"
)
