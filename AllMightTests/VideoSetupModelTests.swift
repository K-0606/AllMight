import Foundation
import Testing
import VBTCore
@testable import AllMight

@MainActor
struct VideoSetupModelTests {

    private func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite) ?? .standard
    }

    @Test("第一次使用給合理預設值")
    func firstLaunchDefaults() {
        let model = VideoSetupModel(defaults: makeDefaults())
        #expect(model.loadKg == 20.0)
        #expect(model.useStandardDiameter)
        #expect(model.plateDiameterCm == VideoSetupModel.standardDiameterCm)
    }

    @Test("persist 後重新建立會記住上次的值")
    func persistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = VideoSetupModel(defaults: defaults)
        first.exercise = .benchPress
        first.loadKg = 97.5
        first.useStandardDiameter = false
        first.customDiameterCm = 32
        first.persist()

        let second = VideoSetupModel(defaults: defaults)
        #expect(second.exercise == .benchPress)
        #expect(second.loadKg == 97.5)
        #expect(!second.useStandardDiameter)
        #expect(second.customDiameterCm == 32)
    }

    @Test("persist 會把超出範圍的重量夾到界線內")
    func clampsLoadOnPersist() {
        let model = VideoSetupModel(defaults: makeDefaults())
        model.loadKg = 1000
        model.persist()
        #expect(model.loadKg == VideoSetupModel.maxLoadKg)

        model.loadKg = 0
        model.persist()
        #expect(model.loadKg == VideoSetupModel.minLoadKg)
    }

    @Test("persist 會把超出範圍的自訂直徑夾到界線內")
    func clampsDiameterOnPersist() {
        let model = VideoSetupModel(defaults: makeDefaults())
        model.customDiameterCm = 90
        model.persist()
        #expect(model.customDiameterCm == VideoSetupModel.maxDiameterCm)
    }
}
