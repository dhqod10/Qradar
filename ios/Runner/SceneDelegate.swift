import Flutter
import UIKit
import GoogleSignIn
import NidThirdPartyLogin

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      let url = context.url

      // Naver 로그인 callback (NidThirdPartyLogin SDK 직접 처리)
      if NidOAuth.shared.handleURL(url) {
        continue
      }

      // Google 로그인 callback (GoogleSignIn SDK 직접 처리)
      if GIDSignIn.sharedInstance.handle(url) {
        continue
      }

      // Kakao 로그인 callback —
      // kakao_flutter_sdk 는 iOS native SDK 를 import 하지 않고,
      // Flutter plugin 의 application(_:open:) 자체 구현으로 처리한다.
      // SceneDelegate URL → AppDelegate 의 application(_:open:) 로 forward.
      if let appDelegate = UIApplication.shared.delegate,
         appDelegate.application?(UIApplication.shared, open: url, options: [:]) == true {
        continue
      }
    }

    super.scene(scene, openURLContexts: URLContexts)
  }
}
