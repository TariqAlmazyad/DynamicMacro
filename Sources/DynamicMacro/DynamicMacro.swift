@attached(member, names: named(hash))
@attached(extension, conformances: Hashable)
public macro Hashable() = #externalMacro(module: "DynamicMacroMacros", type: "HashableMacro")

@attached(member, names: named(==))
public macro Equatable() = #externalMacro(module: "DynamicMacroMacros", type: "EquatableMacro")

@attached(extension, conformances: Identifiable)
public macro Identifiable() = #externalMacro(module: "DynamicMacroMacros", type: "IdentifiableMacro")
