import SwiftUI

struct SeatPickerView: View {
    @State private var state = CinemaState.shared

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(CinemaPosition.allCases) { pos in
                    Button {
                        state.position = pos
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: pos.systemImage)
                                .font(.system(size: 28))
                            Text(pos.localizedTitle)
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                        .frame(width: 130, height: 100)
                        .background {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(state.position == pos
                                      ? .white.opacity(0.25)
                                      : .white.opacity(0.08))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(state.position == pos
                                              ? .white
                                              : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }
}
