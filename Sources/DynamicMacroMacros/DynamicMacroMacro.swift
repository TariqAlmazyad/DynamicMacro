import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin
// Sources/DynamicMacrosMacros/DynamicMacrosMacro.swift

enum MacroError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self {
        case .message(let text): return text
        }
    }
}

@available(macOS 13.0, *)
@main
struct DynamicMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        HashableMacro.self,
        EquatableMacro.self,
        IdentifiableMacro.self,
    ]
}

/// ——————————————————————
/// 1) Hashable: adds `: Hashable` via an extension
///    Works on structs, classes, and enums.
/// ——————————————————————
public struct HashableMacro: MemberMacro {
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
            @available(macOS 13.0, *)
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
            @available(macOS 13.0, *)
            public func hash(into hasher: inout Hasher) {
                \(raw: hashBody)
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
                        } else if isClassType(type) {
                            return "hasher.combine(ObjectIdentifier(\(paramName)))"
                        } else {
                            return "hasher.combine(\(paramName))"
                        }
                    }.joined(separator: "\n        ")
                    
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
            @available(macOS 13.0, *)
            public func hash(into hasher: inout Hasher) {
                switch self {
                \(raw: hashStatements)
                }
            }
            """]
            
        default:
            throw MacroError.message("@DynamicHashable can only be applied to structs, classes, or enums")
        }
    }
    
    private static func isClassType(_ type: String) -> Bool {
        // Simple heuristic: if it starts with uppercase and isn't a known value type
        let knownValueTypes = ["Int", "String", "Bool", "Double", "Float", "Binding"]
        return type.first?.isUppercase == true && !knownValueTypes.contains(where: type.hasPrefix)
    }
}

extension HashableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let extensionDecl: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        @available(macOS 13.0, *)
        extension \(type.trimmed): Hashable {}
        """)
        return [extensionDecl]
    }
}


/// ——————————————————————
/// 2) Equatable: injects `static func ==(...)` + `: Equatable`
///    Works on structs, classes, and enums.
/// ——————————————————————
///
///

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
                            return "false"
                        } else if type.first?.isUppercase == true && !type.hasPrefix("Binding") {
                            return "(lhs\(name) as AnyObject) === (rhs\(name) as AnyObject)"
                        } else {
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
            throw MacroError.message(
                "@DynamicEquatable can only be applied to structs, classes, or enums"
            )
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
            .filter { $0.accessorBlock == nil } // Ignore computed properties
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
                if type(of: lhs.\(property)) != type(of: rhs.\(property)) {
                    return false
                }
                guard lhs.\(property) == rhs.\(property) else {
                    return false
                }
                """
            } else {
                return "guard lhs.\(property) == rhs.\(property) else { return false }"
            }
        }.joined(separator: "\n")
        
        return ["""
        public static func ==(lhs: \(raw: typeName), rhs: \(raw: typeName)) -> Bool {
            \(raw: comparisons)
            return true
        }
        """]
    }
}




/// ——————————————————————
/// 3) Identifiable: adds `: Identifiable` via an extension
///    Works on structs, classes, and enums.
/// ——————————————————————
public struct IdentifiableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self)
            || declaration.is(ClassDeclSyntax.self)
            || declaration.is(EnumDeclSyntax.self)
        else {
            throw MacroError.message("@Identifiable can only be applied to structs, classes, or enums")
        }
        return [ try ExtensionDeclSyntax("extension \(type.trimmed): Identifiable {}") ]
    }
}
