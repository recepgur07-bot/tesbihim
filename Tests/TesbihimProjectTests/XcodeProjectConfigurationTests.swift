import Testing
import Foundation
@testable import TesbihimApp

/// Info.plist / proje konfigürasyonunu doğrular — video recorder projesindeki
/// desenle tutarlı (bkz. PLAN.md Bölüm 10). `project.yml` değişince bu
/// testler beklenmedik regresyonları (ör. eksik UIApplicationSceneManifest)
/// erken yakalar.
struct XcodeProjectConfigurationTests {
    private var appBundle: Bundle { Bundle(for: BundleMarker.self) }
    private var info: [String: Any] { appBundle.infoDictionary ?? [:] }

    @Test func bundleIdentifierIsSet() {
        #expect(appBundle.bundleIdentifier == "com.recepgur.tesbihim")
    }

    @Test func displayNameIsTesbihim() {
        #expect(info["CFBundleDisplayName"] as? String == "Tesbihim")
    }

    @Test func doesNotDeclareNonExemptEncryption() {
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    @Test func privacyManifestIsBundled() {
        #expect(appBundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }
}
