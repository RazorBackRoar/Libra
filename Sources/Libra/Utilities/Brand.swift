import Foundation

/// L!bra brand vs machine-safe ASCII identifiers.
///
/// Use `displayName` anywhere a human sees the product (UI, menus, Dock,
/// About, Application Support, `.app` / DMG names). Keep `githubRepo`,
/// `appId`, and `executableName` ASCII — GitHub, reverse-DNS, and Mach-O
/// names cannot use `!`.
enum Brand {
    static let displayName = "L!bra"
    static let githubRepo = "Libra"
    static let githubOrg = "RazorBackRoar"
    static let appId = "com.razorbackroar.libra"
    static let executableName = "Libra"
    static let organization = "RazorBackRoar"
    static let licenseText = "2026 RazorBackRoar"
    static let copyrightFull = "© 2026 RazorBackRoar. All rights reserved."
    static let architecture = "ARM64 (Apple Silicon)"
}
