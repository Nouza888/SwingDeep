import SwiftUI
import UIKit

extension View {
    /// 指定した角だけを丸める
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    /// 発言者側の下端だけを角張らせたチャット吹き出し。
    func chatBubble(isMyMessage: Bool) -> some View {
        cornerRadius(
            16,
            corners: isMyMessage
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight]
        )
    }
}

/// 指定した角を丸めるためのShape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
