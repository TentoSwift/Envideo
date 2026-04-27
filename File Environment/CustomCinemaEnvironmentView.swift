import SwiftUI
import RealityKit

struct CustomCinemaEnvironmentView: View {
    var body: some View {
        RealityView { content in
            // とりあえず「暗い空間」を作る最小例（本格的にはRCPの環境やスカイボックスに置き換え）
            let sphere = ModelEntity(mesh: .generateSphere(radius: 8))
            sphere.model?.materials = [UnlitMaterial(color: .black)]

            sphere.scale = .init(x: -1, y: 1, z: 1) // 内側を見えるように反転
            content.add(sphere)
        }
    }
}
