import Foundation
import Observation
import VBTCore

/// 影片設定頁的狀態：動作、重量（kg）、槓片直徑（cm）。記住上次的值（見 PRD §3.2）。
///
/// 重量只用 kg（D-014）；直徑預設 45 cm 標準，可切換自訂 20–50 cm。
@MainActor
@Observable
final class VideoSetupModel {
    /// 重量範圍與級距（kg）。
    static let minLoadKg = 1.0
    static let maxLoadKg = 500.0
    static let loadStepKg = 0.5
    /// 標準槓片直徑（cm）。
    static let standardDiameterCm = 45.0
    /// 自訂直徑範圍（cm）。
    static let minDiameterCm = 20.0
    static let maxDiameterCm = 50.0

    var exercise: Exercise
    var loadKg: Double
    var useStandardDiameter: Bool
    var customDiameterCm: Double

    /// 實際採用的槓片直徑（cm）：標準或自訂。
    var plateDiameterCm: Double {
        useStandardDiameter ? Self.standardDiameterCm : customDiameterCm
    }

    private let defaults: UserDefaults

    private enum Key {
        static let exercise = "setup.exerciseRaw"
        static let loadKg = "setup.loadKg"
        static let useStandardDiameter = "setup.useStandardDiameter"
        static let customDiameterCm = "setup.customDiameterCm"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 讀上次值；沒有就用合理預設。
        if let raw = defaults.string(forKey: Key.exercise), let saved = Exercise(rawValue: raw) {
            exercise = saved
        } else {
            exercise = .backSquat
        }
        let savedLoad = defaults.object(forKey: Key.loadKg) as? Double
        loadKg = savedLoad.map { Self.clampLoad($0) } ?? 20.0
        useStandardDiameter = defaults.object(forKey: Key.useStandardDiameter) as? Bool ?? true
        let savedDiameter = defaults.object(forKey: Key.customDiameterCm) as? Double
        customDiameterCm = savedDiameter.map { Self.clampDiameter($0) } ?? standardFallbackDiameter
    }

    /// 自訂直徑第一次的預設落在範圍內（用標準值）。
    private var standardFallbackDiameter: Double { Self.clampDiameter(Self.standardDiameterCm) }

    /// 把目前的值寫回 UserDefaults（在使用者進入下一步時呼叫）。
    func persist() {
        loadKg = Self.clampLoad(loadKg)
        customDiameterCm = Self.clampDiameter(customDiameterCm)
        defaults.set(exercise.rawValue, forKey: Key.exercise)
        defaults.set(loadKg, forKey: Key.loadKg)
        defaults.set(useStandardDiameter, forKey: Key.useStandardDiameter)
        defaults.set(customDiameterCm, forKey: Key.customDiameterCm)
    }

    static func clampLoad(_ value: Double) -> Double {
        min(max(value, minLoadKg), maxLoadKg)
    }

    static func clampDiameter(_ value: Double) -> Double {
        min(max(value, minDiameterCm), maxDiameterCm)
    }
}
