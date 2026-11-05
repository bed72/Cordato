import SwiftUI

struct WidgetActionView: View {
    let background: Color
    let foreground: Color
    let backgroundOpacity: Double

    var body: some View {
        Text("+ Nova despesa")
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(foreground)
            .background(background.opacity(backgroundOpacity), in: RoundedRectangle(cornerRadius: 14))
    }
}
