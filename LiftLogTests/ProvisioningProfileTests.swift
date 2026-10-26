import Foundation
import Testing
@testable import LiftLog

/// 設定頁最下方的簽署到期日
struct ProvisioningProfileTests {
    /// 模擬 embedded.mobileprovision：前後是簽章的二進位資料，中間是 plist
    private func profile(expiration: Date) throws -> Data {
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["Name": "iOS Team Provisioning Profile", "ExpirationDate": expiration],
            format: .xml, options: 0)
        return Data([0x30, 0x82, 0x3A, 0x00, 0x06, 0x09]) + plist + Data([0xA0, 0x82, 0x00, 0x3C, 0xFF])
    }

    @Test func readsTheExpirationDate() throws {
        let expiration = Date(timeIntervalSince1970: 1_793_000_000)
        #expect(ProvisioningProfile.expirationDate(in: try profile(expiration: expiration)) == expiration)
    }

    @Test func missingOrBrokenProfile() {
        #expect(ProvisioningProfile.expirationDate(in: Data()) == nil)
        #expect(ProvisioningProfile.expirationDate(in: Data("<?xml version=\"1.0\"?><plist>".utf8)) == nil)
    }

    @Test func daysLeftCountsCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        func date(_ month: Int, _ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
        }
        let now = date(10, 26, 23)
        #expect(ProvisioningProfile.daysLeft(until: date(11, 2, 9), from: now, calendar: calendar) == 7)
        #expect(ProvisioningProfile.daysLeft(until: date(10, 27, 1), from: now, calendar: calendar) == 1)
        #expect(ProvisioningProfile.daysLeft(until: date(10, 26, 23), from: date(10, 26, 8), calendar: calendar) == 0)
    }
}
