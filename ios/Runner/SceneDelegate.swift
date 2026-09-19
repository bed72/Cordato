import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    let backgroundColor = UIColor { traits in
      if traits.userInterfaceStyle == .dark {
        return UIColor(
          red: 15.0 / 255.0,
          green: 21.0 / 255.0,
          blue: 17.0 / 255.0,
          alpha: 1.0
        )
      }

      return UIColor(
        red: 246.0 / 255.0,
        green: 251.0 / 255.0,
        blue: 244.0 / 255.0,
        alpha: 1.0
      )
    }
    window?.backgroundColor = backgroundColor
    window?.rootViewController?.view.backgroundColor = backgroundColor

    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      flutterViewController.isViewOpaque = false
      flutterViewController.setFlutterViewDidRenderCallback { [weak flutterViewController] in
        flutterViewController?.isViewOpaque = true
      }
    }
  }
}
