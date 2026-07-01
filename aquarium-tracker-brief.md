# Aquarium Water Tracker — Programming Brief

## 1. Product Overview

A native iOS app for tropical fish keepers to log water test results, track trends over time, and get clear, actionable guidance on when and how to intervene (water changes, dosing, etc). Built first for personal daily use, structured well enough to ship as a paid App Store product afterward.

**Core problem it solves:** existing aquarium apps are either bloated (multi-tank fish-shop CRMs), abandoned, or just glorified note-taking with no real trend intelligence. This app should feel like a specialist instrument — simple to use in 30 seconds after a test, but smart about what the numbers mean.

**Platform:** Native iOS, SwiftUI, targeting iOS 17+.
**Distribution:** App Store, one-time purchase (£2.99–£4.99).
**Data entry:** Manual only — no camera/strip-scanning in v1.

---

## 2. Target User

- Freshwater tropical fish keepers (community tanks, planted tanks, occasional shrimp/discus keepers).
- Test water regularly (weekly, or during a cycling/problem period, daily).
- Currently either use a paper logbook, a spreadsheet, or nothing.
- Want fast entry, clear visual trends, and a nudge on what to do next — not an encyclopedia.

This also describes you, which is the right starting persona. Build for one obsessive user first.

---

## 3. Core Parameters to Track

| Parameter | Unit | Typical safe range (freshwater community) | Notes |
|---|---|---|---|
| Ammonia (NH3/NH4) | ppm | 0 | Any reading = urgent |
| Nitrite (NO2) | ppm | 0 | Any reading = urgent |
| Nitrate (NO3) | ppm | <20–40 depending on tank type | Slow creeping metric — the main "trend" parameter |
| KH (Carbonate hardness) | dKH or ppm | 3–8 dKH | Buffering capacity, affects pH stability |
| GH (General hardness) | dGH or ppm | 4–12 dGH | Species-dependent |
| pH | pH scale | 6.5–7.5 (species-dependent) | |
| Temperature | °C/°F | Species-dependent (typically 24–28°C for common tropicals) | Required in v1 — not just a nice-to-have. Temperature directly affects ammonia toxicity (see §6) and metabolic/oxygen stress, so it needs to be a first-class input, not an afterthought |

Design the schema so ranges are **per-tank configurable** (a shrimp tank and an African cichlid tank want very different KH/GH/pH targets). Ship with sensible defaults but let the user override per tank.

---

## 4. MVP Feature Set (v1 — build this first)

1. **Tank setup**
   - Create one or more tanks (name, volume, date established, freshwater/planted/shrimp preset for default ranges).
2. **Log a test**
   - Single fast-entry screen: date/time (defaults to now), numeric/stepper input per parameter (ammonia, nitrite, nitrate, KH, GH, pH, temperature — all in v1), optional free-text note ("added Prime, did 20% change").
   - Default numeric steps and displayed units match the API Freshwater Master Test Kit colour-chart increments (e.g. ammonia 0/0.25/0.5/1/2/4/8 ppm, nitrite 0/0.25/0.5/1/2/5 ppm, nitrate 0/5/10/20/40/80/160 ppm) so entry matches what the user is looking at on the test tube.
   - Should take under 30 seconds for a full 7-parameter log.
3. **History list**
   - Chronological log of past tests per tank, editable/deletable.
4. **Trend charts**
   - Line chart per parameter over time (Swift Charts), with the safe-range band shaded so it's visually obvious when a reading is drifting out of bounds.
   - At minimum: last 30 days, last 90 days, all-time toggle.
5. **Guidance / status**
   - On the tank home screen: a simple traffic-light status per parameter (green/amber/red) based on the latest reading vs configured range.
   - Plain-English one-liner: e.g. "Nitrate is climbing — 3 tests in a row rising. Consider a water change." This is the differentiator — most competitor apps show numbers but never say what to do.
6. **Water change reminders**
   - Configurable reminder cadence per tank (e.g. every 7 days) via local notifications.
   - Log a "water change" event distinct from a test, so you can see change-frequency against nitrate trend on the same chart.
7. **Data persistence**
   - SwiftData, on-device. No login, no backend required for v1.

---

## 5. Phase 2 (post-personal-use validation, pre or post launch)

- iCloud sync via CloudKit (multi-device, free with SwiftData + CloudKit container).
- Home Screen widget showing days-since-last-test / days-since-last-water-change.
- Dosing calculator (e.g. "you need Xml of conditioner for a 20% change on a 120L tank").
- Export data (CSV) — useful for power users and a nice "trust us with your data" feature.
- Multiple test-kit presets (API Freshwater Master Test Kit ranges vs strip-test ranges differ slightly — let advanced users pick).
- **Livestock profiles and species-aware suitability** — this needs care, not a bolt-on:
   - A per-tank stocked-species list, each species carrying its own known-good ranges (pH, GH, KH, temperature, and ammonia/nitrite sensitivity tier — soft-water species like tetras and shrimp are far more sensitive than livebearers or goldfish).
   - For a community tank with multiple species, the app computes the **intersection** of all stocked species' acceptable ranges, not an average — e.g. if one species wants pH 6.0–7.0 and another wants pH 7.0–7.5, the workable overlap is a narrow band around 7.0, and the app should show that overlap explicitly along with which species is the limiting factor for each parameter. This is the actually-hard, actually-valuable part of species-aware guidance, and it's worth being upfront that a naive "average the ranges" approach would be wrong and should be avoided.
   - Ship with a modest built-in reference table (30–50 common tropical species covering the bulk of what community tank keepers stock) rather than trying to be exhaustive at launch — this can grow over time without disrupting the core app.
   - This is correctly a Phase 2 feature: v1 tank-type presets (community/planted/shrimp/cichlid/discus) get you 80% of the value with a fraction of the effort, and validates whether people actually want per-species precision before you build a species database.
- Plant log per tank (nice-to-have, lower priority than livestock).

**Explicitly out of scope for v1 and v2:** photo/strip scanning (you've ruled this out — it's a computer-vision project in its own right and would roughly double build complexity), social features, marketplace/shop integration.

---

## 6. Assessment Methodology (the part worth getting right)

This is the feature that makes the app worth paying for, so each parameter needs its own correct logic rather than one generic threshold-check applied uniformly. The mechanisms genuinely differ — ammonia toxicity is pH/temperature-driven, nitrite toxicity is chloride-driven, nitrate and GH are chronic/stocking indicators rather than acute dangers, and KH/pH are about stability as much as absolute value. Getting these distinctions right (and not papering over them with one shared "range + trend" rule) is the actual point of difference from competitor apps.

### 6.1 General framework (applies unless a parameter overrides it below)

- **Threshold check:** compare the latest reading to the tank's configured safe range → green/amber/red.
- **Trend check:** look at the last 3–5 readings. If a parameter has moved in the same direction across the last 3 tests, flag a trend warning even while the absolute value is still "safe" — this is what lets the app catch a slow nitrate creep or a slowly depleting KH before it becomes an acute problem, which is the actual value of logging over time rather than spot-checking.
- **Guidance copy:** a small local table of message templates keyed to (parameter, status, trend-direction), not anything generated at runtime — deterministic, testable, free to run, and reviewable before shipping (important, since this is health-adjacent advice).

### 6.2 Ammonia — calculate toxicity, don't just read the test kit number

What the test kit measures is total ammonia nitrogen (TAN): the combined concentration of toxic un-ionized ammonia (NH₃) and much less toxic ionized ammonium (NH₄⁺). The ratio between the two shifts sharply with pH and, to a lesser extent, temperature — per the standard reference (Emerson et al., 1975, still the basis of current EPA/CCME freshwater ammonia guidelines), a rise from pH 7.0 to pH 8.0 roughly multiplies the toxic fraction tenfold, while each 10°C rise roughly doubles it. This means a 0.5 ppm TAN reading can be low-risk at pH 6.5 and genuinely dangerous at pH 8.0 in a warm tank — a flat "any ammonia = red" threshold ignores the mechanism entirely.

- **Calculation:** first find `pKa = 0.09018 + 2729.92 / (T + 273.15)` where T is temperature in °C. Then the fraction of TAN that is toxic NH₃ is `f = 1 / (1 + 10^(pKa − pH))`. Un-ionized ammonia (NH₃-N, ppm) = `f × total ammonia reading`.
- **This requires all three readings — total ammonia, pH, and temperature — from the same test session.** The entry screen should treat these as a bundled group rather than fields that could be filled in on different days, or the calculation is meaningless.
- **Risk tiers on the calculated NH₃-N figure** (aligned with published freshwater guideline values, offered as sensible defaults and made tank-preset-adjustable since livebearers/goldfish tolerate more than soft-water species like tetras, rams, or shrimp):
  - Safe: < 0.02 ppm NH₃-N
  - Caution: 0.02–0.05 ppm
  - Danger: 0.05–0.2 ppm
  - Critical: ≥ 0.2 ppm
- **Display the calculated NH₃-N figure as the headline number**, not the raw TAN reading — with the TAN reading shown as a secondary detail for reference. This is the app's actual point of difference and worth being visually prominent.
- **One caveat worth surfacing in-app, not just in this brief:** a newly-cycling tank (first few weeks) will show ammonia most days as a matter of course — the guidance copy for a tank flagged as "cycling" (set at tank creation) should read as informational rather than alarming, since panic-driven over-intervention (excessive water changes) can actually slow a cycle down.

### 6.3 Nitrite — zero-tolerance, and do not apply the ammonia logic to it

Nitrite's toxicity mechanism is different from ammonia's and it is important the app doesn't conflate them. Nitrite crosses the gill via the same chloride-uptake pathway fish use to absorb chloride ions, and once in the bloodstream it oxidises haemoglobin into methaemoglobin, which cannot carry oxygen ("brown blood disease"). The dominant protective factor here is **environmental chloride concentration, not pH or temperature** — a high chloride-to-nitrite ratio (roughly 6:1 or higher; aquarium salt is sometimes dosed deliberately for exactly this reason during a nitrite spike) meaningfully reduces uptake and toxicity, whereas pH and temperature have comparatively little direct effect on nitrite toxicity itself.

- **Practical implication:** since the app doesn't measure chloride by default (it isn't part of the standard freshwater test kit panel), don't attempt a "corrected" nitrite risk figure the way ammonia gets one — that would be applying the wrong mechanism. Treat any non-zero nitrite reading as red regardless of pH/temperature/trend. There is no meaningful "safe" non-zero nitrite level for freshwater fish without knowing chloride levels, which v1 doesn't ask for.
- Optional Phase 2 refinement: if a chloride/salt-dosing field is ever added (relevant mainly to keepers deliberately treating a nitrite spike), the guidance copy could then reference the chloride:nitrite ratio — but this is a niche addition, not core.

### 6.4 Nitrate — a chronic/stocking indicator, not an acute-danger one

Nitrate is far less acutely toxic than ammonia or nitrite (freshwater 96-hour LC50 values are typically over 100 mg/L), so its role in the app is different: it's the slow-moving signal of stocking density, feeding, and water-change adequacy, and the trend matters more than any single reading.

- Threshold + trend check as in §6.1, with the trend check weighted more heavily than for other parameters — nitrate is the parameter where "risen 3 tests running" is more actionable than "currently at 25 ppm."
- **Worth building in as a one-time setup step, not just noted in this brief:** prompt the user to test their tap/source water for nitrate once, since some tap water already carries a nitrate baseline (occasionally significant depending on region). Without knowing that baseline, the guidance "do a water change" is sometimes wrong advice if the tap water itself is the source of elevated nitrate — the app should be able to say "your tank nitrate is close to your tap water baseline; a water change won't lower it much further" rather than repeatedly suggesting a fix that won't work.

### 6.5 KH — buffering capacity and pH-crash risk, assessed via trend more than absolute value

KH (carbonate hardness) reflects the water's buffering capacity — its ability to neutralise acids and resist pH swings. A tank that's low in KH and declining over successive tests is at rising risk of a sudden pH crash (common with driftwood, low water-change frequency, or CO2 injection in planted tanks, all of which produce acids that consume buffering capacity over time).

- Threshold check against the tank's configured range, but the more important signal is the **trend**: KH low-and-falling should be flagged distinctly from KH low-and-stable, since the former is a leading indicator of an approaching pH crash and the latter may simply be a stable low-KH tank that's fine for its stocked species.

### 6.6 GH — species-suitability parameter, not a safety one

GH (general hardness, reflecting calcium/magnesium concentration) matters for osmoregulation, breeding condition (particularly livebearers and cichlids), plant nutrient availability, and shrimp exoskeleton health (calcium specifically) — but drifting outside range is a suitability problem, not an acute-danger one the way ammonia or nitrite are.

- Threshold check against the tank's configured range with a lower-urgency status tier than ammonia/nitrite/nitrate — amber rather than red even well outside range, with guidance copy framed as "outside the ideal range for [tank type]" rather than an urgent warning.

### 6.7 pH — stability matters as much as the absolute number

Within a broad species-appropriate range, a *stable* pH that's slightly outside the textbook-ideal range is generally less harmful than a pH that's "correct" on paper but swinging significantly between tests — rapid pH change is itself a stressor, independent of where the number lands.

- In addition to the range check, calculate the **rate of change** between consecutive readings. A shift greater than roughly 0.3–0.5 pH units between tests (adjust as a tank preset) should be flagged as a stability warning even if both readings individually fall within the configured safe range.
- Note the interaction with §6.2: a rising pH reading should also trigger a re-check of ammonia risk on the same test session, since rising pH pushes more total ammonia into the toxic NH₃ form — worth wiring these two checks together in code rather than treating them as fully independent.

### 6.8 Temperature — range and stability, plus its role as an input to other calculations

- Threshold check against the tank's configured range (typically 24–28°C for common freshwater tropicals, adjustable per tank/species preset).
- **Rate-of-change check:** a swing greater than roughly 2°C within 24 hours should be flagged as a stress-risk warning regardless of whether both readings are individually within range — sudden temperature change is a known stressor and disease trigger (e.g. ich outbreaks are classically associated with temperature swings) independent of the absolute values involved.
- Temperature's other role, covered in §6.2, is as a required input to the ammonia toxicity calculation — it isn't only a status parameter in its own right, which is part of why it belongs in v1 rather than being treated as optional.

### 6.9 Example guidance copy (illustrative, not exhaustive)

- Ammonia + danger + cycling tank → "Ammonia is elevated but this is expected during cycling. Keep testing daily and avoid large water changes that could slow the cycle."
- Ammonia + danger + established tank → "Calculated ammonia risk is high for your current pH and temperature. Do a water change now and check for overstocking or overfeeding."
- Nitrite + any reading → "Nitrite detected — this is always a red flag. Do a partial water change and re-test in 24 hours."
- Nitrate + red + rising, tap-water baseline known and low → "Nitrate is high and climbing. Do a 20–30% water change and check feeding/stocking levels."
- Nitrate + red + rising, tap-water baseline known and comparable → "Nitrate is high but close to your tap water baseline — a water change alone won't bring this down much further. Consider reducing feeding or stocking."
- KH + amber + falling → "KH is trending down — pH crashes become more likely as buffering capacity drops. Consider a KH buffer or more frequent water changes."
- pH + stability warning → "pH shifted by more than 0.4 since your last test. Rapid pH changes are more stressful to fish than a stable off-target pH — check what changed (water change size, new decor, CO2 system)."
- Temperature + stability warning → "Temperature changed by more than 2°C since your last reading. Check heater function and room temperature — sudden swings stress fish and can trigger disease outbreaks."

---

## 7. Tech Stack

- **UI:** SwiftUI
- **Persistence:** SwiftData (local), CloudKit sync in Phase 2
- **Charts:** Swift Charts (native, no third-party dependency)
- **Notifications:** UserNotifications framework for water-change reminders
- **Monetization:** Paid-upfront confirmed. No StoreKit/IAP integration needed at all — pricing is set directly in App Store Connect, and the app itself contains no paywall logic. This simplifies the build: no entitlement checks, no "unlock" screen, nothing to test around purchase state. Worth knowing the tradeoff you're accepting: upfront-paid apps get very little organic App Store browsing traffic compared to free-with-IAP apps, so discovery will lean more on your own audience/marketing (White Wiki readers, LinkedIn, r/Aquariums, fishkeeping forums) than on App Store search.

---

## 8. Non-Functional Requirements

- **Offline-first:** must work with no network at all — a fish room with bad WiFi shouldn't block a test log.
- **Privacy:** no account, no analytics beyond basic crash reporting, no data leaves the device unless the user opts into iCloud sync. Worth a line on this in the App Store listing — it's a genuine differentiator vs bloated competitor apps.
- **Accessibility:** Dynamic Type support, VoiceOver labels on chart data (Swift Charts has accessibility support built in — don't skip it).
- **Performance:** trivial for this data volume (hundreds of readings per tank at most), no real constraints here.

---

## 9. Suggested Build Order for Claude Code Sessions

1. Data models (Tank, TestReading, WaterChangeEvent) + SwiftData schema.
2. Tank creation/list screens.
3. Test entry screen (the highest-frequency-use screen — get this right first).
4. History list.
5. Trend charts with range bands.
6. Guidance/status logic + traffic-light home screen.
7. Notifications for water-change reminders.
8. Polish pass: onboarding, empty states, App Store screenshots prep.
9. StoreKit integration once the monetization model (upfront paid vs free+unlock) is decided.

---

## 10. Decisions

- [x] **Monetization:** paid upfront.
- [x] **Test kit defaults:** API Freshwater Master Test Kit increments.
- [x] **Temperature logging:** in v1, required (feeds the ammonia toxicity calculation).
- [x] **App name:** TropiFish (see §11).
- [x] **Visual direction:** see §12.
- [ ] Bundle identifier / App Store Connect setup (housekeeping, do this whenever — not a design decision).

---

## 11. App Name — TropiFish (decided)

Settled on **TropiFish**. Short, immediately signals what it's for (tropical fish keeping), easy to say and spell, and reads as a proper app name rather than a generic keyword string — App Store search will still pick it up for "tropical fish" queries via the name itself, no keyword-stuffing needed. Worth a quick App Store and trademark-register search before the listing goes live, same as with any name, but nothing about it raises a flag.

For reference, the earlier shortlist considered: Tankly, Aqualog, Cyclewise, Finstrument, Tankpulse, Waterlog — TropiFish beats all of them on the main criterion that matters, which is that a fishkeeper searching the App Store would type almost exactly this.

---

## 12. Visual Design Direction

Most existing aquarium apps default to a cartoonish, skeuomorphic look — bubbles, cartoon fish icons, bright primary colours. That's the wrong reference point for a paid, science-forward tool. The stronger positioning is closer to a **precision instrument / health-tracking app** (think Oura, Apple Health, a lab thermometer) than a fish-shop mascot app:

- **Palette:** deep teal/navy dark mode as the primary surface (fishkeepers often check tank stats in a dim room at night), with a single clean accent colour for interactive elements, and desaturated traffic-light colours (muted green/amber/red rather than saturated stoplight colours) for status so it reads as calm rather than alarming.
- **Typography:** a clean system sans-serif (SF Pro is fine — don't over-design this), numbers given visual priority since this is fundamentally a numbers-first app.
- **Iconography:** abstract/geometric (a droplet, a gauge arc, a simple line-chart mark) rather than illustrated fish or bubbles. Save any fish illustration for empty-states only, kept minimal.
- **Layout inspiration:** card-based home screen (one card per tank), each card showing latest status at a glance, tapping through to full trend detail — this pattern (dashboard → detail) is well-worn in health/fitness apps for good reason: it's fast to scan.

I've put together a quick mockup of what the tank home screen could look like in this direction, to make the decision concrete rather than abstract.

---

## 13. Development Environment & Build Workflow

This matters enough to spell out explicitly, since it affects how §9's build order actually gets executed: a native SwiftUI iOS app requires Xcode to compile, run in the simulator, and submit to the App Store — and **Xcode is macOS-only**. This isn't a Claude Code or Cowork limitation, it's an Apple toolchain limitation, and it would apply just as much if the app were built in React Native or Flutter instead (any iOS build still passes through Xcode at the final step).

**Claude Code itself runs fine on Windows** — it can write, edit, and reason about all the Swift/SwiftUI code with no issue. What it can't do on Windows is invoke `xcodebuild`, launch the iOS Simulator, or produce a runnable `.app`/`.ipa`. So the practical options are:

- **Get access to a Mac** — even a secondhand or base-spec Mac mini is enough (Xcode doesn't need a powerful machine for an app this size). This is the most straightforward path since you'll need Xcode repeatedly anyway: simulator testing throughout development, TestFlight builds, and App Store submission are all recurring needs, not one-off steps.
- **Cloud Mac rental** (MacinCloud, MacStadium, or similar) if you don't want to buy hardware — gives you remote access to a real Mac with Xcode, at an hourly or monthly cost. Workable, but noticeably clunkier for the kind of fast, iterative "change code → check simulator → change code" loop you'll want during active development.
- **CI-only cloud builds** (Xcode Cloud, Codemagic, GitHub Actions macOS runners) — good for automating TestFlight builds later, but you still won't get simulator visual feedback this way, so it doesn't replace having a Mac during active UI development.

**Recommended workflow given this:** write and iterate on code with Claude Code on your Windows laptop for anything that doesn't need visual/runtime feedback (data models, the ammonia calculation logic, guidance-message templates), pushing to Git as you go. For screens and anything requiring simulator testing, you'll want Claude Code running on an actual Mac against the same repo — Claude Code works identically on macOS, so this isn't a different tool, just a different machine for that part of the loop.

**On "building it in one go":** Claude Code can work through a large chunk of the build order in §9 autonomously in a single long session once it has this brief as context (drop it in as `CLAUDE.md` or reference it directly), but "one go" is worth treating as "one long autonomous session with checkpoints" rather than zero supervision — particularly for the ammonia/nitrite/nitrate assessment logic in §6, which is worth reviewing and testing against known reference values before trusting it, since a subtle bug there wouldn't look wrong, it would just quietly give bad guidance. A reasonable shape for the session: let Claude Code run through data models → tank setup → test entry → history unsupervised, then pause to actually run and check the app in Simulator before continuing to charts and the assessment logic, then a second pause to verify the ammonia calculation specifically against the reference values noted in the earlier conversation.

**On old hardware specifically:** if you're weighing an older Mac you already own rather than buying new, check its exact model against Apple's current requirement first. As of April 2026, Apple requires all App Store submissions to be built with Xcode 26, which itself requires macOS Sequoia 15.6 or later to install. Older Intel Macs that Apple has already stopped supporting (check via *About This Mac* → your exact model → Apple's support page for that model) will fall short of this regardless of unofficial patchers, since it's a hard OS/Simulator compatibility wall rather than a performance issue — the machine either can run the required macOS or it can't. A current or recent-generation Apple Silicon Mac mini (the base model is Apple's cheapest current Mac) is the reliable option, and secondhand M1/M2 Mac minis are a reasonable middle ground if you want to spend less.

---

## 14. App Store Submission Checklist

Everything Apple requires before this can actually go live, grouped by when you'll need it.

### 14.1 Accounts and enrolment
- [ ] **Apple Developer Program membership** — $99 USD/year (billed in local currency), required to distribute publicly. Enrol as an individual (your legal name appears as the seller on the App Store — don't use a business/brand name unless you enrol as an organisation, which needs a D-U-N-S number and takes longer to approve). Xcode itself is free and usable without this for local development/testing on your own device; you only need the paid membership at the point you want to submit to TestFlight or the App Store.

### 14.2 Build requirements
- [ ] Built with **Xcode 26 or later**, using the **iOS 26 SDK or later** — Apple has made this mandatory for all new submissions and updates since April 28, 2026. You can still set a lower deployment target (e.g. iOS 17) to support users on older iOS versions; the SDK requirement is about what you build *with*, not the minimum iOS version your users need.
- [ ] Run **Product → Archive → Validate App** in Xcode's Organizer before uploading — catches a meaningful chunk of rejection-worthy issues before Apple's review does.

### 14.3 App Store Connect listing
- [ ] **App name** (from §11) and a short subtitle (30 characters).
- [ ] **Description** — what it does, who it's for, no keyword-stuffing (App Store ranking actively penalises this now).
- [ ] **Keywords** (100 characters, comma-separated, not shown to users) — think "aquarium, fish tank, water test, nitrate, ammonia" rather than repeating words already in your app name.
- [ ] **Category** — Utilities or Lifestyle both fit; Utilities probably reads more accurately for what this is.
- [ ] **Screenshots** — need at least one set at the largest supported device size (currently the 6.9" iPhone Pro Max class); App Store Connect will scale for other device sizes from that. Worth designing these properly rather than raw simulator screenshots — they're genuinely part of conversion for a paid app.
- [ ] **App icon** — 1024×1024px, no transparency, no rounded corners (the system applies those). Ties back to the visual direction in §12 — a clean geometric mark, not an illustrated fish.
- [ ] **Support URL** — a real page users can reach if something goes wrong. A simple page on one of your existing domains works fine; doesn't need to be elaborate.
- [ ] **Privacy policy URL** — mandatory for every app regardless of category, no exceptions. Given this app stores everything on-device with no accounts and no analytics, this can be a short, genuinely simple page — worth stating plainly that no data leaves the device, which is also a real selling point given the brief's non-functional requirements in §8.
- [ ] **Age rating questionnaire** — straightforward for this app; no objectionable content, expect 4+.
- [ ] **App Privacy "nutrition label"** — the data-collection disclosure shown on your product page. Since v1 collects nothing beyond on-device data, this should mostly be "Data Not Collected," which again doubles as a point of differentiation on your listing.
- [ ] **Export compliance declaration** — a standard questionnaire on encryption use; an app using only Apple's standard HTTPS/on-device encryption (no custom cryptography) typically qualifies for the standard exemption, but confirm this in App Store Connect at submission time since it's asked per-build.
- [ ] **Pricing and availability** — set your one-time price tier (from §10, already decided) and territories.

### 14.4 Before you submit for review
- [ ] **TestFlight beta** — not mandatory, but genuinely worth doing even as a solo developer: it's a free, easy way to run the app on a real device rather than just the simulator before it goes out publicly.
- [ ] **Review Guidelines basics** — no placeholder/lorem-ipsum content anywhere in the shipped build, no crashes on first launch, functional empty states (e.g. a brand-new tank with no test history yet), and metadata (screenshots, description) that accurately reflects what the app actually does — mismatches between listing and app behaviour are a common rejection reason.

### 14.5 What Apple takes on sales
Since you've settled on paid-upfront: Apple's standard commission is 30%, reduced to **15%** for developers enrolled in the **App Store Small Business Program** (free to join, for developers/businesses earning under $1M/year on the App Store — worth applying for given this app's likely revenue, since it's a straightforward form and roughly halves Apple's cut). No separate IAP-related fees apply here since there's no in-app purchase to manage. The EU Core Technology Fee that gets mentioned in App Store cost discussions only applies to very high-install-volume apps distributed via alternative EU marketplaces, not to a small paid app on the standard App Store — not a real consideration here.

---

## 15. Cost Breakdown

| Item | Cost | Notes |
|---|---|---|
| Xcode | Free | Download from the Mac App Store |
| Mac hardware | £0 if you already have a compatible one; otherwise from ~£/$500–600 new for a base Apple Silicon Mac mini, less secondhand | The 2012 Mac mini in the loft won't work (see §13) — this is the one unavoidable cost if you don't already have a current Mac |
| Apple Developer Program | $99/year | Mandatory for any public distribution, including TestFlight betas beyond your own devices |
| App Store commission | 15% of each sale (after joining the free Small Business Program) or 30% without it | Ongoing, per-sale, not upfront |
| Privacy policy / support page hosting | Effectively £0 | A simple page on whitewiki.org or radiumquest.com (or a free GitHub Pages page) satisfies this — no dedicated hosting needed |
| App icon / screenshot design | £0–low, your own time | Doable yourself given the visual direction already set in §12; no need to commission this |
| TestFlight | Free | Included with the Developer Program membership |
| Ongoing server/backend costs | £0 | v1 has no backend — SwiftData is on-device, CloudKit sync in Phase 2 is free within Apple's standard iCloud tiers |

The only genuinely new cost this project requires, beyond the $99/year Apple already charges every developer, is the Mac itself if you don't get one some other way — everything else is either free or comes out of your own time rather than your wallet.
