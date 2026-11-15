import Foundation

enum LocalFanInstaller {
    static func prepare(app: URL, requirement: String) throws -> URL {
        let files = FileManager.default
        let directory = files.temporaryDirectory.appending(path: "ThermalDeck-FanHelper-\(UUID())")
        try files.createDirectory(at: directory, withIntermediateDirectories: false,
                                  attributes: [.posixPermissions: 0o700])
        let working = directory.appending(path: "Build")
        let package = directory.appending(path: "ThermalDeck Fan Helper.pkg")
        var prepared = false
        defer { try? files.removeItem(at: prepared ? working : directory) }

        let scripts = working.appending(path: "Scripts")
        try files.createDirectory(at: scripts, withIntermediateDirectories: true)
        let copiedApp = scripts.appending(path: "ThermalDeck.app")
        try run("/usr/bin/ditto", ["--norsrc", app.path, copiedApp.path])
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "-R", "=" + requirement, copiedApp.path])

        let resources = copiedApp.appending(path: "Contents/Resources/FanHelperInstaller")
        let postinstall = scripts.appending(path: "postinstall")
        try files.copyItem(at: resources.appending(path: "postinstall"), to: postinstall)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: postinstall.path)
        try run("/usr/bin/pkgbuild", [
            "--nopayload", "--scripts", scripts.path, "--identifier", "org.thermaldeck.local.fan-control.installer",
            "--version", "1", working.appending(path: "fan-helper.pkg").path
        ])
        try run("/usr/bin/productbuild", [
            "--distribution", resources.appending(path: "Distribution.xml").path,
            "--package-path", working.path, package.path
        ])
        prepared = true
        return package
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        let url = URL(filePath: executable)
        process.executableURL = url
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ThermalDeck.FanHelperInstaller", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(url.lastPathComponent) failed"])
        }
    }
}
