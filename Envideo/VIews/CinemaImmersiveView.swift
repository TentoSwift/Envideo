import SwiftUI
import RealityKit
import RealityKitContent

enum ImmersiveIDs {
    static let cinema = "cinema"
    static let studio = "studio"
}

// MARK: - 視聴位置

enum CinemaPosition: String, CaseIterable, Identifiable, Hashable {
    case frontCenter
    case middleCenter

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .frontCenter:  return "最前列"
        case .middleCenter: return "中段・中央"
        }
    }

    var systemImage: String {
        switch self {
        case .frontCenter:  return "rectangle.inset.bottomleading.filled"
        case .middleCenter: return "rectangle.center.inset.filled"
        }
    }

    /// シーンを動かす量(ユーザーがそこに座っているように見せる平行移動)
    var sceneOffset: SIMD3<Float> {
        switch self {
        case .frontCenter:  return SIMD3( 0,  0,  6)   // 6m前進(画面に近づく)
        case .middleCenter: return SIMD3( 0,  0,  0)   // デフォルト位置
        }
    }
}

// MARK: - 共有状態

@MainActor
@Observable
final class CinemaState {
    static let shared = CinemaState()
    var position: CinemaPosition = .middleCenter
    var isImmersiveOpen: Bool = false
    private init() {}
}

extension Notification.Name {
    static let cinemaImmersiveStateChanged = Notification.Name("cinemaImmersiveStateChanged")
}

// MARK: - Blender自作シーン

struct CinemaImmersiveView: View {
    @State private var state = CinemaState.shared

    /// CinemaScene.usdaのVideo_Dockの初期位置(0, 5.5, -14)
    private static let videoDockOriginalPosition = SIMD3<Float>(0, 5.5, -14)

    var body: some View {
        RealityView { content in
            guard let scene = try? await Entity(named: "CinemaScene",
                                                in: realityKitContentBundle) else {
                return
            }
            scene.name = "LoadedCinema"
            CinemaImmersiveView.applyUnlit(to: scene)
            content.add(scene)
            // 初期: Video_Dockだけ位置調整(部屋は固定)
            CinemaImmersiveView.applyDockOffset(in: scene, offset: state.position.sceneOffset)
        } update: { content in
            for entity in content.entities where entity.name == "LoadedCinema" {
                CinemaImmersiveView.applyDockOffset(in: entity, offset: state.position.sceneOffset)
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

    private static func applyDockOffset(in scene: Entity, offset: SIMD3<Float>) {
        guard let dock = scene.findEntity(named: "Video_Dock") else { return }
        dock.position = videoDockOriginalPosition + offset
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

// MARK: - DestinationVideo Studio (Apple純正)

struct StudioImmersiveView: View {
    var body: some View {
        RealityView { content in
            guard let scene = try? await Entity(named: "AAA_MainScene",
                                                in: realityKitContentBundle) else {
                return
            }
            content.add(scene)
        }
    }
}
