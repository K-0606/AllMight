import Foundation
import CoreGraphics
import ImageIO

/// 影片顯示方向，對應 `CGImagePropertyOrientation` 的八個值。
///
/// 由影片軌道的 `preferredTransform` 推導（見 skill video-pipeline §1）。
/// 轉正時把來源像素依此方向旋轉／鏡像，Vision 追蹤也用對應的 `cg` 值。
public enum VideoOrientation: Sendable, Equatable {
    case up, upMirrored, down, downMirrored, left, leftMirrored, right, rightMirrored

    /// 是否包含鏡像（前鏡頭拍攝時 transform 行列式為負）。
    public var isMirrored: Bool {
        switch self {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            return true
        case .up, .down, .left, .right:
            return false
        }
    }

    /// 對應的 `CGImagePropertyOrientation`，交給 Vision 使用。
    public var cg: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        }
    }

    /// 由軌道的 `preferredTransform` 推導方向。
    ///
    /// 旋轉角取自 `atan2`，四捨五入到最近的 90°；行列式為負代表含水平鏡像。
    /// 非鏡像的四個角度（0° 正、90° 直拍、180°、−90°）有單元測試覆蓋；
    /// 鏡像（前鏡頭）對應的 *Mirrored 變體依 `Rθ·水平翻轉` 慣例推導，
    /// 實際相簿影片格式需以真實前鏡頭影片在實機驗證。
    public static func from(transform t: CGAffineTransform) -> VideoOrientation {
        let determinant = t.a * t.d - t.b * t.c
        let mirrored = determinant < 0
        // 非鏡像：角度 = atan2(b, a)。
        // 鏡像（Rθ·水平翻轉）：cosθ = d、sinθ = −b，故角度 = atan2(−b, d)。
        let angle = mirrored ? atan2(-t.b, t.d) : atan2(t.b, t.a)
        let quarter = (((Int((angle / (.pi / 2)).rounded())) % 4) + 4) % 4
        switch (quarter, mirrored) {
        case (0, false): return .up
        case (1, false): return .right
        case (2, false): return .down
        case (3, false): return .left
        case (0, true): return .upMirrored
        case (1, true): return .rightMirrored
        case (2, true): return .downMirrored
        default: return .leftMirrored
        }
    }
}
