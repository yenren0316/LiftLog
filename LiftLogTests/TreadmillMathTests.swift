import Foundation
import Testing
@testable import LiftLog

struct TreadmillMathTests {
    @Test func averageSpeedFromDistanceAndTime() {
        // 2 km / 30 分 = 4.0 km/h
        #expect(TreadmillMath.averageSpeed(distanceKm: 2, seconds: 1800) == 4.0)
        // 2.13 km / 30 分 = 4.26 → 4.3
        #expect(TreadmillMath.averageSpeed(distanceKm: 2.13, seconds: 1800) == 4.3)
    }

    @Test func invalidInputsGiveNil() {
        #expect(TreadmillMath.averageSpeed(distanceKm: nil, seconds: 1800) == nil)
        #expect(TreadmillMath.averageSpeed(distanceKm: 0, seconds: 1800) == nil)
        #expect(TreadmillMath.averageSpeed(distanceKm: 1, seconds: 30) == nil)
    }

    @Test func minutesRoundToNearest() {
        #expect(TreadmillMath.minutes(seconds: 1800) == 30)
        #expect(TreadmillMath.minutes(seconds: 1829) == 30)
        #expect(TreadmillMath.minutes(seconds: 1831) == 31)
    }
}
