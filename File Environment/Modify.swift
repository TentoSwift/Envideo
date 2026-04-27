//
//  Modigy.swift
//  File Environment
//
//  Created by 石野天斗 on 2026/02/22.
//


import SwiftUI

func formatTimestamp(_ seconds: Double) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                 : String(format: "%d:%02d", m, s)
}

extension View {
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}

public struct BlurBackgroundView: View {
  public init() {}

  let maxHeight: CGFloat = 160

  public var body: some View {
    ZStack {
      Color.clear
        .background(.regularMaterial)
        .frame(maxWidth: .infinity, maxHeight: maxHeight)

      LinearGradient(
        gradient: Gradient(colors: [.black.opacity(0), .black]),
        startPoint: .top,
        endPoint: .bottom
      )
      .blendMode(.destinationOut)
      .frame(maxWidth: .infinity, maxHeight: maxHeight)
    }
    .compositingGroup()
    .frame(maxHeight: maxHeight)
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}

extension View {
    @ViewBuilder
    public func blurNavigationBar() -> some View {
        ZStack(alignment: .top) {
            self
            BlurBackgroundView()
        }
    }
}
