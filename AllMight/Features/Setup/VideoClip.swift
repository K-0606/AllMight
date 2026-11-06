import Foundation
import VBTVision

/// 一段已通過檢查、可進入剪輯的影片：本機檔案位置與檢查結果。
///
/// 作為導覽路由的值傳遞，需 `Hashable`；以檔案 URL 作為識別。
struct VideoClip: Hashable {
    let url: URL
    let info: VideoInfo

    static func == (lhs: VideoClip, rhs: VideoClip) -> Bool {
        lhs.url == rhs.url && lhs.info == rhs.info
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
