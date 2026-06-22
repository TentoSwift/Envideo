import SwiftUI
import RealityKit
import RealityKitContent

enum ImmersiveIDs {
    static let cinema = "cinema"
    static let studio = "studio"
}

// MARK: - 視聴位置

enum CinemaRow: String, CaseIterable, Identifiable, Hashable {
    case front
    case middle
    case back

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .front:  return "前列"
        case .middle: return "中列"
        case .back:   return "後列"
        }
    }

    /// +z: シーンが手前に来る = スクリーンに近づく
    var zOffset: Float {
        switch self {
        case .front:  return 6
        case .middle: return 0    // デフォルト位置
        case .back:   return -5
        }
    }
}

enum CinemaTier: String, CaseIterable, Identifiable, Hashable {
    case floor
    case balcony

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .floor:   return "1階席"
        case .balcony: return "バルコニー席"
        }
    }

    /// -y: シーンが下がる = 座席が高くなる
    var yOffset: Float {
        switch self {
        case .floor:   return -0.8
        case .balcony: return -2.5
        }
    }
}

// MARK: - 共有状態

@MainActor
@Observable
final class CinemaState {
    static let shared = CinemaState()

    private static let rowKey = "seatRow"
    private static let tierKey = "seatTier"

    var row: CinemaRow = .middle {
        didSet { UserDefaults.standard.set(row.rawValue, forKey: Self.rowKey) }
    }
    var tier: CinemaTier = .floor {
        didSet { UserDefaults.standard.set(tier.rawValue, forKey: Self.tierKey) }
    }
    var isImmersiveOpen: Bool = false

    /// シーン全体を動かす量(ユーザーがその座席に座っているように見せる平行移動)
    /// 部屋とスクリーンが一緒に動くので位置関係は常に保たれる。
    var sceneOffset: SIMD3<Float> {
        SIMD3(0, tier.yOffset, row.zOffset)
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.rowKey),
           let saved = CinemaRow(rawValue: raw) {
            row = saved
        }
        if let raw = UserDefaults.standard.string(forKey: Self.tierKey),
           let saved = CinemaTier(rawValue: raw) {
            tier = saved
        }
    }
}

extension Notification.Name {
    static let cinemaImmersiveStateChanged = Notification.Name("cinemaImmersiveStateChanged")
}

// MARK: - Blender自作シーン

struct CinemaImmersiveView: View {
    @State private var state = CinemaState.shared

    var body: some View {
        RealityView { content in
            guard let scene = try? await Entity(named: "CinemaScene",
                                                in: realityKitContentBundle) else {
                return
            }
            scene.name = "LoadedCinema"
            CinemaImmersiveView.applyUnlit(to: scene)
            content.add(scene)
            // 初期座席: 部屋とスクリーンを丸ごと平行移動(瞬間移動なのでVR酔いしない)
            scene.position = state.sceneOffset
        } update: { content in
            for entity in content.entities where entity.name == "LoadedCinema" {
                entity.position = state.sceneOffset
            }
        }
        .onAppear {
            CinemaState.shared.isImmersiveOpen = true
            NotificationCenter.default.post(name: .cinemaImmersiveStateChanged, object: nil)
        }
        .onDisappear {
            CinemaState.shared.isImmersiveOpen = false
            NotificationCenter.default.post(name: .cinemaImmersiveStateChanged, object: nil)
        }
    }

    private static func applyUnlit(to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            let newMaterials: [any RealityKit.Material] = model.materials.map { mat in
                if let pbr = mat as? PhysicallyBasedMaterial {
                    var unlit = UnlitMaterial(color: pbr.baseColor.tint)
                    unlit.color = .init(tint: pbr.baseColor.tint,
                                        texture: pbr.baseColor.texture)
                    return unlit
                }
                return mat
            }
            model.materials = newMaterials
            entity.components.set(model)
        }
        for child in entity.children {
            applyUnlit(to: child)
        }
    }
}

// MARK: - スタジオ(暗転空間 + 可動スクリーン)

struct StudioImmersiveView: View {
    @State private var state = CinemaState.shared

    var body: some View {
        RealityView { content in
            // ドッキング領域だけの軽量シーン。部屋は無く、暗転空間にスクリーンが浮かぶ
            guard let scene = try? await Entity(named: "StudioScene",
                                                in: realityKitContentBundle) else {
                return
            }
            scene.name = "LoadedStudio"
            content.add(scene)
            // シネマと同じ方式: シーン全体を平行移動して座席位置を表現
            scene.position = state.sceneOffset
        } update: { content in
            for entity in content.entities where entity.name == "LoadedStudio" {
                entity.position = state.sceneOffset
            }
        }
        .onAppear {
            CinemaState.shared.isImmersiveOpen = true
            NotificationCenter.default.post(name: .cinemaImmersiveStateChanged, object: nil)
        }
        .onDisappear {
            CinemaState.shared.isImmersiveOpen = false
            NotificationCenter.default.post(name: .cinemaImmersiveStateChanged, object: nil)
        }
    }
}
