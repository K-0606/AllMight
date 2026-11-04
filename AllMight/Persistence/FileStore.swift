import Foundation

/// 統一管理 App 本機檔案的位置與刪除。所有影片與樣本檔的路徑都從這裡取得，
/// 不在別處自行組路徑（見 rule `privacy-and-files`）。
///
/// 檔案放在 `Application Support/`（`Videos/`、`Samples/`），不放 `Documents`，
/// 以免出現在「檔案」App。目錄不存在時會自動建立。
/// 標記 `nonisolated`：純檔案 I/O，需能從背景分析管線與主執行緒 ViewModel 兩邊呼叫，
/// 不綁定在專案預設的 MainActor 上。
nonisolated struct FileStore: Sendable {
    enum Kind: Sendable {
        case videos
        case samples

        var folderName: String {
            switch self {
            case .videos: "Videos"
            case .samples: "Samples"
            }
        }
    }

    /// 無儲存狀態；直接使用執行緒安全的 `FileManager.default`，讓此型別可從任何 context 呼叫。
    public init() {}

    /// 回傳指定類別的目錄，不存在時建立。
    func directory(for kind: Kind) throws -> URL {
        let fileManager = FileManager.default
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(kind.folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    /// 由檔名組出完整 URL（會確保目錄存在）。
    func url(for kind: Kind, fileName: String) throws -> URL {
        try directory(for: kind).appendingPathComponent(fileName, isDirectory: false)
    }

    /// 刪除單一檔案；檔案不存在時當作成功（不丟錯）。
    func delete(_ kind: Kind, fileName: String) throws {
        let url = try url(for: kind, fileName: fileName)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// 刪除一組紀錄對應的影片與樣本檔（見 rule `privacy-and-files`：刪紀錄要一併刪檔）。
    func deleteFiles(videoFileName: String, samplesFileName: String) throws {
        try delete(.videos, fileName: videoFileName)
        try delete(.samples, fileName: samplesFileName)
    }
}
