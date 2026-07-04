import Foundation
import Security

/// Persists the trial's start date in the **Keychain** rather than
/// `UserDefaults`, so deleting and reinstalling the app can't reset the 14-day
/// trial (Keychain items survive app deletion). A `UserDefaults` copy is kept in
/// sync purely as a convenience for other readers (`ReviewGate`); the Keychain
/// value is always the source of truth.
enum TrialStore {
    private static let service = "com.fathom.TropiFish.trial"
    private static let account = "trialStartDate"
    /// Mirror key so `ReviewGate` (and debug tooling) can read the same value.
    static let mirrorKey = "trialStartDate"

    /// The stored trial start, or `nil` if never set on this device/Apple ID.
    static func loadStart() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let seconds = try? JSONDecoder().decode(Double.self, from: data) else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }

    /// Persist the trial start (Keychain source of truth + UserDefaults mirror).
    static func saveStart(_ date: Date) {
        UserDefaults.standard.set(date, forKey: mirrorKey)
        guard let data = try? JSONEncoder().encode(date.timeIntervalSince1970) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Upsert: remove any existing item, then add fresh.
        SecItemDelete(base as CFDictionary)
        var attributes = base
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// Resolve the effective start: Keychain wins; otherwise migrate a legacy
    /// UserDefaults value (from before this store existed); otherwise stamp
    /// `now` as the first-ever launch. Always leaves both stores populated.
    static func resolveStart(now: Date = Date()) -> Date {
        if let existing = loadStart() { return existing }
        let legacy = UserDefaults.standard.object(forKey: mirrorKey) as? Date
        let start = legacy ?? now
        saveStart(start)
        return start
    }
}
