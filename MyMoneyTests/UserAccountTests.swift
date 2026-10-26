import XCTest
import FirebaseCore
import FirebaseAuth
@testable import MyMoney

@MainActor
final class UserAccountTests: XCTestCase {
    func testAuthErrorsDoNotExposeCredentials() {
        let error = NSError(domain: AuthErrorDomain, code: AuthErrorCode.emailAlreadyInUse.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: "private@example.invalid secret"])
        let message = UserAccountManager.errorMessage(error)
        XCTAssertTrue(message.contains("già registrato"))
        XCTAssertFalse(message.contains("private@example.invalid"))
        XCTAssertFalse(message.contains("secret"))
    }

    func testRegistrationVerificationAndRestoredSessionAgainstLocalEmulator() async throws {
        let base = URL(string: "http://127.0.0.1:9099")!
        do { _ = try await URLSession.shared.data(from: base) }
        catch { throw XCTSkip("Local Firebase Auth emulator is not running") }
        let options = FirebaseOptions(googleAppID: "1:123456789:ios:0123456789abcdef", gcmSenderID: "123456789")
        options.apiKey = "demo-key-not-a-real-secret"
        options.projectID = "demo-mymoney"
        let appName = "account-tests-\(UUID().uuidString)"
        FirebaseApp.configure(name: appName, options: options)
        let app = try XCTUnwrap(FirebaseApp.app(name: appName))
        let auth = Auth.auth(app: app)
        auth.useEmulator(withHost: "127.0.0.1", port: 9099)
        let manager = UserAccountManager(authentication: auth)
        let email = "ios-\(UUID().uuidString.lowercased())@example.invalid"
        let password = "Local-test-password-123"
        await manager.register(name: "Utente QA", email: email, password: password)
        let user = try XCTUnwrap(manager.user)
        XCTAssertEqual(user.email, email)
        XCTAssertEqual(user.name, "Utente QA")
        XCTAssertFalse(user.emailVerified)
        let (codesData, _) = try await URLSession.shared.data(from: base.appendingPathComponent("emulator/v1/projects/demo-mymoney/oobCodes"))
        let codes = try XCTUnwrap((try JSONSerialization.jsonObject(with: codesData) as? [String: Any])?["oobCodes"] as? [[String: Any]])
        let code = try XCTUnwrap(codes.last(where: { $0["email"] as? String == email })?["oobCode"] as? String)
        var request = URLRequest(url: URL(string: "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-key-not-a-real-secret")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["oobCode": code])
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        await manager.refresh()
        XCTAssertEqual(manager.user?.emailVerified, true)
        let restored = UserAccountManager(authentication: auth)
        XCTAssertEqual(restored.user?.id, user.id)
        manager.signOut()
        XCTAssertNil(manager.user)
        await manager.signIn(email: email, password: password)
        XCTAssertEqual(manager.user?.id, user.id)
        XCTAssertEqual(manager.user?.emailVerified, true)
        // Dispose of only the synthetic emulator user created by this test.
        try await auth.currentUser?.delete()
    }
}
