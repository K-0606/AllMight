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
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}
