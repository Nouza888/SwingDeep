import SwiftUI

/// コーナーのカスタマイズ用ビュー拡張
///
/// ## 使用例
/// ```
/// .cornerRadius(16, corners: [.topLeft, .topRight])
/// ```
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// 特定の角だけ丸めるシェイプ
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
