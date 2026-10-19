import Foundation
import os

/// Checks GitHub Releases for a newer version of MainMic.
///
/// Runs once at launch, every few hours after that, and again when the menu is
/// opened if the last answer is stale. Uses the public GitHub API (no token),
/// which allows 60 requests an hour per IP, far more than this ever needs.
@MainActor
final class UpdateChecker {
    enum Status: Equatable {
        case unknown
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    nonisolated static let repo = "seastwood/MainMic"
    nonisolated static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!

    /// The version baked into Info.plist (set from the git tag by the release workflow).
    nonisolated static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private(set) var status: Status = .unknown
    private(set) var lastChecked: Date?
    var onChange: (() -> Void)?

    private var timer: Timer?
    private let log = Logger(subsystem: "com.seastwood.mainmic", category: "update")

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    /// Re-checks if the last check is more than an hour old (or never happened).
    func checkIfStale() {
        if let last = lastChecked, Date().timeIntervalSince(last) < 60 * 60 { return }
        check()
    }

    func check() {
        guard status != .checking else { return }
        let previous = status
        status = .checking
        onChange?()

        Task {
            let result = await Self.fetchLatest()
            lastChecked = Date()
            switch result {
            case .success(let release):
                if Self.isNewer(release.tag, than: Self.currentVersion) {
                    status = .available(version: release.tag, url: release.url)
                    log.info("Update available: \(release.tag, privacy: .public)")
                } else {
                    status = .upToDate
                }
            case .failure(let error):
                log.error("Update check failed: \(error.localizedDescription, privacy: .public)")
                // Keep a known "update available" result rather than hiding it on a network blip.
                if case .available = previous { status = previous } else { status = .failed }
            }
            onChange?()
        }
    }

    // MARK: GitHub

    private struct LatestRelease: Decodable {
        let tag_name: String
        let html_url: String
    }

    private struct Release {
        let tag: String
        let url: URL
    }

    private enum CheckError: LocalizedError {
        case badResponse(Int)
        var errorDescription: String? {
            switch self {
            case .badResponse(let code): return "GitHub returned HTTP \(code)"
            }
        }
    }

    nonisolated private static func fetchLatest() async -> Result<Release, Error> {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MainMic/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else { return .failure(CheckError.badResponse(code)) }
            let latest = try JSONDecoder().decode(LatestRelease.self, from: data)
            let url = URL(string: latest.html_url) ?? releasesPage
            return .success(Release(tag: latest.tag_name, url: url))
        } catch {
            return .failure(error)
        }
    }

    // MARK: Version comparison

    /// "v1.10.2" → [1, 10, 2]. Anything non-numeric (like "dev") becomes [0].
    nonisolated static func components(_ version: String) -> [Int] {
        let trimmed = version.hasPrefix("v") || version.hasPrefix("V") ? String(version.dropFirst()) : version
        let core = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
        let parts = core.split(separator: ".").map { Int($0) ?? 0 }
        return parts.isEmpty ? [0] : parts
    }

    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = components(candidate), b = components(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
