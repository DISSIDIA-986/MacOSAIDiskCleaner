import Foundation

struct RuleMatcher: Sendable {
    struct Options: Sendable {
        /// 认为“活跃项目”的阈值（天）
        var activeProjectDays: Int = 30
        /// 用户白名单（永不清理/永不提示）
        var denylistPatterns: [String] = []
        /// 用户黑名单（强制标记为可清理）
        var allowlistPatterns: [String] = []
    }

    private let rules: [CleanupRule]
    private let options: Options

    init(rules: [CleanupRule], options: Options = .init()) {
        self.rules = rules
        self.options = options
    }

    func match(path: String) -> RuleMatch? {
        let standardized = (path as NSString).standardizingPath

        // denylist: 永不清理
        if matchesAnyGlob(standardized, patterns: options.denylistPatterns) {
            return nil
        }

        // allowlist: 强制命中一个“虚拟规则”
        if matchesAnyGlob(standardized, patterns: options.allowlistPatterns) {
            let forced = CleanupRule(
                id: "user.allowlist",
                name: "User allowlist",
                kind: .glob,
                pattern: "*",
                riskLevel: .low,
                priority: 2000,
                isUserDefined: true
            )
            return RuleMatch(rule: forced, isActiveProject: false, note: "Matched user allowlist")
        }

        var best: CleanupRule?
        for r in rules {
            if matches(rule: r, path: standardized) {
                if best == nil || r.priority > best!.priority {
                    best = r
                }
            }
        }
        guard let chosen = best else { return nil }

        // 项目活跃度：对 node_modules/DerivedData 这类“开发缓存”，活跃项目要降权提示
        let isActive = isLikelyActiveProject(forMatchedPath: standardized, rule: chosen)
        let note: String? = isActive ? "Project seems active (<\(options.activeProjectDays)d); treat as needs-review." : nil
        return RuleMatch(rule: chosen, isActiveProject: isActive, note: note)
    }

    // MARK: - Matching

    private func matches(rule: CleanupRule, path: String) -> Bool {
        switch rule.kind {
        case .glob:
            return GlobMatcher.match(path: path, pattern: rule.pattern)
        case .regex:
            return RegexMatcher.match(path: path, pattern: rule.pattern)
        }
    }

    private func matchesAnyGlob(_ path: String, patterns: [String]) -> Bool {
        for p in patterns where GlobMatcher.match(path: path, pattern: p) {
            return true
        }
        return false
    }

    // MARK: - Active project heuristic

    private func isLikelyActiveProject(forMatchedPath path: String, rule: CleanupRule) -> Bool {
        // 只对少数规则做活跃度判断
        let activeSensitiveRuleIds: Set<String> = ["node_modules", "xcode.deriveddata"]
        guard activeSensitiveRuleIds.contains(rule.id) else { return false }

        let url = URL(fileURLWithPath: path)
        var projectRoot: URL?

        if rule.id == "node_modules" {
            // 在 path 内向上找到 node_modules，再取其父目录作为项目根目录
            var cur = url
            for _ in 0..<12 {
                if cur.lastPathComponent == "node_modules" {
                    projectRoot = cur.deletingLastPathComponent()
                    break
                }
                let parent = cur.deletingLastPathComponent()
                if parent.path == cur.path { break }
                cur = parent
            }
            if projectRoot == nil {
                projectRoot = url.deletingLastPathComponent().deletingLastPathComponent()
            }
        } else {
            // DerivedData 路径结构比较复杂，这里只做弱判断：向上找一个含 .xcodeproj 或 .git 的目录
            projectRoot = findNearestProjectRoot(startingAt: url)
        }

        guard let root = projectRoot else { return false }
        let cutoff = Date().addingTimeInterval(TimeInterval(-options.activeProjectDays * 24 * 3600))

        let candidates: [URL] = [
            root.appendingPathComponent(".git/logs/HEAD"),
            root.appendingPathComponent("package-lock.json"),
            root.appendingPathComponent("pnpm-lock.yaml"),
            root.appendingPathComponent("yarn.lock"),
        ]

        for c in candidates {
            if let d = (try? c.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               d >= cutoff {
                return true
            }
        }
        return false
    }

    private func findNearestProjectRoot(startingAt url: URL) -> URL? {
        var cur = url
        for _ in 0..<8 {
            let fm = FileManager.default
            if fm.fileExists(atPath: cur.appendingPathComponent(".git").path) {
                return cur
            }
            if let items = try? fm.contentsOfDirectory(at: cur, includingPropertiesForKeys: nil),
               items.contains(where: { $0.pathExtension == "xcodeproj" }) {
                return cur
            }
            cur.deleteLastPathComponent()
        }
        return nil
    }
}

// MARK: - Core matchers

enum RegexMatcher {
    static func match(path: String, pattern: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        return re.firstMatch(in: path, options: [], range: range) != nil
    }
}

enum GlobMatcher {
    /// 简化 glob：
    /// - `**` 跨目录
    /// - `*` 单段（不跨 `/`）
    /// - `?` 单字符（不跨 `/`）
    static func match(path: String, pattern: String) -> Bool {
        let regex = globToRegex(pattern)
        return RegexMatcher.match(path: path, pattern: regex)
    }

    private static func globToRegex(_ glob: String) -> String {
        var out = "^"
        var i = glob.startIndex

        func advance(_ n: Int = 1) { i = glob.index(i, offsetBy: n) }

        while i < glob.endIndex {
            let ch = glob[i]

            if ch == "*" {
                // ** -> .*
                let next = glob.index(after: i)
                if next < glob.endIndex, glob[next] == "*" {
                    out += ".*"
                    advance(2)
                    continue
                }
                out += "[^/]*"
                advance()
                continue
            }

            if ch == "?" {
                out += "[^/]"
                advance()
                continue
            }

            // escape regex meta
            if "\\.^$|()[]{}+?".contains(ch) {
                out += "\\"
            }
            out += String(ch)
            advance()
        }

        out += "$"
        return out
    }
}

