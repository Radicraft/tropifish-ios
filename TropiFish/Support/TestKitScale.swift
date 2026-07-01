import Foundation

/// Discrete colour-chart increments for the API Freshwater Master Test Kit
/// (brief §4.2, a decided default in §10). Entry offers exactly these steps so
/// the number the user taps matches the tube they're comparing against, which is
/// what keeps a full 7-parameter log under 30 seconds.
enum TestKitScale {
    /// Total ammonia (TAN), ppm.
    static let ammonia: [Double] = [0, 0.25, 0.5, 1, 2, 4, 8]
    /// Nitrite, ppm.
    static let nitrite: [Double] = [0, 0.25, 0.5, 1, 2, 5]
    /// Nitrate, ppm.
    static let nitrate: [Double] = [0, 5, 10, 20, 40, 80, 160]
    /// pH — the kit's low-range and high-range cards combined.
    static let ph: [Double] = [6.0, 6.4, 6.6, 6.8, 7.0, 7.2, 7.4, 7.6, 7.8, 8.0, 8.2, 8.4, 8.6, 8.8]
}
