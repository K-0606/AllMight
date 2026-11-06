import SwiftUI
import UniformTypeIdentifiers

/// 把 `PhotosPicker` 選到的影片載到暫存檔，取得可讀的本機 URL。
///
/// 只用 PhotosPicker，不請求完整相簿權限（見 rule privacy-and-files）。
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            // 盡量用搬移避免整檔複製；跨 volume 無法搬移時回退為複製。
            do {
                try FileManager.default.moveItem(at: received.file, to: destination)
            } catch {
                try FileManager.default.copyItem(at: received.file, to: destination)
            }
            return PickedMovie(url: destination)
        }
    }
}
