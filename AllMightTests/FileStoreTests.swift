import Foundation
import Testing
@testable import AllMight

struct FileStoreTests {

    @Test("store 把來源檔複製進 Videos 目錄並可再刪除")
    func storesAndDeletesVideo() throws {
        let store = FileStore()

        // 準備一個暫存來源檔。
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        try Data([0x00, 0x01, 0x02]).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let fileName = UUID().uuidString + ".mov"
        let stored = try store.store(.videos, sourceURL: source, fileName: fileName)
        #expect(FileManager.default.fileExists(atPath: stored.path))

        try store.delete(.videos, fileName: fileName)
        #expect(!FileManager.default.fileExists(atPath: stored.path))
    }

    @Test("moveIn 把來源檔搬進 Videos 並移除來源")
    func movesVideoIn() throws {
        let store = FileStore()

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        try Data([0x00, 0x01, 0x02]).write(to: source)

        let fileName = UUID().uuidString + ".mov"
        let stored = try store.moveIn(.videos, sourceURL: source, fileName: fileName)
        defer { try? store.delete(.videos, fileName: fileName) }

        #expect(FileManager.default.fileExists(atPath: stored.path))
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }
}
