**DynamicMacros**

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

https://github.com/user-attachments/assets/3d01065b-14ff-4ffc-a291-13788ad32042

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

### Struct: User Model with All Macros

**Before**:

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

**After**:

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

---

### Class: Authentication ViewModel

**Before**:

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

**After**:

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

#### Class with Binding: Theme Settings

```swift
@Equatable
@Hashable
class ThemeSettingsViewModel: ObservableObject {
    @Published var isDarkMode: Bool
    var toggleMode: Binding<Bool>

    init(isDarkMode: Bool, toggleMode: Binding<Bool>) {
        self.isDarkMode = isDarkMode
        self.toggleMode = toggleMode
    }
}
```

---

### Enum: App Screens Navigation

**Before**:

```swift
import SwiftUI

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

**After**:

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

*Perfect for enum-driven navigation in **Coordinator** flows.*

---

### Generic API Models & Binding

**Before**:

```swift
struct APIResponse<T> { let data: T }

struct SearchViewModel: Equatable, Hashable {
    let response: APIResponse<Article>
    var query: Binding<String>
    let statusCode: Int
}
```

**After**:

```swift
@Equatable
@Hashable
struct SearchViewModel {
    let response: APIResponse<Article>
    var query: Binding<String>
    let statusCode: Int
}
```

---

### Identifiable: User Profile Model

**Before**:

```swift
struct Profile: Identifiable {
    let id: UUID
    let name: String
}
```

**After**:

```swift
@Identifiable
struct Profile {
    let name: String
}
```

*Dynamically provides an `id: UUID` under the hood.*

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

---

> Made with ❤️ by [@talmazyad](https://github.com/talmazyad)
