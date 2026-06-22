import SwiftUI

struct SeatPickerView: View {
    @Bindable private var state = CinemaState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("環境")
                    .font(.headline)
                Picker("環境", selection: $state.environment) {
                    ForEach(CinemaEnvironment.allCases) { env in
                        Text(env.localizedTitle).tag(env)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("列")
                    .font(.headline)
                Picker("列", selection: $state.row) {
                    ForEach(CinemaRow.allCases) { row in
                        Text(row.localizedTitle).tag(row)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("高さ")
                    .font(.headline)
                Picker("高さ", selection: $state.tier) {
                    ForEach(CinemaTier.allCases) { tier in
                        Text(tier.localizedTitle).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .padding(.horizontal, 24)
    }
}
