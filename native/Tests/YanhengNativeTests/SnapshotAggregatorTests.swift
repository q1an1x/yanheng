import XCTest
@testable import YanhengNative

final class SnapshotAggregatorTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-07-17T08:00:00Z")!

    func testHealthyPoolReportsAverageRemainingQuota() throws {
        let accounts = [
            pair(id: 1, usage5: 20, usage7: 40),
            pair(id: 2, usage5: 40, usage7: 20),
            pair(id: 3, usage5: 30, usage7: 30),
            pair(id: 4, usage5: 30, usage7: 30)
        ]
        let snapshot = SnapshotAggregator.aggregate(
            accounts: accounts,
            dashboard: dashboard(),
            config: YanhengConfig(),
            now: now
        )
        XCTAssertEqual(snapshot.level, "healthy")
        XCTAssertEqual(snapshot.availableAccounts, 4)
        XCTAssertEqual(snapshot.fiveHourRemaining, 70)
        XCTAssertEqual(snapshot.sevenDayRemaining, 70)
        XCTAssertEqual(snapshot.todayTokens, 600)
    }

    func testExhaustedWindowRequestsAccountSupplement() throws {
        var config = YanhengConfig()
        config.minimumAvailableAccounts = 1
        let snapshot = SnapshotAggregator.aggregate(
            accounts: [pair(id: 1, usage5: 92, usage7: 50)],
            dashboard: dashboard(),
            config: config,
            now: now
        )
        XCTAssertEqual(snapshot.level, "critical")
        XCTAssertEqual(snapshot.headline, "账号供给需要补充")
        XCTAssertEqual(snapshot.fiveHourRemaining, 8)
    }

    func testRateLimitedAccountIsUnavailable() throws {
        let account = Sub2APIAccount(
            id: 1,
            name: "limited",
            platform: "openai",
            status: "active",
            schedulable: true,
            errorMessage: nil,
            expiresAt: nil,
            rateLimitResetAt: "2026-07-17T09:00:00Z",
            overloadUntil: nil,
            tempUnschedulableUntil: nil,
            tempUnschedulableReason: nil
        )
        XCTAssertFalse(SnapshotAggregator.isAvailable(account, now: now))
    }

    private func pair(id: Int64, usage5: Double, usage7: Double) -> AccountWithUsage {
        AccountWithUsage(
            account: Sub2APIAccount(
                id: id, name: "account-\(id)", platform: "openai", status: "active", schedulable: true,
                errorMessage: nil, expiresAt: nil, rateLimitResetAt: nil, overloadUntil: nil,
                tempUnschedulableUntil: nil, tempUnschedulableReason: nil
            ),
            usage: AccountUsage(
                fiveHour: UsageWindow(utilization: usage5, resetsAt: nil),
                sevenDay: UsageWindow(utilization: usage7, resetsAt: nil),
                error: nil
            )
        )
    }

    private func dashboard() -> DashboardStats {
        DashboardStats(
            todayRequests: 10,
            todayInputTokens: 100,
            todayOutputTokens: 200,
            todayCacheCreationTokens: 100,
            todayCacheReadTokens: 200,
            todayTokens: 600,
            todayCost: 1.5,
            totalTokens: 12_000,
            rpm: 3,
            tpm: 900
        )
    }
}
