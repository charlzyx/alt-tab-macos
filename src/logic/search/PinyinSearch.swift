import Foundation

class PinyinSearch {
    static func convertToPinyin(_ text: String) -> String {
        // 简单的中文转拼音（实际项目中需要更完整的实现）
        // 这里只做示例，实际需要使用成熟的库
        return text
    }

    static func getPinyinFirstLetters(_ text: String) -> String {
        // 获取拼音首字母（实际项目中需要更完整的实现）
        return text
    }

    static func containsPinyin(_ text: String, query: String) -> Bool {
        let pinyin = convertToPinyin(text).lowercased()
        let pinyinFirstLetters = getPinyinFirstLetters(text).lowercased()
        let lowerQuery = query.lowercased()

        return pinyin.contains(lowerQuery) || pinyinFirstLetters.contains(lowerQuery)
    }

    static func searchScore(_ text: String, query: String) -> Double {
        let normalizedQuery = query.lowercased()
        let name = text.lowercased()
        let pinyin = convertToPinyin(text).lowercased()
        let firstLetters = getPinyinFirstLetters(text).lowercased()

        if name.contains(normalizedQuery) {
            return 1.0
        }
        if name.hasPrefix(normalizedQuery) {
            return 0.95
        }
        if pinyin.contains(normalizedQuery) {
            return 0.8
        }
        if firstLetters.contains(normalizedQuery) {
            return 0.7
        }

        return Search.smithWatermanSimilarity(query: normalizedQuery, text: name) * 0.6
    }
}

extension Search {
    static func searchApplications(_ apps: [InstalledApplication], query: String) -> [InstalledApplication] {
        if query.isEmpty {
            return apps
        }

        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let results = apps.filter { app in
            if app.isSystemApplication && !Preferences.showSystemApplicationsInLauncher {
                return false
            }

            let nameMatch = app.localizedName.lowercased().contains(normalizedQuery)
            let pinyinMatch = PinyinSearch.containsPinyin(app.localizedName, query: normalizedQuery)

            return nameMatch || pinyinMatch
        }

        return results.sorted { (lhs, rhs) -> Bool in
            let lhsScore = PinyinSearch.searchScore(lhs.localizedName, query: normalizedQuery)
            let rhsScore = PinyinSearch.searchScore(rhs.localizedName, query: normalizedQuery)

            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            return lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
        }
    }
}
