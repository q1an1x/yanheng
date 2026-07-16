import Foundation

struct Sub2APIAccount: Decodable {
    let id: Int64
    let name: String
    let platform: String
    let status: String
    let schedulable: Bool
    let errorMessage: String?
    let expiresAt: Double?
    let rateLimitResetAt: String?
    let overloadUntil: String?
    let tempUnschedulableUntil: String?
    let tempUnschedulableReason: String?

    enum CodingKeys: String, CodingKey {
        case id, name, platform, status, schedulable
        case errorMessage = "error_message"
        case expiresAt = "expires_at"
        case rateLimitResetAt = "rate_limit_reset_at"
        case overloadUntil = "overload_until"
        case tempUnschedulableUntil = "temp_unschedulable_until"
        case tempUnschedulableReason = "temp_unschedulable_reason"
    }
}

struct UsageWindow: Decodable {
    let utilization: Double
    let resetsAt: String?
    enum CodingKeys: String, CodingKey { case utilization; case resetsAt = "resets_at" }
}

struct AccountUsage: Decodable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let error: String?
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case error
    }
}

struct DashboardStats: Decodable {
    let todayRequests: Int64
    let todayInputTokens: Int64
    let todayOutputTokens: Int64
    let todayCacheCreationTokens: Int64
    let todayCacheReadTokens: Int64
    let todayTokens: Int64
    let todayCost: Double
    let totalTokens: Int64
    let rpm: Int64
    let tpm: Int64

    enum CodingKeys: String, CodingKey {
        case todayRequests = "today_requests"
        case todayInputTokens = "today_input_tokens"
        case todayOutputTokens = "today_output_tokens"
        case todayCacheCreationTokens = "today_cache_creation_tokens"
        case todayCacheReadTokens = "today_cache_read_tokens"
        case todayTokens = "today_tokens"
        case todayCost = "today_cost"
        case totalTokens = "total_tokens"
        case rpm, tpm
    }
}

struct AccountWithUsage {
    let account: Sub2APIAccount
    let usage: AccountUsage?
}

struct YanhengSnapshot: Codable, Equatable {
    let generatedAt: String
    let level: String
    let headline: String
    let recommendation: String
    let totalAccounts: Int
    let availableAccounts: Int
    let unavailableAccounts: Int
    let errorAccounts: Int
    let rateLimitedAccounts: Int
    let availablePercent: Double
    let fiveHourRemaining: Double?
    let sevenDayRemaining: Double?
    let fiveHourReportingAccounts: Int
    let sevenDayReportingAccounts: Int
    let todayRequests: Int64
    let todayInputTokens: Int64
    let todayOutputTokens: Int64
    let todayCacheCreationTokens: Int64
    let todayCacheReadTokens: Int64
    let todayTokens: Int64
    let todayCost: Double
    let totalTokens: Int64
    let rpm: Int64
    let tpm: Int64
    let platformSummary: String
    let accountSummary: String
    let availabilityText: String
    let fiveHourText: String
    let sevenDayText: String
    let tokenText: String
    let trafficText: String

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case level, headline, recommendation
        case totalAccounts = "total_accounts"
        case availableAccounts = "available_accounts"
        case unavailableAccounts = "unavailable_accounts"
        case errorAccounts = "error_accounts"
        case rateLimitedAccounts = "rate_limited_accounts"
        case availablePercent = "available_percent"
        case fiveHourRemaining = "five_hour_remaining"
        case sevenDayRemaining = "seven_day_remaining"
        case fiveHourReportingAccounts = "five_hour_reporting_accounts"
        case sevenDayReportingAccounts = "seven_day_reporting_accounts"
        case todayRequests = "today_requests"
        case todayInputTokens = "today_input_tokens"
        case todayOutputTokens = "today_output_tokens"
        case todayCacheCreationTokens = "today_cache_creation_tokens"
        case todayCacheReadTokens = "today_cache_read_tokens"
        case todayTokens = "today_tokens"
        case todayCost = "today_cost"
        case totalTokens = "total_tokens"
        case rpm, tpm
        case platformSummary = "platform_summary"
        case accountSummary = "account_summary"
        case availabilityText = "availability_text"
        case fiveHourText = "five_hour_text"
        case sevenDayText = "seven_day_text"
        case tokenText = "token_text"
        case trafficText = "traffic_text"
    }
}

enum SnapshotAggregator {
    static func aggregate(
        accounts: [AccountWithUsage],
        dashboard: DashboardStats,
        config: YanhengConfig,
        now: Date = Date()
    ) -> YanhengSnapshot {
        let available = accounts.filter { isAvailable($0.account, now: now) }
        let unavailable = accounts.filter { !isAvailable($0.account, now: now) }
        let errorCount = accounts.filter { $0.account.status == "error" }.count
        let rateLimitedCount = accounts.filter { future($0.account.rateLimitResetAt, after: now) }.count
        let ratio = accounts.isEmpty ? 0 : Double(available.count) / Double(accounts.count) * 100

        let five = accounts.compactMap { $0.usage?.fiveHour?.utilization }.map { max(0, 100 - $0) }
        let seven = accounts.compactMap { $0.usage?.sevenDay?.utilization }.map { max(0, 100 - $0) }
        let fiveAverage = average(five)
        let sevenAverage = average(seven)

        let capacityCritical = available.count < config.minimumAvailableAccounts || ratio < config.minimumAvailablePercent
        let quotaCritical = [fiveAverage, sevenAverage].compactMap { $0 }.contains { $0 < config.warningRemainingPercent }
        let capacityWarning = available.count <= config.minimumAvailableAccounts + 1 || ratio < config.minimumAvailablePercent + 15
        let quotaWarning = [fiveAverage, sevenAverage].compactMap { $0 }.contains { $0 < config.warningRemainingPercent + 15 }

        let level: String
        let headline: String
        let recommendation: String
        if accounts.isEmpty {
            level = "critical"
            headline = "没有可监控的账号"
            recommendation = "请检查服务地址和管理员密钥，或先在 sub2api 中添加账号。"
        } else if capacityCritical || quotaCritical {
            level = "critical"
            headline = "账号供给需要补充"
            recommendation = "可用账号或滚动窗口余量已低于阈值，建议尽快补充账号并处理异常项。"
        } else if capacityWarning || quotaWarning || errorCount > 0 {
            level = "warning"
            headline = "账号余量偏紧"
            recommendation = "当前仍可服务，但应关注限流、异常账号和即将耗尽的用量窗口。"
        } else {
            level = "healthy"
            headline = "账号供给充足"
            recommendation = "可用账号与 5h/7d 平均余量均处于安全范围。"
        }

        let platforms = Dictionary(grouping: available, by: { $0.account.platform })
            .map { "\($0.key) \($0.value.count)" }
            .sorted()
            .joined(separator: "  ·  ")
        let issueLines = unavailable.prefix(6).map {
            "\($0.account.name)  ·  \(unavailableReason($0.account, now: now))"
        }

        return YanhengSnapshot(
            generatedAt: ISO8601DateFormatter().string(from: now),
            level: level,
            headline: headline,
            recommendation: recommendation,
            totalAccounts: accounts.count,
            availableAccounts: available.count,
            unavailableAccounts: unavailable.count,
            errorAccounts: errorCount,
            rateLimitedAccounts: rateLimitedCount,
            availablePercent: ratio,
            fiveHourRemaining: fiveAverage,
            sevenDayRemaining: sevenAverage,
            fiveHourReportingAccounts: five.count,
            sevenDayReportingAccounts: seven.count,
            todayRequests: dashboard.todayRequests,
            todayInputTokens: dashboard.todayInputTokens,
            todayOutputTokens: dashboard.todayOutputTokens,
            todayCacheCreationTokens: dashboard.todayCacheCreationTokens,
            todayCacheReadTokens: dashboard.todayCacheReadTokens,
            todayTokens: dashboard.todayTokens,
            todayCost: dashboard.todayCost,
            totalTokens: dashboard.totalTokens,
            rpm: dashboard.rpm,
            tpm: dashboard.tpm,
            platformSummary: platforms.isEmpty ? "暂无可用平台" : platforms,
            accountSummary: issueLines.isEmpty ? "所有账号均可调度" : issueLines.joined(separator: "\n"),
            availabilityText: "\(available.count) / \(accounts.count) 可用  ·  \(Int(ratio.rounded()))%",
            fiveHourText: quotaText(remaining: fiveAverage, count: five.count),
            sevenDayText: quotaText(remaining: sevenAverage, count: seven.count),
            tokenText: "输入 \(compact(dashboard.todayInputTokens))  ·  输出 \(compact(dashboard.todayOutputTokens))  ·  缓存读 \(compact(dashboard.todayCacheReadTokens))  ·  缓存写 \(compact(dashboard.todayCacheCreationTokens))",
            trafficText: "今日 \(compact(dashboard.todayTokens)) tokens / \(compact(dashboard.todayRequests)) 请求  ·  RPM \(dashboard.rpm)  ·  TPM \(compact(dashboard.tpm))"
        )
    }

    static func isAvailable(_ account: Sub2APIAccount, now: Date) -> Bool {
        guard account.status == "active", account.schedulable else { return false }
        if let expiresAt = account.expiresAt, expiresAt > 0, Date(timeIntervalSince1970: expiresAt) <= now { return false }
        if future(account.rateLimitResetAt, after: now) { return false }
        if future(account.overloadUntil, after: now) { return false }
        if future(account.tempUnschedulableUntil, after: now) { return false }
        return true
    }

    private static func future(_ value: String?, after now: Date) -> Bool {
        guard let value, let date = parsedDate(value) else { return false }
        return date > now
    }

    private static func parsedDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func unavailableReason(_ account: Sub2APIAccount, now: Date) -> String {
        if account.status == "error" { return account.errorMessage ?? "账号异常" }
        if account.status != "active" { return "未启用" }
        if future(account.rateLimitResetAt, after: now) { return "上游限流" }
        if future(account.overloadUntil, after: now) { return "上游过载" }
        if future(account.tempUnschedulableUntil, after: now) { return account.tempUnschedulableReason ?? "临时不可调度" }
        if !account.schedulable { return "已暂停调度" }
        return "当前不可用"
    }

    private static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func quotaText(remaining: Double?, count: Int) -> String {
        guard let remaining else { return "暂无上游窗口数据" }
        return "平均剩余 \(Int(remaining.rounded()))%  ·  \(count) 个账号"
    }

    private static func compact(_ value: Int64) -> String {
        if value >= 1_000_000_000 { return String(format: "%.1fB", Double(value) / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return String(value)
    }
}

final class Sub2APIClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) { self.session = session }

    func fetchSnapshot(config input: YanhengConfig) async throws -> YanhengSnapshot {
        var config = input
        config.normalize()
        guard !config.adminAPIKey.isEmpty else { throw ClientError.missingAPIKey }
        let normalizedConfig = config

        async let accounts = fetchAccounts(config: normalizedConfig)
        async let dashboard: DashboardStats = request(path: "/api/v1/admin/dashboard/stats", config: normalizedConfig)
        let (allAccounts, stats) = try await (accounts, dashboard)

        let accountUsage = await withTaskGroup(of: AccountWithUsage.self, returning: [AccountWithUsage].self) { group in
            var iterator = allAccounts.makeIterator()
            var results: [AccountWithUsage] = []
            for _ in 0..<min(8, allAccounts.count) {
                if let account = iterator.next() { addUsageTask(account, config: normalizedConfig, to: &group) }
            }
            while let result = await group.next() {
                results.append(result)
                if let account = iterator.next() { addUsageTask(account, config: normalizedConfig, to: &group) }
            }
            return results
        }
        return SnapshotAggregator.aggregate(accounts: accountUsage, dashboard: stats, config: normalizedConfig)
    }

    private func addUsageTask(
        _ account: Sub2APIAccount,
        config: YanhengConfig,
        to group: inout TaskGroup<AccountWithUsage>
    ) {
        group.addTask { [self] in
            let usage: AccountUsage? = try? await request(
                path: "/api/v1/admin/accounts/\(account.id)/usage?source=passive",
                config: config
            )
            return AccountWithUsage(account: account, usage: usage)
        }
    }

    private func fetchAccounts(config: YanhengConfig) async throws -> [Sub2APIAccount] {
        var page = 1
        var accounts: [Sub2APIAccount] = []
        while true {
            let result: Page<Sub2APIAccount> = try await request(
                path: "/api/v1/admin/accounts?page=\(page)&page_size=100&sort_by=name&sort_order=asc",
                config: config
            )
            accounts.append(contentsOf: result.items)
            if accounts.count >= result.total || result.items.isEmpty { return accounts }
            page += 1
        }
    }

    private func request<T: Decodable>(path: String, config: YanhengConfig) async throws -> T {
        guard let url = URL(string: config.baseURL + path) else { throw ClientError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(config.adminAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Yanheng/0.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? decoder.decode(APIEnvelope<T>.self, from: data),
               let message = envelope.message, !message.isEmpty {
                throw ClientError.api(message)
            }
            throw ClientError.http(http.statusCode)
        }
        let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
        guard envelope.code == 0, let result = envelope.data else {
            throw ClientError.api(envelope.message ?? "sub2api 返回错误")
        }
        return result
    }
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: T?
}

private struct Page<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
}

enum ClientError: LocalizedError {
    case missingAPIKey, invalidURL, invalidResponse, http(Int), api(String)
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "请先填写管理员 API Key"
        case .invalidURL: return "服务地址无效"
        case .invalidResponse: return "sub2api 返回了无效响应"
        case .http(let status): return "sub2api 请求失败（HTTP \(status)）"
        case .api(let message): return message
        }
    }
}
