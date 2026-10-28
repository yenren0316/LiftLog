import Foundation

/// 首頁「近 30 天」的長條顏色：組數達到這個數量算練得夠（綠色）；0 組紅色，其他黃色。
/// 組數本身由 StatsCache 算（StatsSnapshot.recentSets）
nonisolated enum RecentVolume {
    static let enoughSets = 10
}
