import Testing
@testable import VBTVision

@Test("VBTVision 佔位：能透過 VBTCore 讀到演算法版本")
func readsCoreAnalysisVersion() {
    #expect(VBTVision.coreAnalysisVersion == 2)
}
