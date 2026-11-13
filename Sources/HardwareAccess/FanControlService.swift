import Darwin
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
    public static let localApp = "org.thermaldeck.local"
    public static let localHelper = localApp + helperSuffix

    public struct SigningIdentity {
        public let identifier: String
        public let team: String?
        public let cdHash: String

        /// Both ends pin the peer's identifier and the Apple-issued team of their own executable.
        public func peerRequirement(identifier: String) -> String? {
            guard let team, FanControlServiceIdentity.validIdentifier(identifier),
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
              let hash = details[kSecCodeInfoUnique as String] as? Data, hash.count == 20
        else { return nil }
        let team = (details[kSecCodeInfoTeamIdentifier as String] as? String).flatMap { value in
            value.utf8.count == 10 && value.utf8.allSatisfy { (65...90).contains($0) || (48...57).contains($0) }
                ? value : nil
        }
        return SigningIdentity(identifier: identifier, team: team, cdHash: hash.map { String(format: "%02x", $0) }.joined())
    }

    public struct LocalInstallation: Decodable {
        public let appCDHash: String
        public let helperCDHash: String

        public static func read() -> LocalInstallation? {
            let library = open("/Library", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard library >= 0 else { return nil }
            defer { close(library) }
            guard isProtected(library) else { return nil }

            let directory = openat(library, "PrivilegedHelperTools", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard directory >= 0 else { return nil }
            defer { close(directory) }
            guard isProtected(directory) else { return nil }

            let descriptor = openat(directory, localHelper + ".plist", O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
            guard descriptor >= 0 else { return nil }
            let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            var info = stat()
            guard fstat(descriptor, &info) == 0, info.st_uid == 0,
                  info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o022 == 0,
                  (1...4096).contains(info.st_size),
                  let data = try? file.read(upToCount: 4096), data.count == Int(info.st_size),
                  let installation = try? PropertyListDecoder().decode(Self.self, from: data),
                  validHash(installation.appCDHash), validHash(installation.helperCDHash) else { return nil }
            return installation
        }

        private static func isProtected(_ descriptor: Int32) -> Bool {
            var info = stat()
            return fstat(descriptor, &info) == 0 && info.st_uid == 0 && info.st_mode & 0o022 == 0
        }
    }

    public static func exactRequirement(identifier: String, cdHash: String) -> String? {
        guard validIdentifier(identifier), validHash(cdHash) else { return nil }
        return "identifier \"\(identifier)\" and cdhash H\"\(cdHash)\""
    }

    private static func validHash(_ value: String) -> Bool {
        value.utf8.count == 40 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func validIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty && identifier.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46
        }
    }
}
