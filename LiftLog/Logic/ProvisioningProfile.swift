import Foundation

/// 免費 Apple ID 簽署的 App 七天後就打不開，要用 Xcode 重新安裝。
/// 到期日寫在 App 裡的 embedded.mobileprovision；模擬器沒有這個檔
nonisolated enum ProvisioningProfile {
    /// 這次安裝的到期日（安裝後不會變，讀一次就好）
    static let installedExpiration = expirationDate()

    static func expirationDate(bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return expirationDate(in: data)
    }

    /// 檔案是包著簽章的 plist，直接取出 <?xml … </plist> 那一段來讀
    static func expirationDate(in data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }

    /// 還剩幾個日曆天（今天到期為 0，已過期為負數）
    static func daysLeft(until expiration: Date, from now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiration)).day ?? 0
    }
}
