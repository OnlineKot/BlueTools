import Foundation
import UIKit

enum AppLinks {
    static let repository = URL(string: "https://github.com/OnlineKot/BlueTools")!
    static let releases = URL(string: "https://github.com/OnlineKot/BlueTools/releases")!
    static let latestRelease = URL(string: "https://api.github.com/repos/OnlineKot/BlueTools/releases/latest")!
    static let sourceString = "https://github.com/OnlineKot/BlueTools/releases/latest/download/source.json"
    static let source = URL(string: sourceString)!

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

    private let lastCheckKey = "lastUpdateCheck"
    private let skippedKey = "skippedVersion"

    var available: ReleaseInfo? {
        if case .available(let info) = status { return info }
        return nil
    }

    func checkOnLaunch(enabled: Bool) {
        guard enabled else { return }
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 6 * 3600 else { return }
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
                ipa: payload.assets.first { $0.name.lowercased().hasSuffix(".ipa") }?.browserDownloadURL,
                published: payload.publishedAt
            )
            status = .available(info)
            let skipped = UserDefaults.standard.string(forKey: skippedKey)
            if manual || skipped != version {
                presented = info
            }
        } catch {
            status = manual ? .failed("Nie udało się połączyć z GitHubem. Sprawdź internet i spróbuj jeszcze raz.") : .idle
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
}
