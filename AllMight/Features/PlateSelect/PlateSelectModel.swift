import Foundation
import Observation
import AVFoundation
import CoreGraphics
import VBTCore
import VBTVision

/// 點選槓片頁的狀態：起點幀影像、圓圈位置與直徑，並把圓圈換算成 `PlateSelection`（見 PRD §3.5）。
///
/// 圓圈以 view 點數（原點左上）表示；換算成 Vision 正規化圓心 + 轉正後像素直徑時，
/// 透過 `PlateCoordinates`（座標數學已在 VBTCore 測試，見 docs/ALGORITHMS.md §0、§1）。
/// 依 PRD §3.5：一開始沒有圓圈，使用者**點一下**槓片才出現圓圈，之後可拖曳與縮放。
@MainActor
@Observable
final class PlateSelectModel {
    let videoURL: URL
    /// 轉正後幾何（尺寸、fps），比例尺與座標換算都以此為準。
    let geometry: VideoGeometry
    let trimStartSeconds: Double
    let trimEndSeconds: Double

    /// 片段起點的轉正後影像；載入中為 nil。
    private(set) var startFrame: CGImage?
    /// 是否已放置圓圈（第一次點擊後為 true）。
    private(set) var isCirclePlaced = false
    /// 圓心（view 點數，原點左上）。
    var circleCenter: CGPoint = .zero
    /// 圓圈直徑（view 點數）。
    var circleDiameter: Double = 0
    /// 最近一次已知的容器尺寸，供工具列按鈕換算 `PlateSelection`。
    private(set) var containerSize: CGSize = .zero

    /// Stage 1（ML 偵測可視化，見 DECISIONS D-033）：起點幀偵測到的所有槓片框（純標記，不做吸附）。
    private(set) var detectedPlates: [DetectedPlate] = []
    /// 是否正在偵測（供畫面顯示「偵測中」）。
    private(set) var isDetecting = false
    /// 偵測失敗時的實際錯誤文字（nil = 沒失敗；暫時診斷用，確認可用後移除，見 DECISIONS D-033）。
    private(set) var detectionErrorText: String?
    /// Stage 2：使用者點選的槓片框（nil = 尚未選、或改為手動圈）；供畫面標示哪個被選。
    private(set) var selectedPlate: DetectedPlate?

    /// 預設圓圈直徑佔影像顯示寬度的比例（PRD §3.5：畫面寬的 18%）。
    private static let defaultDiameterFraction = 0.18
    /// 縮放時直徑可調整範圍（相對影像較短邊）。
    private static let minDiameterFraction = 0.05
    private static let maxDiameterFraction = 1.0
    /// 無障礙調整時每一步的縮放倍率。
    private static let accessibilityStep = 1.1

    init(videoURL: URL, geometry: VideoGeometry, trimStartSeconds: Double, trimEndSeconds: Double) {
        self.videoURL = videoURL
        self.geometry = geometry
        self.trimStartSeconds = trimStartSeconds
        self.trimEndSeconds = trimEndSeconds
    }

    convenience init(clip: VideoClip, trimStartSeconds: Double, trimEndSeconds: Double) {
        self.init(
            videoURL: clip.url,
            geometry: clip.info.geometry,
            trimStartSeconds: trimStartSeconds,
            trimEndSeconds: trimEndSeconds
        )
    }

    /// 載入片段起點的精確幀（已轉正）。
    func loadStartFrame() async {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let time = CMTime(seconds: trimStartSeconds, preferredTimescale: 600)
        startFrame = try? await generator.image(at: time).image
    }

    /// 影像在容器中以 aspect-fit 顯示的實際區域（扣掉 letterbox）。
    func imageRect(containerSize: CGSize) -> CGRect {
        let rect = PlateCoordinates.aspectFitRect(
            containerWidth: Double(containerSize.width),
            containerHeight: Double(containerSize.height),
            imageWidth: Double(geometry.widthPx),
            imageHeight: Double(geometry.heightPx)
        )
        return CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    /// 記錄容器尺寸（不放置圓圈；圓圈由使用者點擊才出現，見 PRD §3.5）。
    func updateContainer(size: CGSize) {
        containerSize = size
    }

    // MARK: - Stage 1：ML 偵測可視化（見 docs/ALGORITHMS.md §9、DECISIONS D-033）

    /// 對起點幀跑 ML 偵測，標記所有槓片框。純偵測＋標記，不做吸附、不改既有手動圈流程。
    /// 回空陣列＝模型跑了但沒偵測到；丟錯（模型載入/影片讀取失敗）→ `detectionFailed = true`，兩者分開供診斷。
    func detectPlates() async {
        isDetecting = true
        do {
            let plates = try await PlateDetector().detect(url: videoURL, atSeconds: trimStartSeconds)
            receiveDetectedPlates(plates)
            detectionErrorText = nil
        } catch {
            receiveDetectedPlates([])
            detectionErrorText = "\(error)"
        }
        isDetecting = false
    }

    /// 套用偵測結果（抽出供測試注入）；換新結果時清掉先前的選取。
    func receiveDetectedPlates(_ plates: [DetectedPlate]) {
        detectedPlates = plates
        selectedPlate = nil
    }

    /// 偵測框（Vision 正規化、原點左下）換算成 view 顯示矩形（原點左上），供畫面標記。
    func boxRect(for plate: DetectedPlate) -> CGRect {
        let rect = imageRect(containerSize: containerSize)
        let centerX = rect.minX + plate.centerX * rect.width
        let centerY = rect.minY + (1 - plate.centerY) * rect.height
        let w = plate.width * rect.width
        let h = plate.height * rect.height
        return CGRect(x: centerX - w / 2, y: centerY - h / 2, width: w, height: h)
    }

    // MARK: - Stage 2：點選偵測框（見 docs/ALGORITHMS.md §9、DECISIONS D-033）

    /// 點擊挑選:點到某偵測框 → 選它並把圈放上去；點空白處 → 維持現行手動放圈（清掉選取）。
    /// 偵測已在進頁完成、框已知,故這是**同步**命中測試,無吸附/非同步競態。
    func handleTap(at point: CGPoint) {
        let rect = imageRect(containerSize: containerSize)
        guard rect.width > 0, rect.height > 0 else { return }
        let tapX = (Double(point.x) - rect.minX) / rect.width
        let tapY = 1 - (Double(point.y) - rect.minY) / rect.height
        if let picked = DetectedPlate.select(tapX: tapX, tapY: tapY, from: detectedPlates) {
            selectPlate(picked)
        } else {
            selectedPlate = nil
            placeCircle(at: point)
        }
    }

    /// 直接選定某個偵測框:高亮它、並把圈設成該框換算出的圈（Stage 3 會再精修直徑換算）。
    func selectPlate(_ plate: DetectedPlate) {
        let circle = viewCircle(for: plate.plateSelection(geometry: geometry))
        guard circle.diameter > 0 else { return }
        selectedPlate = plate
        circleDiameter = circle.diameter
        isCirclePlaced = true
        moveCircle(to: circle.center) // 夾中心進影像範圍
    }

    /// `PlateSelection`（Vision 正規化圓心 + 像素直徑）換算成 view 顯示座標 + view 直徑
    /// （`currentSelection` 的逆，與 `TrackingPreviewModel.displayPoint` 同一套映射）。
    func viewCircle(for selection: PlateSelection) -> (center: CGPoint, diameter: Double) {
        let rect = imageRect(containerSize: containerSize)
        let center = CGPoint(
            x: rect.minX + selection.centerX * rect.width,
            y: rect.minY + (1 - selection.centerY) * rect.height
        )
        let diameter = (rect.width > 0 && geometry.widthPx > 0)
            ? selection.diameterPx / Double(geometry.widthPx) * Double(rect.width)
            : 0
        return (center, diameter)
    }

    /// 在指定點放置或移動圓心（夾在影像顯示區域內）。第一次放置時設定預設直徑。
    func placeCircle(at point: CGPoint) {
        let rect = imageRect(containerSize: containerSize)
        guard rect.width > 0 else { return }
        if !isCirclePlaced {
            circleDiameter = rect.width * Self.defaultDiameterFraction
            isCirclePlaced = true
        }
        moveCircle(to: point)
    }

    /// 把圓心移到指定點（夾在影像顯示區域內）。
    func moveCircle(to point: CGPoint) {
        let rect = imageRect(containerSize: containerSize)
        guard rect.width > 0 else { return }
        circleCenter = CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    /// 以倍率縮放圓圈直徑（夾在影像較短邊的比例範圍內）。
    func scaleCircle(by factor: Double) {
        let rect = imageRect(containerSize: containerSize)
        let shortSide = min(rect.width, rect.height)
        guard shortSide > 0 else { return }
        let proposed = circleDiameter * factor
        circleDiameter = min(
            max(proposed, shortSide * Self.minDiameterFraction),
            shortSide * Self.maxDiameterFraction
        )
    }

    // MARK: - 無障礙

    /// VoiceOver 無法拖曳：提供把圓圈放在影像中央的動作。
    func placeCircleAtImageCenter() {
        let rect = imageRect(containerSize: containerSize)
        placeCircle(at: CGPoint(x: rect.midX, y: rect.midY))
    }

    /// VoiceOver 調整：放大 / 縮小圓圈一步。
    func adjustDiameter(enlarge: Bool) {
        guard isCirclePlaced else { return }
        scaleCircle(by: enlarge ? Self.accessibilityStep : 1 / Self.accessibilityStep)
    }

    /// 目前圓圈直徑相對影像顯示寬度的百分比（供 VoiceOver 朗讀狀態）。
    func diameterPercentOfWidth() -> Int {
        let rect = imageRect(containerSize: containerSize)
        guard rect.width > 0 else { return 0 }
        return Int((circleDiameter / rect.width * 100).rounded())
    }

    /// 目前圓圈換算出的 `PlateSelection`（Vision 正規化圓心 + 轉正後像素直徑）。
    func currentSelection() -> PlateSelection {
        PlateCoordinates.selection(
            circleCenterViewX: Double(circleCenter.x),
            circleCenterViewY: Double(circleCenter.y),
            diameterPoints: Double(circleDiameter),
            imageRect: PlateCoordinates.aspectFitRect(
                containerWidth: Double(containerSize.width),
                containerHeight: Double(containerSize.height),
                imageWidth: Double(geometry.widthPx),
                imageHeight: Double(geometry.heightPx)
            ),
            orientedWidthPx: geometry.widthPx
        )
    }
}
