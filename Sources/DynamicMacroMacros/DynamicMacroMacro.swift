import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin

/// A generic error type for macro expansion failures.
///
/// Conforms to `Error` and `CustomStringConvertible` to provide
/// descriptive messages when macro expansion cannot proceed.
enum MacroError: Error, CustomStringConvertible {
    /// An error with an associated explanatory message.
    case message(String)

    /// A textual description of the error.
    public var description: String {
        switch self {
        case .message(let text):
            return text
        }
    }
}

@available(macOS 13.0, *)
/// The entry point for the DynamicMacro compiler plugin.
///
/// Registers all macros provided by this package with the Swift compiler,
/// making `@Hashable`, `@Equatable`, and `@Identifiable` available in
/// client targets.
@main
struct DynamicMacroPlugin: CompilerPlugin {
    /// The collection of macros exposed by this plugin.
    public let providingMacros: [Macro.Type] = [
        HashableMacro.self,
        EquatableMacro.self,
        IdentifiableMacro.self,
    ]
}

// MARK: ——————————————————————
// 1) Hashable: adds `: Hashable` via an extension
//    Works on structs, classes, and enums.
// ——————————————————————

/// A macro that synthesizes `Hashable` conformance.
///
/// - MemberMacro: Generates the `hash(into:)` implementation.
/// - ExtensionMacro: Adds the `: Hashable` conformance via an extension.
///
/// **Supported Declarations:**
///   - `struct`
///   - `class`
///   - `enum`
public struct HashableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        switch declaration {
        case let structDecl as StructDeclSyntax:
            let properties = structDecl.memberBlock.members
                .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                .filter { $0.bindingSpecifier.text == "let" || $0.bindingSpecifier.text == "var" }
                .flatMap { $0.bindings }
                .map { $0.pattern.trimmedDescription }

            let hashBody = properties.map { "hasher.combine(\($0))" }.joined(separator: "\n    ")

            return ["""
            public func hash(into hasher: inout Hasher) {
                \(raw: hashBody)
            }
            """]

        case let classDecl as ClassDeclSyntax:
            let properties = classDecl.memberBlock.members
                .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                .filter { $0.bindingSpecifier.text == "let" || $0.bindingSpecifier.text == "var" }
                .flatMap { $0.bindings }
                .map { $0.pattern.trimmedDescription }

            let hashBody = properties.map { "hasher.combine(\($0))" }.joined(separator: "\n    ")

            return ["""
            public func hash(into hasher: inout Hasher) {
                \(raw: hashBody)
                hasher.combine(ObjectIdentifier(self))
            }
            """]

        case let enumDecl as EnumDeclSyntax:
            let cases = enumDecl.memberBlock.members
                .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
                .flatMap { $0.elements }

            let hashStatements = cases.enumerated().map { index, element in
                if let parameters = element.parameterClause?.parameters {
                    let paramsHash = parameters.enumerated().map { paramIndex, param in
                        let paramName = param.firstName?.text ?? "value\(paramIndex)"
                        let type = param.type.trimmedDescription

                        if type.hasPrefix("Binding<") {
                            return "hasher.combine(\(paramName).wrappedValue)"
                        } else if type.contains("->") {
                            return "// Cannot hash function type"
                        } else {
                            // For all other types including nested enums, just combine directly
                            return "hasher.combine(\(paramName))"
                        }
                    }.filter { !$0.starts(with: "//") }.joined(separator: "\n        ")

                    let paramNames = parameters.enumerated().map { index, param in
                        param.firstName?.text ?? "value\(index)"
                    }

                    return """
                    case .\(element.name)(\(paramNames.map { "let \($0)" }.joined(separator: ", "))):
                        hasher.combine(\(index))
                        \(paramsHash)
                    """
                } else {
                    return """
                    case .\(element.name):
                        hasher.combine(\(index))
                    """
                }
            }.joined(separator: "\n        ")

            return ["""
            public func hash(into hasher: inout Hasher) {
                switch self {
                \(raw: hashStatements)
                }
            }
            """]

        default:
            throw MacroError.message("@Hashable can only be applied to structs, classes, or enums")
        }
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let extensionDecl: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        extension \(type.trimmed): Hashable {}
        """)
        return [extensionDecl]
    }
}


/// ——————————————————————
/// 2) Equatable: injects `static func ==(...)` + `: Equatable`
///    Works on structs, classes, and enums.
/// ——————————————————————

@available(macOS 13.0, *)
public struct EquatableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        switch declaration {
        case let structDecl as StructDeclSyntax:
            return try makeEquatable(for: structDecl.name.text,
                                   members: structDecl.memberBlock.members,
                                   isClass: false)
            
        case let classDecl as ClassDeclSyntax:
            return try makeEquatable(for: classDecl.name.text,
                                   members: classDecl.memberBlock.members,
                                   isClass: true)
            
        case let enumDecl as EnumDeclSyntax:
            let typeName = enumDecl.name.text
            let elements = enumDecl.memberBlock.members
                .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
                .flatMap { $0.elements }

            let caseBodies = elements.map { element -> String in
                let caseName = element.name.text
                
                if let params = element.parameterClause?.parameters, !params.isEmpty {
                    let names: [String] = params.enumerated().map { idx, p in
                        p.secondName?.text ?? p.firstName?.text ?? "value\(idx)"
                    }
                    
                    let lhsBinds = names.map { "let lhs\($0)" }.joined(separator: ", ")
                    let rhsBinds = names.map { "let rhs\($0)" }.joined(separator: ", ")
                    
                    let comps = params.enumerated().map { idx, p in
                        let name = names[idx]
                        let type = p.type.trimmedDescription
                        
                        if type.hasPrefix("Binding<") {
                            return "lhs\(name).wrappedValue == rhs\(name).wrappedValue"
                        } else if type.contains("->") {
                            return "false" // Functions can't be compared
                        } else {
                            // For all other types including nested enums, just use ==
                            return "lhs\(name) == rhs\(name)"
                        }
                    }.joined(separator: " && ")
                    
                    return """
                    case (.\(caseName)(\(lhsBinds)), .\(caseName)(\(rhsBinds))):
                        return \(comps)
                    """
                } else {
                    return "case (.\(caseName), .\(caseName)): return true"
                }
            }
            
            let switchBody = caseBodies.joined(separator: "\n        ")
            return ["""
            public static func ==(lhs: \(raw: typeName), rhs: \(raw: typeName)) -> Bool {
                switch (lhs, rhs) {
                \(raw: switchBody)
                default: return false
                }
            }
            """]
            
        default:
            throw MacroError.message("@Equatable can only be applied to structs, classes, or enums")
        }
    }

    private static func makeEquatable(
        for typeName: String,
        members: MemberBlockItemListSyntax,
        isClass: Bool
    ) throws -> [DeclSyntax] {
        let storedProperties = members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { $0.bindingSpecifier.text == "let" || $0.bindingSpecifier.text == "var" }
            .flatMap { $0.bindings }
            .filter { $0.accessorBlock == nil }
            .map { $0.pattern.trimmedDescription }

        guard !storedProperties.isEmpty else {
            return ["""
            public static func ==(lhs: \(raw: typeName), rhs: \(raw: typeName)) -> Bool {
                return true
            }
            """]
        }

        let comparisons = storedProperties.map { property -> String in
            if isClass {
                return """
                guard lhs.\(property) == rhs.\(property) else {
                    return false
                }
                """
            } else {
                return "guard lhs.\(property) == rhs.\(property) else { return false }"
            }
        }.joined(separator: "\n")

        let typeCheck = isClass ? "guard type(of: lhs) == type(of: rhs) else { return false }\n" : ""
        
        return ["""
        public static func ==(lhs: \(raw: typeName), rhs: \(raw: typeName)) -> Bool {
            \(raw: typeCheck)\(raw: comparisons)
            return true
        }
        """]
    }
}


/// ——————————————————————
/// 3) Identifiable: adds `: Identifiable` via an extension
///    Works on structs, classes, and enums.
/// ——————————————————————
/// A macro that adds `Identifiable` conformance and optionally injects an `id` property.
/// A macro that adds `Identifiable` conformance and injects an optional `id` property if none exists.

public struct IdentifiableMacro: ExtensionMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) ||
              declaration.is(ClassDeclSyntax.self) ||
              declaration.is(EnumDeclSyntax.self) else {
            throw MacroError.message("@Identifiable can only be applied to structs, classes, or enums")
        }
        
        return [try ExtensionDeclSyntax("extension \(type.trimmed): Identifiable {}")]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard !hasExistingIDProperty(in: declaration) else {
            return []
        }
        
        let idType = try parseIDType(from: node)
        return [generateIDProperty(for: declaration, idType: idType)]
    }
    
    private static func hasExistingIDProperty(in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains { member in
            member.decl.as(VariableDeclSyntax.self)?.bindings.contains {
                $0.pattern.trimmedDescription == "id"
            } ?? false
        }
    }
    
    private static func parseIDType(from node: AttributeSyntax) throws -> String {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first else {
            return "String"
        }
        
        guard let typeExpr = firstArg.expression.as(MemberAccessExprSyntax.self),
              typeExpr.declName.baseName.text == "self",
              let base = typeExpr.base?.as(DeclReferenceExprSyntax.self) else {
            throw MacroError.message("Use format @Identifiable(idType: Type.self)")
        }
        
        return base.baseName.text
    }
    
    private static func generateIDProperty(
        for declaration: some DeclGroupSyntax,
        idType: String
    ) -> DeclSyntax {
        let isClass = declaration.is(ClassDeclSyntax.self)
        let isSimpleEnum = declaration.is(EnumDeclSyntax.self) &&
        !((declaration as? EnumDeclSyntax)?.hasAssociatedValues ?? false)
        
        if isSimpleEnum {
            return "public var id: Self { self }"
        }
        
        let (typeName, value) = idPropertyDetails(for: idType, isClass: isClass)
        let decl: String
        
        if isClass {
            decl = "public let id: \(typeName) = \(value)"
        } else {
            decl = "public var id: \(typeName) { \(value) }"
        }
        
        return DeclSyntax(stringLiteral: decl)
    }
    
    private static func idPropertyDetails(for typeName: String, isClass: Bool) -> (String, String) {
        switch typeName {
        case "String": return ("String", "UUID().uuidString")
        case "Int": return ("Int", "Int.random(in: 1..<Int.max)")
        case "Double": return ("Double", "Double.random(in: 0..<1)")
        case "Bool": return ("Bool", "Bool.random()")
        case "UUID": return ("UUID", "UUID()")
        default:
            let defaultValue = isClass ?
                "fatalError(\"Implement \(typeName) ID generation\")" :
                "{ fatalError(\"Implement \(typeName) ID generation\") }"
            return (typeName, defaultValue)
        }
    }
}

extension EnumDeclSyntax {
    var hasAssociatedValues: Bool {
        memberBlock.members.contains { member in
            member.decl.as(EnumCaseDeclSyntax.self)?.elements.contains {
                $0.parameterClause != nil
            } ?? false
        }
    }
}
