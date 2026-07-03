import SwiftUI

/// A calm status pill for the overall tank traffic light (brief §4.5, §12).
struct TrafficLightBadge: View {
    let light: TrafficLight
    var compact: Bool = false

    var body: some View {
        Label {
            Text(light.label)
        } icon: {
            Image(systemName: light.systemImage)
        }
        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        .foregroundStyle(light.color)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(light.color.opacity(0.14), in: Capsule())
    }
}

/// Like `TrafficLightBadge` but with caller-supplied text, for statuses that
/// aren't the fixed water traffic-light wording (e.g. a tank's stocking level).
struct TrafficLightBadgeLabel: View {
    let light: TrafficLight
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: light.systemImage)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(light.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(light.color.opacity(0.14), in: Capsule())
    }
}

/// A small directional glyph for a parameter's trend (brief §6.1).
struct TrendGlyph: View {
    let trend: TrendDirection

    var body: some View {
        if trend.isDirectional {
            Image(systemName: trend == .rising ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityLabel(trend == .rising ? "rising" : "falling")
        }
    }
}

/// One parameter's status line: name, value, trend, and a coloured status dot.
struct ParameterStatusRow: View {
    let assessment: ParameterAssessment

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(assessment.hasData ? assessment.risk.color : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)

            Text(assessment.parameter.displayName)
                .font(.body)

            if assessment.stabilityAlert {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.caption2)
                    .foregroundStyle(TrafficLight.amber.color)
                    .accessibilityLabel("unstable")
            }

            Spacer()

            TrendGlyph(trend: assessment.trend)

            Text(assessment.displayValue)
                .font(.callout.monospacedDigit())
                .foregroundStyle(assessment.hasData ? .primary : .secondary)
        }
        .padding(.vertical, 2)
    }
}
