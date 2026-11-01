import Foundation
import UIKit

enum AppLinks {
    static let repository = URL(string: "https://github.com/OnlineKot/BlueTools")!
    static let releases = URL(string: "https://github.com/OnlineKot/BlueTools/releases")!
    static let latestRelease = URL(string: "https://api.github.com/repos/OnlineKot/BlueTools/releases/latest")!
    static let sourceString = "https://github.com/OnlineKot/BlueTools/releases/latest/download/source.json"
    static let source = URL(string: sourceString)!
    static let latestIPA = URL(string: "https://github.com/OnlineKot/BlueTools/releases/latest/download/BlueTools.ipa")!

    static var sideStore: URL {
        URL(string: "sidestore://source?url=\(sourceString)")!
    }

    static var liveContainer: URL {
        URL(string: "livecontainer://source?url=\(sourceString)")!
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}

struct ReleaseInfo: Equatable, Identifiable {
    var id: String { version }
    let version: String
    let notes: String
    let page: URL
    let ipa: URL?
    let published: Date?
}

final class UpdateChecker: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published var presented: ReleaseInfo?
    @Published var countdown: Countdown?
    @Published var missingInstaller: Installer?

    struct Countdown: Equatable {
        let info: ReleaseInfo
        let installer: Installer
        var seconds: Int
    }

    func install(_ info: ReleaseInfo, with installer: Installer) {
        let ipa = info.ipa ?? AppLinks.latestIPA
        guard let url = installer.url(ipa: ipa) else { return }
        countdown = nil
        ExternalApp.openAndQuit(url) { [weak self] in
            DispatchQueue.main.async { self?.missingInstaller = installer }
        }
    }

    func tick() {
        guard var current = countdown else { return }
        current.seconds -= 1
        if current.seconds <= 0 {
            install(current.info, with: current.installer)
        } else {
            countdown = current
        }
    }

    private let lastCheckKey = "lastUpdateCheck"
    private let skippedKey = "skippedVersion"

    var available: ReleaseInfo? {
        if case .available(let info) = status { return info }
        return nil
    }

    func checkOnLaunch(enabled: Bool) {
        guard enabled else { return }
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 600 else { return }
        Task { await check(manual: false) }
    }

    @MainActor
    func check(manual: Bool) async {
        status = .checking
        var request = URLRequest(url: AppLinks.latestRelease)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BlueTools/\(AppLinks.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                status = .upToDate
                return
            }
            let payload = try JSONDecoder.github.decode(GitHubRelease.self, from: data)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
            let version = payload.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard Self.isNewer(version, than: AppLinks.currentVersion) else {
                status = .upToDate
                return
            }
            let info = ReleaseInfo(
                version: version,
                notes: payload.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                page: payload.htmlURL,
                ipa: payload.assets.first { $0.name.lowercased().hasSuffix(".ipa") }?.browserDownloadURL ?? AppLinks.latestIPA,
                published: payload.publishedAt
            )
            status = .available(info)
            let skipped = UserDefaults.standard.string(forKey: skippedKey)
            guard manual || skipped != version else { return }
            let defaults = UserDefaults.standard
            let auto = defaults.object(forKey: PrefKey.autoInstall) as? Bool ?? true
            let installer = Installer(rawValue: defaults.string(forKey: PrefKey.installer) ?? "") ?? Installer.suggested
            if auto && !manual && installer != .ask {
                countdown = Countdown(info: info, installer: installer, seconds: 3)
            } else {
                presented = info
            }
        } catch {
            status = manual ? .failed("Couldn't reach GitHub.") : .idle
        }
    }

    func skip(_ info: ReleaseInfo) {
        UserDefaults.standard.set(info.version, forKey: skippedKey)
        presented = nil
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = parts(candidate)
        let rhs = parts(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { piece in
            Int(piece.prefix { $0.isNumber }) ?? 0
        }
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let body: String?
    let htmlURL: URL
    let publishedAt: Date?
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private extension JSONDecoder {
    static var github: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum ExternalApp {
    static func open(_ url: URL, completion: @escaping (Bool) -> Void = { _ in }) {
        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }

    static func openAndQuit(_ url: URL, failed: @escaping () -> Void) {
        UIApplication.shared.open(url, options: [:]) { ok in
            guard ok else {
                failed()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                exit(0)
            }
        }
    }

    static var isInsideLiveContainer: Bool {
        let path = Bundle.main.bundlePath
        let env = ProcessInfo.processInfo.environment
        return path.contains("/Documents/Applications/") || env.keys.contains { $0.hasPrefix("LC_") }
    }
}

enum Installer: String, CaseIterable, Identifiable {
    case ask
    case sideStore
    case liveContainer
    case altStore
    case trollStore
    case feather
    case safari

    var id: String { rawValue }

    static var choices: [Installer] { allCases.filter { $0 != .ask } }

    static var suggested: Installer {
        ExternalApp.isInsideLiveContainer ? .liveContainer : .ask
    }

    var title: String {
        switch self {
        case .ask: return "Ask every time"
        case .sideStore: return "SideStore"
        case .liveContainer: return "LiveContainer"
        case .altStore: return "AltStore"
        case .trollStore: return "TrollStore"
        case .feather: return "Feather"
        case .safari: return "Download IPA in Safari"
        }
    }

    var subtitle: String {
        switch self {
        case .ask: return "Show the list when an update is out"
        case .sideStore: return "Installs the new IPA directly"
        case .liveContainer: return "Installs the new IPA into LiveContainer"
        case .altStore: return "Installs the new IPA directly"
        case .trollStore: return "Installs permanently, no refresh needed"
        case .feather: return "Adds the BlueTools source"
        case .safari: return "Save the file and install it however you like"
        }
    }

    var symbol: String {
        switch self {
        case .ask: return "questionmark.circle"
        case .sideStore: return "s.circle.fill"
        case .liveContainer: return "shippingbox.fill"
        case .altStore: return "a.circle.fill"
        case .trollStore: return "t.circle.fill"
        case .feather: return "leaf.fill"
        case .safari: return "safari.fill"
        }
    }

    func url(ipa: URL) -> URL? {
        func scheme(_ name: String, _ host: String, _ value: String) -> URL? {
            var components = URLComponents()
            components.scheme = name
            components.host = host
            components.queryItems = [URLQueryItem(name: "url", value: value)]
            return components.url
        }
        switch self {
        case .ask: return nil
        case .sideStore: return scheme("sidestore", "install", ipa.absoluteString)
        case .liveContainer: return scheme("livecontainer", "install", ipa.absoluteString)
        case .altStore: return scheme("altstore", "install", ipa.absoluteString)
        case .trollStore: return scheme("apple-magnifier", "install", ipa.absoluteString)
        case .feather: return URL(string: "feather://source/\(AppLinks.sourceString)")
        case .safari: return ipa
        }
    }
}
