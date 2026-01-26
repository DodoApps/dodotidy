import SwiftUI

struct SunburstChartView: View {
    let entries: [DirEntry]
    let totalSize: Int64
    @Binding var selectedEntry: DirEntry?

    private let colors = Color.chartColors

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // Background circle
                Circle()
                    .fill(Color.dodoBackgroundTertiary.opacity(0.3))
                    .frame(width: size, height: size)

                // Sunburst rings
                ForEach(Array(entries.prefix(8).enumerated()), id: \.element.id) { index, entry in
                    SunburstSegment(
                        entry: entry,
                        index: index,
                        totalSize: totalSize,
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        color: colors[index % colors.count],
                        innerRadius: size * 0.25,
                        outerRadius: size * 0.45,
                        isSelected: selectedEntry?.id == entry.id
                    ) {
                        selectedEntry = entry
                    }
                }

                // Center info
                VStack(spacing: 4) {
                    if let selected = selectedEntry {
                        Text(selected.name)
                            .font(.dodoSubheadline)
                            .foregroundColor(.dodoTextPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Text(selected.size.formattedBytes)
                            .font(.dodoHeadline)
                            .foregroundColor(.dodoPrimary)

                        Text("\(percentageOf(selected.size))%")
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    } else {
                        Text("Total")
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)

                        Text(totalSize.formattedBytes)
                            .font(.dodoHeadline)
                            .foregroundColor(.dodoTextPrimary)

                        Text("\(entries.count) items")
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextTertiary)
                    }
                }
                .frame(width: size * 0.4)

                // Legend
                legendView
                    .position(x: geometry.size.width - 80, y: geometry.size.height - 100)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func startAngle(for index: Int) -> Angle {
        let previousSizes = entries.prefix(index).reduce(0) { $0 + $1.size }
        return .degrees(Double(previousSizes) / Double(totalSize) * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let currentSizes = entries.prefix(index + 1).reduce(0) { $0 + $1.size }
        return .degrees(Double(currentSizes) / Double(totalSize) * 360 - 90)
    }

    private func percentageOf(_ size: Int64) -> String {
        guard totalSize > 0 else { return "0" }
        return String(format: "%.1f", Double(size) / Double(totalSize) * 100)
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 6) {
                    Circle()
                        .fill(colors[index % colors.count])
                        .frame(width: 8, height: 8)

                    Text(entry.name)
                        .font(.dodoCaptionSmall)
                        .foregroundColor(.dodoTextSecondary)
                        .lineLimit(1)
                }
            }

            if entries.count > 5 {
                Text("+ \(entries.count - 5) more")
                    .font(.dodoCaptionSmall)
                    .foregroundColor(.dodoTextTertiary)
            }
        }
        .padding(10)
        .background(Color.dodoBackgroundSecondary.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadius))
    }
}

struct SunburstSegment: View {
    let entry: DirEntry
    let index: Int
    let totalSize: Int64
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            Path { path in
                path.addArc(
                    center: center,
                    radius: isSelected || isHovering ? outerRadius * 1.05 : outerRadius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.addArc(
                    center: center,
                    radius: innerRadius,
                    startAngle: endAngle,
                    endAngle: startAngle,
                    clockwise: true
                )
                path.closeSubpath()
            }
            .fill(color.opacity(isSelected ? 1.0 : (isHovering ? 0.9 : 0.75)))
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                onSelect()
            }
        }
    }
}

// MARK: - Progress Ring Component

struct ProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 8
    var backgroundColor: Color = Color.dodoBackgroundTertiary

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Animated Progress Bar

struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.dodoBackgroundTertiary)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}
