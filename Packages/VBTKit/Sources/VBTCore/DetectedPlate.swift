import Foundation

/// 一個偵測到的槓片框（來自 ML 物件偵測，見 docs/ALGORITHMS.md §9、DECISIONS D-033）。
///
/// 座標為 **Vision 正規化**（0–1，原點左下，轉正後影像），與 `PlateSelection` 同慣例。
/// 純值型別，不含 Vision 型別，數學可在 macOS `swift test`。
public struct DetectedPlate: Equatable, Sendable {
    /// 框中心 x（正規化，原點左下）。
    public var centerX: Double
    /// 框中心 y（正規化，原點左下）。
    public var centerY: Double
    /// 框寬（正規化）。
    public var width: Double
    /// 框高（正規化）。
    public var height: Double
    /// 偵測信心（0–1）。
    public var confidence: Double

    public init(centerX: Double, centerY: Double, width: Double, height: Double, confidence: Double) {
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.confidence = confidence
    }

    /// 點（正規化、原點左下）是否落在此框內。
    public func contains(x: Double, y: Double) -> Bool {
        abs(x - centerX) <= width / 2 && abs(y - centerY) <= height / 2
    }

    /// 由此框換算成 `PlateSelection`（比例尺用的 `diameterPx` 取**框高**）。
    ///
    /// 槓片是「直徑 45cm、厚度沿槓桿（水平）」的圓盤。側拍（相機大致水平、槓桿大致水平）時：
    /// **框高（垂直投影）＝真直徑**，與相機左右偏角、槓片厚度都無關；框寬會被透視壓縮（D·cosθ）
    /// 或被厚片的厚度灌水，不可靠。故取框高（見 docs/ALGORITHMS.md §9、DECISIONS D-033）。
    /// 相機俯拍／槓桿明顯傾斜等非常態下框高會失準，由使用者手動微調當後備；更通用可改橢圓長軸（列後續）。
    ///
    /// 註：手動圈路徑（`PlateCoordinates.diameterPixels`）以**框寬**軸換算直徑、此處用**框高**軸；
    /// 兩者都是「導向像素直徑」，在**正方形像素**（iPhone 影片恆成立）下等價。若日後出現非正方形像素
    /// 或 `Calibrator` 改各向異性縮放，需重新統一兩條路徑（見 DECISIONS D-033）。
    public func plateSelection(geometry: VideoGeometry) -> PlateSelection {
        let diameterPx = height * Double(geometry.heightPx)
        // 夾中心進 0–1，避免框極少數落在邊界外時圈跑出畫面。
        return PlateSelection(centerX: min(1, max(0, centerX)), centerY: min(1, max(0, centerY)), diameterPx: diameterPx)
    }

    /// 從偵測結果挑出使用者點到的槓片：點擊落在框內者中，取框中心最接近點擊的那個。
    ///
    /// 由使用者的手指解決「哪個框才是正在舉的槓片」（多槓片場景，見 DECISIONS D-033）。
    /// 點擊不落在任何框內回 `nil`（呼叫端退回手動圈）。
    public static func select(tapX: Double, tapY: Double, from plates: [DetectedPlate]) -> DetectedPlate? {
        plates
            .filter { $0.contains(x: tapX, y: tapY) }
            .min { hypot($0.centerX - tapX, $0.centerY - tapY) < hypot($1.centerX - tapX, $1.centerY - tapY) }
    }
}
