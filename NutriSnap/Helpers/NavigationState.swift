import Foundation

@Observable
final class NavigationState {
    static let shared = NavigationState()
    var shouldOpenAddFood = false
    private init() {}
}
