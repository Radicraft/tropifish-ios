import Foundation

/// The kinds of filter media a tank's filter runs, with sensible default
/// replacement cadences. These are the generic media types common to almost any
/// canister or hang-on filter, named by what they *do* rather than by any one
/// brand, since the same media is sold under many names.
///
/// Typical hobby guidance, which the defaults follow: replace the polishing pad,
/// carbon and ammonia-remover monthly; biological foam and bio rings roughly
/// every six months (and only *half* the bio rings at a time to preserve the
/// bacterial colony); coarse mechanical foam roughly yearly. The cardinal rule —
/// never swap all media at once — is surfaced in the guidance copy.
///
/// All cadences here are *defaults*: `FilterMediaItem.intervalDays` is seeded
/// from these but freely overridable per item, mirroring how `TankType` seeds
/// `ParameterTargets` without locking the user in.
enum FilterMediaKind: String, Codable, CaseIterable, Identifiable {
    /// Coarse mechanical foam / sponge — rinsed at most water changes, replaced when worn.
    case mechanicalFoam
    /// Biological foam / sponge insert.
    case bioFoam
    /// Ceramic bio rings / noodles — replace half at a time.
    case bioMax
    /// Activated carbon (chemical) — exhausts fastest.
    case carbon
    /// Fine "quick-clear" water-polishing pad.
    case waterPolishingPad
    /// Ammonia-remover / zeolite pad.
    case ammoniaRemover
    /// Anything not covered above (user names it via `FilterMediaItem.customName`).
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mechanicalFoam:   return "Mechanical Foam / Sponge"
        case .bioFoam:          return "Biological Foam"
        case .bioMax:           return "Bio Rings / Ceramic Media"
        case .carbon:           return "Activated Carbon"
        case .waterPolishingPad:return "Water Polishing Pad"
        case .ammoniaRemover:   return "Ammonia Remover"
        case .other:            return "Other Media"
        }
    }

    /// SF Symbol used in lists and the tank Filter section.
    var systemImage: String {
        switch self {
        case .mechanicalFoam, .bioFoam:  return "square.stack.3d.up"
        case .bioMax:                    return "circle.grid.3x3.fill"
        case .carbon:                    return "diamond.fill"
        case .waterPolishingPad:         return "square.dashed"
        case .ammoniaRemover:            return "drop.triangle"
        case .other:                     return "shippingbox"
        }
    }

    /// Default replacement cadence in days (typical hobby guidance).
    var defaultIntervalDays: Int {
        switch self {
        case .carbon, .waterPolishingPad, .ammoniaRemover:  return 30
        case .bioFoam, .bioMax:                             return 180
        case .mechanicalFoam:                               return 365
        case .other:                                        return 30
        }
    }

    /// Biological media that seed the tank's bacteria — replacing it all at once
    /// risks a mini-cycle, so the app advises swapping only half.
    var replaceHalfAtATime: Bool {
        switch self {
        case .bioMax, .bioFoam:  return true
        default:                 return false
        }
    }

    /// Short, plain-English maintenance note shown alongside the item.
    var guidance: String {
        switch self {
        case .mechanicalFoam:
            return "Rinse in old tank water at water changes; replace about yearly when it stops springing back."
        case .bioFoam:
            return "Biological media — rinse gently in tank water, replace roughly every 6 months and never at the same time as your bio rings."
        case .bioMax:
            return "Holds your beneficial bacteria. Replace only half at a time, about every 6 months, so the colony survives."
        case .carbon:
            return "Chemical media that exhausts fastest — swap monthly, or remove it entirely if you're dosing medication."
        case .waterPolishingPad:
            return "Fine pad that clears cloudiness. Replace monthly; it clogs quickly."
        case .ammoniaRemover:
            return "Zeolite pad for ammonia. Replace monthly. Not needed once a tank is fully cycled."
        case .other:
            return "Set your own reminder interval for this media."
        }
    }

    /// A standard canister-filter media set, in basket order (coarse → fine →
    /// bio → chemical → polish), for the one-tap "add standard set" action.
    static let standardSet: [FilterMediaKind] = [
        .mechanicalFoam, .bioFoam, .bioMax, .carbon, .waterPolishingPad
    ]
}
