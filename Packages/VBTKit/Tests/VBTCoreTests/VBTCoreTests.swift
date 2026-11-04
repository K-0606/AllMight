import Testing
@testable import VBTCore

@Test("VBTCore 佔位：analysisVersion 預設為 1")
func analysisVersionIsOne() {
    #expect(VBTCore.analysisVersion == 1)
}
