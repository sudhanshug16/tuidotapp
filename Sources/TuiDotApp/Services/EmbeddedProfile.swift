import Foundation

enum EmbeddedProfile {
    private static let key = "TuiDotAppProfileID"

    static var id: UUID? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        return UUID(uuidString: value)
    }

    static var isStandaloneProfileApp: Bool { id != nil }
}
