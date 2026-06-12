import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "film.stack.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .padding(.bottom, 28)

            Text("無制限アンロック")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 12)

            Text("無料版は履歴\(StoreManager.historyLimit)件まで。\nアンロックすると動画を無制限に追加できます。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            ProductView(id: StoreManager.productID)
                .padding(.horizontal, 40)

            Button("購入を復元") {
                Task { await store.restore() }
            }
            .foregroundStyle(.secondary)
            .disabled(store.isLoading)
            .padding(.top, 16)

            Button("閉じる") { dismiss() }
                .foregroundStyle(.tertiary)
                .padding(.top, 20)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 420, minHeight: 500)
        .padding()
        .onChange(of: store.isPurchased) { _, purchased in
            if purchased { dismiss() }
        }
    }
}
