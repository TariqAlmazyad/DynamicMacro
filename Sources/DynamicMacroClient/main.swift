import DynamicMacro
import SwiftUI

// MARK: – Struct Example

/// A simple to-do item.
/// Conforms to Identifiable, Equatable & Hashable automatically.
@Equatable
@Hashable
@Identifiable
struct Task {
    var title: String
    var isDone: Bool
    var id: String = UUID().uuidString
}

func demoStruct() {
    let t1 = Task(title: "Write docs", isDone: false)
    let t2 = Task(title: "Write docs", isDone: false)
    print(t1 == t2)               // true, thanks to @Equatable
    print(Set([t1, t2]).count)    // 1, thanks to @Hashable
    print(t1.id)                  // UUID, synthesized by @Identifiable
}


// MARK: – Class Example

/// A model object in your app.
/// Only Equatable & Hashable – no automatic `id`.
@Equatable
@Hashable
class Widget {
    var uuid: UUID
    var name: String
    
    init(name: String) {
        self.uuid = UUID()
        self.name = name
    }
}

func demoClass() {
    let w1 = Widget(name: "Spinner")
    let w2 = Widget(name: "Spinner")
    print(w1 == w2)               // false, compares `uuid` + `name`
    print([w1, w2].hashValue)     // you can get a hashValue
}


// MARK: – Enum Example

/// Navigation targets in your SwiftUI app.
/// All associated values must themselves be Equatable/Hashable.
@Equatable
@Hashable
enum NavigationPage {
    case home
    case profile(userID: String)
    case settings
    case details(itemID: Int, title: String)
}

func demoEnum() {
    let p1 = NavigationPage.profile(userID: "abc123")
    let p2 = NavigationPage.profile(userID: "abc123")
    let p3 = NavigationPage.details(itemID: 42, title: "Answer")

    print(p1 == p2)               // true
    print(p1 == p3)               // false
    print(p3.hashValue)           // works out of the box
}


// MARK: – SwiftUI ViewModel Example

/// A view-model you might bind in your UI.
/// Conforms to Identifiable & Equatable.
@Equatable
@Identifiable
@Hashable
class CounterViewModel: ObservableObject {
    @Published var count: Int = 0
}

func demoViewModel() {
    let m1 = CounterViewModel()
    let m2 = CounterViewModel()
    print(m1 == m2)               // true, since both start at 0
    print(m1.id, m2.id)           // two different UUIDs
}


// MARK: – Using in Collections

func demoCollections() {
    let tasks: [Task] = [
        Task(title: "A", isDone: false),
        Task(title: "B", isDone: true),
        Task(title: "A", isDone: false)
    ]
    let unique = Set(tasks)       // duplicates removed
    print("Unique tasks:", unique.count)
}
