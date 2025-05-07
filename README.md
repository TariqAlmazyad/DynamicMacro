# DynamicMacros

![Swift Version](https://img.shields.io/badge/Swift-5.8+-orange.svg) ![License](https://img.shields.io/badge/License-MIT-blue.svg)

A Swift Package that provides dynamic macro annotations to automatically synthesize `Equatable`, `Hashable`, `Identifiable`, and other common protocol conformances for **structs**, **classes**, **enums**, and **Coordinator**-based architectures—including full support for SwiftUI `Binding<T>` properties and enum cases.

---

## 🚀 Features

* **Zero-Boilerplate**: Eliminate repetitive `==` and `hash(into:)` implementations
* **Multi-Type Support**: Works on `struct`, `class`, and `enum`
* **Coordinator-Ready**: Seamlessly integrate with Coordinator architectures for navigation enums
* **Binding Support**: Recognizes and handles `Binding<T>` in stored properties, enum payloads, and class fields
* **Identifiable Support**: Automatically synthesizes an `id` property for `Identifiable` conformance in structs and classes
* **Extensible**: Easily add support for more protocols in the future

---

## 📦 Installation

Add **DynamicMacros** to your project using Swift Package Manager:

```swift
// In Xcode: File ▶️ Add Packages... ▶️ https://github.com/talmazyad/DynamicMacros

// Or in Package.swift:
dependencies: [
    .package(url: "https://github.com/talmazyad/DynamicMacros", from: "1.0.0")
]
```

Then import in your code:

```swift
import DynamicMacros
```

---

## 🔨 Usage Examples

### Enum: App Screens Navigation

<details>
<summary><strong>Before</strong></summary>

```swift
enum AppScreen: Equatable, Hashable {
    case dashboard
    case userProfile(username: String)
    case messages(count: Int)
    case settings
    case courseDetail(courseId: Int)
    case auth(viewModel: AuthViewModel)
    case themeMode(binding: Binding<Bool>)

    var title: String {
        switch self {
        case .dashboard:      return "Dashboard"
        case .userProfile:    return "Profile"
        case .messages:       return "Messages"
        case .settings:       return "Settings"
        case .courseDetail:   return "Course Detail"
        case .auth:           return "Authentication"
        case .themeMode:      return "Theme"
        }
    }

    // MARK: - Equatable
    static func ==(lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.dashboard, .dashboard), (.settings, .settings):
            return true
        case let (.userProfile(a), .userProfile(b)):
            return a == b
        case let (.messages(a), .messages(b)):
            return a == b
        case let (.courseDetail(a), .courseDetail(b)):
            return a == b
        case let (.auth(a), .auth(b)):
            return ObjectIdentifier(a) == ObjectIdentifier(b)
        case let (.themeMode(a), .themeMode(b)):
            return a.wrappedValue == b.wrappedValue
        default:
            return false
        }
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .dashboard:
            hasher.combine(0)
        case .settings:
            hasher.combine(1)
        case let .userProfile(name):
            hasher.combine(2); hasher.combine(name)
        case let .messages(count):
            hasher.combine(3); hasher.combine(count)
        case let .courseDetail(id):
            hasher.combine(4); hasher.combine(id)
        case let .auth(vm):
            hasher.combine(5); hasher.combine(ObjectIdentifier(vm))
        case let .themeMode(binding):
            hasher.combine(6); hasher.combine(binding.wrappedValue)
        }
    }
}
```

</details>

<details>
<summary><strong>After</strong></summary>

```swift
@Equatable
@Hashable
enum AppScreen {
    case dashboard
    case userProfile(username: String)
    case messages(count: Int)
    case settings
    case courseDetail(courseId: Int)
    case auth(viewModel: AuthViewModel)
    case themeMode(binding: Binding<Bool>)

    var title: String {
        switch self {
        case .dashboard:      return "Dashboard"
        case .userProfile:    return "Profile"
        case .messages:       return "Messages"
        case .settings:       return "Settings"
        case .courseDetail:   return "Course Detail"
        case .auth:           return "Authentication"
        case .themeMode:      return "Theme"
        }
    }
}
```

</details>

---

### Struct: User Model with All Macros

<details>
<summary><strong>Before</strong></summary>

```swift
struct User: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let email: String

    // Equatable
    static func ==(lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.email == rhs.email
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(email)
    }
}
```

</details>

<details>
<summary><strong>After</strong></summary>

```swift
@Identifiable
@Equatable
@Hashable
struct User {
    let id: UUID
    let name: String
    let email: String
}
```

</details>

---

### Class: Authentication ViewModel

<details>
<summary><strong>Before</strong></summary>

```swift
class AuthViewModel: ObservableObject, Equatable, Hashable {
    @Published var token: String
    let userId: UUID

    init(token: String, userId: UUID) {
        self.token = token
        self.userId = userId
    }

    static func ==(lhs: AuthViewModel, rhs: AuthViewModel) -> Bool {
        return lhs.userId == rhs.userId && lhs.token == rhs.token
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
        hasher.combine(token)
    }
}
```

</details>

<details>
<summary><strong>After</strong></summary>

```swift
@Equatable
@Hashable
class AuthViewModel: ObservableObject {
    @Published var token: String
    let userId: UUID

    init(token: String, userId: UUID) {
        self.token = token
        self.userId = userId
    }
}
```

</details>

---

### 🔖 `@Identifiable` Usage

Automatically inject an `id` property of any supported type—no boilerplate required.

#### 1. Default `UUID` id

```swift
@Identifiable
struct Task {
    var title: String
    var isDone: Bool
}

// → provides:
// var id: UUID { UUID() }
```

#### 2. Custom `String` id

```swift
@Identifiable(idType: String.self)
struct Task {
    var title: String
    var isDone: Bool
    var id: String = UUID().uuidString
}
```

#### 3. Other built-in id types

```swift
@Identifiable(idType: Bool.self)
struct FeatureToggle {
    var name: String
    var isEnabled: Bool
    var id: Bool = true
}

@Identifiable(idType: Int.self)
struct UserProfile {
    var username: String
    var age: Int
    var id: Int = Int.random(in: 1...1_000_000)
}
```

#### 4. Custom id type

```swift
struct CustomID: RawRepresentable, Hashable {
    var rawValue: String
}

@Identifiable(idType: CustomID.self)
struct Resource {
    var url: String
    var id: CustomID = CustomID(rawValue: UUID().uuidString)
}
```

---

## 💡 Why DynamicMacros?

* **Reduce Boilerplate**: Focus on your app logic, not repetitive code.
* **Maintainability**: One macro annotation keeps your models consistent.
* **Coordinator-Friendly**: Perfect for enum-based navigation in MVVM+Coordinator.

---

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch
3. Submit a PR

---

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

> Made with ❤️ by [@talmazyad](https://github.com/talmazyad)
