/// The unit the user lifts in. Increments, plates, and dumbbells all follow it.
public enum WeightUnit: String, Sendable, Hashable, Codable, CaseIterable {
    case pounds
    case kilograms

    public var symbol: String {
        switch self {
        case .pounds: "lb"
        case .kilograms: "kg"
        }
    }
}
