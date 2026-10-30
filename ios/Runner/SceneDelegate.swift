import Flutter
import UIKit
import GoogleSignIn

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      let url = context.url

      // Naver 로그인은 flutter_web_auth_2(ASWebAuthenticationSession)가
      // 콜백(qradar://auth/naver)을 세션 내부에서 자체 처리하므로
      // 여기서 별도 forwarding 이 필요 없다. (구 NidThirdPartyLogin SDK 제거됨)

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
