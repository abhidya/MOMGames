import SwiftUI

/// Drives archery, artillery, and launch from a `DuelConfig`. Set angle/power,
/// Fire to preview the shot, then Send to commit it as the next message.
struct DuelView: View {
    @ObservedObject var controller: GameController
    let envelope: MatchEnvelope
    let config: DuelConfig

    @State private var angle: Double
    @State private var power: Double
    @State private var preview: DuelShot?

    init(controller: GameController, envelope: MatchEnvelope, config: DuelConfig) {
        self.controller = controller
        self.envelope = envelope
        self.config = config
        _angle = State(initialValue: config.defaultAngle)
        _power = State(initialValue: config.defaultPower)
    }

    private var seat: Int { controller.perspectiveSeat(in: envelope) }
    private var canAct: Bool { controller.canAct(in: envelope) }
    private var scene: DuelScene { config.scene(envelope.state, seat) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(config.statusLine(envelope.state))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            canvas
                .frame(height: 150)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))

            if canAct {
                controls
            }

            if let preview {
                Text(preview.caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(preview.hit ? Theme.positive : Theme.textPrimary)
            }

            history
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        Canvas { context, size in
            let scene = scene
            let scaleX = size.width / scene.worldWidth
            let scaleY = size.height / scene.worldHeight
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * scaleX, y: size.height - p.y * scaleY)
            }

            var ground = Path()
            if let first = scene.ground.first {
                ground.move(to: map(CGPoint(x: first.x, y: 0)))
                for point in scene.ground { ground.addLine(to: map(point)) }
                if let last = scene.ground.last {
                    ground.addLine(to: map(CGPoint(x: last.x, y: 0)))
                }
                ground.closeSubpath()
            }
            context.fill(ground, with: .color(Theme.boardDark.opacity(0.6)))

            for marker in scene.markers {
                let rect = CGRect(origin: map(CGPoint(x: marker.rect.minX, y: marker.rect.maxY)),
                                  size: CGSize(width: marker.rect.width * scaleX,
                                               height: marker.rect.height * scaleY))
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color(for: marker.kind)))
            }

            if let preview, preview.trajectory.count > 1 {
                var path = Path()
                path.move(to: map(preview.trajectory[0]))
                for point in preview.trajectory.dropFirst() { path.addLine(to: map(point)) }
                context.stroke(path, with: .color(Theme.accent), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            }
        }
    }

    private func color(for kind: DuelMarker.Kind) -> Color {
        switch kind {
        case .target: return Theme.positive
        case .me: return Theme.accent
        case .opponent: return Theme.danger
        case .boost: return Theme.positive.opacity(0.8)
        case .drag: return Theme.warning
        case .landing: return Theme.accent
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            slider(title: "Angle", value: $angle, range: config.minAngle...config.maxAngle, unit: "°")
            slider(title: "Power", value: $power, range: config.minPower...config.maxPower, unit: "")
            HStack(spacing: 10) {
                Button {
                    preview = config.fire(envelope.state, seat, angle, power)
                } label: {
                    Label("Fire", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.warning)

                Button {
                    send()
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(preview == nil)
            }
        }
    }

    private func slider(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))\(unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
            }
            Slider(value: value, in: range)
                .tint(Theme.accent)
                .onChange(of: value.wrappedValue) { _ in preview = nil }
        }
    }

    @ViewBuilder
    private var history: some View {
        let entries = config.history(envelope.state)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func send() {
        guard let preview else { return }
        let result = MoveResult(
            state: preview.newState,
            caption: preview.caption,
            subcaption: preview.subcaption,
            finished: preview.finished,
            winnerSeat: preview.winnerSeat
        )
        controller.commit(result, in: envelope)
    }
}
