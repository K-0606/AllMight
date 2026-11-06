import Testing
import Foundation
@testable import VBTCore

@Test("MVP 動作清單為 5 項")
func exerciseHasFiveCases() {
    #expect(Exercise.allCases.count == 5)
}

@Test("硬舉類起始相位為向心，蹲舉與臥推為離心")
func startsWithConcentricPerExercise() {
    #expect(Exercise.conventionalDeadlift.startsWithConcentric)
    #expect(Exercise.sumoDeadlift.startsWithConcentric)
    #expect(!Exercise.backSquat.startsWithConcentric)
    #expect(!Exercise.frontSquat.startsWithConcentric)
    #expect(!Exercise.benchPress.startsWithConcentric)
}

@Test("Exercise rawValue 可穩定往返編碼（存檔用）")
func exerciseRoundTripsThroughRawValue() throws {
    for exercise in Exercise.allCases {
        let restored = try #require(Exercise(rawValue: exercise.rawValue))
        #expect(restored == exercise)
    }
}

@Test("VideoGeometry 可 JSON 往返")
func videoGeometryRoundTripsThroughJSON() throws {
    let geometry = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
    let data = try JSONEncoder().encode(geometry)
    let restored = try JSONDecoder().decode(VideoGeometry.self, from: data)
    #expect(restored == geometry)
}
