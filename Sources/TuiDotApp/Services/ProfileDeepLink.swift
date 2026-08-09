import Foundation

enum ProfileDeepLink: Equatable, Sendable {
    case launch(UUID)

    static let scheme = "tuidotapp"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              url.host?.lowercased() == "launch"
        else {
            return nil
        }

        let rawID = url.pathComponents
            .filter { $0 != "/" }
            .first
        guard let rawID, let id = UUID(uuidString: rawID) else {
            return nil
        }
        self = .launch(id)
    }

    var url: URL {
        switch self {
        case let .launch(id):
            // UUIDs need no percent encoding, so this cannot smuggle query
            // parameters or commands into the launcher.
            return URL(string: "\(Self.scheme)://launch/\(id.uuidString)")!
        }
    }
}
