import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.0, *)
struct WidgetRenderedActionView: View {
    let background: Color
    let foreground: Color
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var colorMode: WidgetColorMode {
        switch renderingMode {
        case .fullColor:
            return .fullColor
        case .accented:
            return .accented
        default:
            return .vibrant
        }
    }

    var body: some View {
        WidgetActionView(
            background: colorMode.usesSystemForeground ? .primary : background,
            foreground: colorMode.usesSystemForeground ? .primary : foreground,
            backgroundOpacity: colorMode.actionBackgroundOpacity
        )
    }
}
