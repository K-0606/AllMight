import Testing
@testable import VBTCore

@Test("VBTCore：analysisVersion 為 2（M7 Q11 加相位時間欄位後升版）")
func analysisVersionIsTwo() {
    #expect(VBTCore.analysisVersion == 2)
}
