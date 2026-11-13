import Foundation
import Security

public enum FanControlResult: Int, Sendable {
    case automatic, maximum, external, unavailable, unsupported, busy, failed, stopped, unconfirmed, thermalPressure
}

@objc(TDFanControlService)
public protocol FanControlService {
    func status(reply: @escaping @Sendable (Int) -> Void)
    func maximum(reply: @escaping @Sendable (Int) -> Void)
    func automatic(reply: @escaping @Sendable (Int) -> Void)
}

public enum FanControlServiceIdentity {
    public static let helperSuffix = ".fan-control"

    public struct SigningIdentity {
        public let identifier: String
        let team: String

        /// Both ends pin the peer's identifier and the Apple-issued team of their own executable.
        public func peerRequirement(identifier: String) -> String? {
            guard FanControlServiceIdentity.validIdentifier(identifier),
                  identifier + FanControlServiceIdentity.helperSuffix == self.identifier ||
                    self.identifier + FanControlServiceIdentity.helperSuffix == identifier
            else { return nil }
            return "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
        }
    }

    public static func current() -> SigningIdentity? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let details = info as? [String: Any],
              let identifier = details[kSecCodeInfoIdentifier as String] as? String, validIdentifier(identifier),
              let team = details[kSecCodeInfoTeamIdentifier as String] as? String,
              team.utf8.count == 10, team.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) })
        else { return nil }
        return SigningIdentity(identifier: identifier, team: team)
    }

    private static func validIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty && identifier.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46
        }
    }
}
