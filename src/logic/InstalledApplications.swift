import Cocoa
import UniformTypeIdentifiers

class InstalledApplications {
    static var list = [InstalledApplication]()
    static var cache = [String: InstalledApplication]()
    static let updateQueue = DispatchQueue(label: "com.lwouis.alt-tab-macos.installedApps", qos: .background)
    static var isInitialized = false

    struct InstalledApplication: Hashable, Equatable {
        let bundleIdentifier: String
        let bundleURL: URL
        let localizedName: String
        let executableURL: URL
        let icon: CGImage
        let lastModifiedDate: Date?
        let isSystemApplication: Bool

        var pinyin: String = ""
        var pinyinFirstLetters: String = ""

        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }

        static func ==(lhs: InstalledApplications.InstalledApplication, rhs: InstalledApplications.InstalledApplication) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
    }

    static func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        updateQueue.async {
            scanAllApplications()
        }
    }

    private static func scanAllApplications() {
        var applications = [InstalledApplication]()
        var tempCache = [String: InstalledApplication]()

        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(NSHomeDirectory())/Applications",
            "\(NSHomeDirectory())/Library/Application Support"
        ]

        for path in searchPaths {
            let url = URL(fileURLWithPath: path)
            if let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, error in
                    Logger.debug { "Failed to enumerate \(url.path): \(error.localizedDescription)" }
                    return true
                }
            ) {
                for case let fileURL as URL in enumerator {
                    if isValidApplicationBundle(fileURL) {
                        if let app = createInstalledApplication(from: fileURL) {
                            applications.append(app)
                            tempCache[app.bundleIdentifier] = app
                        }
                    }
                }
            }
        }

        var uniqueApplications = [InstalledApplication]()
        var seenBundleIds = Set<String>()

        for app in applications {
            if !seenBundleIds.contains(app.bundleIdentifier) {
                seenBundleIds.insert(app.bundleIdentifier)
                uniqueApplications.append(app)
            }
        }

        uniqueApplications.sort { (lhs, rhs) -> Bool in
            lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
        }

        list = uniqueApplications
        cache = tempCache

        Logger.info { "Scanned \(list.count) installed applications" }
    }

    private static func isValidApplicationBundle(_ url: URL) -> Bool {
        guard url.pathExtension == "app" else { return false }

        let contentsURL = url.appendingPathComponent("Contents")
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        let macosFolderURL = contentsURL.appendingPathComponent("MacOS")

        guard FileManager.default.fileExists(atPath: infoPlistURL.path),
              FileManager.default.fileExists(atPath: macosFolderURL.path) else {
            return false
        }

        if let infoDict = NSDictionary(contentsOf: infoPlistURL) {
            return infoDict["CFBundleExecutable"] != nil
        }

        return false
    }

    private static func createInstalledApplication(from url: URL) -> InstalledApplication? {
        guard let infoDict = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) else {
            return nil
        }

        guard let bundleIdentifier = infoDict["CFBundleIdentifier"] as? String,
              let bundleName = infoDict["CFBundleName"] as? String,
              let executableName = infoDict["CFBundleExecutable"] as? String else {
            return nil
        }

        let localizedName = Bundle(url: url)?.localizedInfoDictionary?["CFBundleName"] as? String ?? bundleName

        let contentsURL = url.appendingPathComponent("Contents")
        let macosURL = contentsURL.appendingPathComponent("MacOS")
        let executableURL = macosURL.appendingPathComponent(executableName)

        let icon = loadAppIcon(from: url, infoDict: infoDict)
        let lastModifiedDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date

        let isSystemApplication = isSystemApp(bundleIdentifier)

        var app = InstalledApplication(
            bundleIdentifier: bundleIdentifier,
            bundleURL: url,
            localizedName: localizedName,
            executableURL: executableURL,
            icon: icon,
            lastModifiedDate: lastModifiedDate,
            isSystemApplication: isSystemApplication
        )

        app.pinyin = PinyinSearch.convertToPinyin(localizedName)
        app.pinyinFirstLetters = PinyinSearch.getPinyinFirstLetters(localizedName)

        return app
    }

    private static func loadAppIcon(from appURL: URL, infoDict: NSDictionary) -> CGImage {
        let defaultIcon = CGImage.named("app.icns") ?? CGImage.black()

        guard let bundle = Bundle(url: appURL) else {
            return defaultIcon
        }

        if let iconFile = infoDict["CFBundleIconFile"] as? String {
            let iconName = iconFile.replacingOccurrences(of: ".icns", with: "")
            if let icon = bundle.image(forResource: NSImage.Name(iconName))?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                return icon
            }
            if let icon = bundle.image(forResource: NSImage.Name(iconFile))?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                return icon
            }
        }

        let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
        if let enumerator = FileManager.default.enumerator(
            at: resourcesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "icns" {
                    if let icon = NSImage(contentsOf: fileURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        return icon
                    }
                }
            }
        }

        return defaultIcon
    }

    private static func isSystemApp(_ bundleIdentifier: String) -> Bool {
        let systemPrefixes = [
            "com.apple.",
            "com.apple.dt.",
            "com.apple.system.",
            "com.apple.security.",
            "com.apple.driver."
        ]

        for prefix in systemPrefixes {
            if bundleIdentifier.starts(with: prefix) {
                return true
            }
        }

        return false
    }

    static func getAllApplications(includeSystemApps: Bool = Preferences.showSystemApplicationsInLauncher) -> [InstalledApplication] {
        if includeSystemApps {
            return list
        }
        return list.filter { !$0.isSystemApplication }
    }

    static func getRunningApplications() -> [InstalledApplication] {
        let runningApps = NSWorkspace.shared.runningApplications
        return list.filter { app in
            runningApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
        }
    }

    static func searchApplications(_ query: String) -> [InstalledApplication] {
        if query.isEmpty {
            return getAllApplications()
        }

        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        return list.filter { app in
            if app.isSystemApplication && !Preferences.showSystemApplicationsInLauncher {
                return false
            }

            let nameMatch = app.localizedName.lowercased().contains(normalizedQuery)
            let pinyinMatch = app.pinyin.contains(normalizedQuery)
            let pinyinFirstLettersMatch = app.pinyinFirstLetters.contains(normalizedQuery)

            return nameMatch || pinyinMatch || pinyinFirstLettersMatch
        }
    }

    @discardableResult
    static func launchApplication(_ app: InstalledApplication) -> Bool {
        do {
            let configuration = NSWorkspace.OpenConfiguration()
            _ = try NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: configuration)
            return true
        } catch {
            Logger.error { "Failed to launch \(app.localizedName): \(error.localizedDescription)" }
            return false
        }
    }

    static func refresh(completion: (() -> Void)? = nil) {
        updateQueue.async {
            scanAllApplications()
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
}
