//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan
//

import AppKit
import Combine
import Defaults
import EventKit
import SwiftUI

// MARK: - Music Player Components

struct MusicPlayerView: View {
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        HStack {
            AlbumArtView(vm: vm, albumArtNamespace: albumArtNamespace).padding(.all, 5)
            MusicControlsView().drawingGroup().compositingGroup()
        }
    }
}

struct AlbumArtView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if Defaults[.lightingEffect] {
                albumArtBackground
            }
            albumArtButton
        }
    }

    private var albumArtBackground: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Defaults[.cornerRadiusScaling]
                        ? MusicPlayerImageSizes.cornerRadiusInset.opened
                        : MusicPlayerImageSizes.cornerRadiusInset.closed)
            )
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(x: 1.3, y: 1.4)
            .rotationEffect(.degrees(92))
            .blur(radius: 40)
            .opacity(musicManager.isPlaying ? 0.5 : 0)
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                musicManager.openMusicApp()
            } label: {
                ZStack(alignment:.bottomTrailing) {
                    albumArtImage
                    appIconOverlay
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(musicManager.isPlaying ? 1 : 0.85)
            
            albumArtDarkOverlay
        }
    }

    private var albumArtDarkOverlay: some View {
        Rectangle()
            .aspectRatio(1, contentMode: .fit)
            .foregroundColor(Color.black)
            .opacity(musicManager.isPlaying ? 0 : 0.8)
            .blur(radius: 50)
    }
                

    private var albumArtImage: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Defaults[.cornerRadiusScaling]
                        ? MusicPlayerImageSizes.cornerRadiusInset.opened
                        : MusicPlayerImageSizes.cornerRadiusInset.closed)
            )
    }

    @ViewBuilder
    private var appIconOverlay: some View {
        if vm.notchState == .open && !musicManager.usingAppIconForArtwork {
            AppIcon(for: musicManager.bundleIdentifier ?? "com.apple.Music")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .offset(x: 10, y: 10)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
        }
    }
}

struct MusicControlsView: View {
    @ObservedObject var musicManager = MusicManager.shared
        @EnvironmentObject var vm: BoringViewModel
        @ObservedObject var webcamManager = WebcamManager.shared
    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast
    @Default(.musicControlSlots) private var slotConfig
    @Default(.musicControlSlotLimit) private var slotLimit

    var body: some View {
        VStack(alignment: .leading) {
            songInfoAndSlider
            slotToolbar
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var songInfoAndSlider: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                songInfo(width: geo.size.width)
                musicSlider
            }
        }
        .padding(.top, 10)
        .padding(.leading, 5)
    }

    private func songInfo(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MarqueeText(
                $musicManager.songTitle, font: .headline, nsFont: .headline, textColor: .white,
                frameWidth: width)
            MarqueeText(
                $musicManager.artistName,
                font: .headline,
                nsFont: .headline,
                textColor: Defaults[.playerColorTinting]
                    ? Color(nsColor: musicManager.avgColor)
                        .ensureMinimumBrightness(factor: 0.6) : .gray,
                frameWidth: width
            )
            .fontWeight(.medium)
            if Defaults[.enableLyrics] {
                TimelineView(.animation(minimumInterval: 0.25)) { timeline in
                    let currentElapsed: Double = {
                        guard musicManager.isPlaying else { return musicManager.elapsedTime }
                        let delta = timeline.date.timeIntervalSince(musicManager.timestampDate)
                        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
                        return min(max(progressed, 0), musicManager.songDuration)
                    }()
                    let line: String = {
                        if musicManager.isFetchingLyrics { return "Loading lyrics…" }
                        if !musicManager.syncedLyrics.isEmpty {
                            return musicManager.lyricLine(at: currentElapsed)
                        }
                        let trimmed = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? "No lyrics found" : trimmed.replacingOccurrences(of: "\n", with: " ")
                    }()
                    let isPersian = line.unicodeScalars.contains { scalar in
                        let v = scalar.value
                        return v >= 0x0600 && v <= 0x06FF
                    }
                    MarqueeText(
                        .constant(line),
                        font: .subheadline,
                        nsFont: .subheadline,
                        textColor: musicManager.isFetchingLyrics ? .gray.opacity(0.7) : .gray,
                        frameWidth: width
                    )
                    .font(isPersian ? .custom("Vazirmatn-Regular", size: NSFont.preferredFont(forTextStyle: .subheadline).pointSize) : .subheadline)
                    .lineLimit(1)
                    .opacity(musicManager.isPlaying ? 1 : 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var musicSlider: some View {
        TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            MusicSliderView(
                sliderValue: $sliderValue,
                duration: $musicManager.songDuration,
                lastDragged: $lastDragged,
                color: musicManager.avgColor,
                dragging: $dragging,
                currentDate: timeline.date,
                timestampDate: musicManager.timestampDate,
                elapsedTime: musicManager.elapsedTime,
                playbackRate: musicManager.playbackRate,
                isPlaying: musicManager.isPlaying,
                onValueChange: { newValue in
                    MusicManager.shared.seek(to: newValue)
                },
                isEnabled: musicManager.canSeek
            )
            .padding(.top, 5)
            .frame(height: 36)
        }
    }

    private var slotToolbar: some View {
        let slots = activeSlots
        return HStack(spacing: 6) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                slotView(for: slot)
                    .frame(alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var activeSlots: [MusicControlButton] {
        let sanitizedLimit = min(
            max(slotLimit, MusicControlButton.minSlotCount),
            MusicControlButton.maxSlotCount
        )
        let padded = slotConfig.padded(to: sanitizedLimit, filler: .none)
        let result = Array(padded.prefix(sanitizedLimit))
        // If calendar and camera are both visible alongside music, hide the edge slots
        let shouldHideEdges = Defaults[.showCalendar] && Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
        if shouldHideEdges && result.count >= 5 {
            return Array(result.dropFirst().dropLast())
        }

        return result
    }

    @ViewBuilder
    private func slotView(for slot: MusicControlButton) -> some View {
        switch slot {
        case .shuffle:
            HoverButton(icon: "shuffle", iconColor: musicManager.isShuffled ? .red : .primary, scale: .medium) {
                MusicManager.shared.toggleShuffle()
            }
        case .previous:
            HoverButton(icon: "backward.fill", scale: .medium) {
                MusicManager.shared.previousTrack()
            }
        case .playPause:
            HoverButton(icon: musicManager.isPlaying ? "pause.fill" : "play.fill", scale: .large) {
                MusicManager.shared.togglePlay()
            }
        case .next:
            HoverButton(icon: "forward.fill", scale: .medium) {
                MusicManager.shared.nextTrack()
            }
        case .repeatMode:
            HoverButton(icon: repeatIcon, iconColor: repeatIconColor, scale: .medium) {
                MusicManager.shared.toggleRepeat()
            }
        case .volume:
            VolumeControlView()
        case .favorite:
            FavoriteControlButton()
        case .goBackward:
            HoverButton(icon: "gobackward.15", scale: .medium) {
                MusicManager.shared.skip(seconds: -15)
            }
        case .goForward:
            HoverButton(icon: "goforward.15", scale: .medium) {
                MusicManager.shared.skip(seconds: 15)
            }
        case .none:
            Color.clear.frame(height: 1)
        }
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    private var repeatIconColor: Color {
        switch musicManager.repeatMode {
        case .off:
            return .primary
        case .all, .one:
            return .red
        }
    }
}

struct FavoriteControlButton: View {
    @ObservedObject var musicManager = MusicManager.shared

    var body: some View {
        HoverButton(icon: iconName, iconColor: iconColor, scale: .medium) {
            MusicManager.shared.toggleFavoriteTrack()
        }
        .disabled(!musicManager.canFavoriteTrack)
        .opacity(musicManager.canFavoriteTrack ? 1 : 0.35)
    }

    private var iconName: String {
        musicManager.isFavoriteTrack ? "heart.fill" : "heart"
    }

    private var iconColor: Color {
        musicManager.isFavoriteTrack ? .red : .primary
    }
}

private extension Array where Element == MusicControlButton {
    func padded(to length: Int, filler: MusicControlButton) -> [MusicControlButton] {
        if count >= length { return self }
        return self + Array(repeating: filler, count: length - count)
    }
}

// MARK: - Volume Control View

struct VolumeControlView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @State private var volumeSliderValue: Double = 0.5
    @State private var dragging: Bool = false
    @State private var showVolumeSlider: Bool = false
    @State private var lastVolumeUpdateTime: Date = Date.distantPast
    private let volumeUpdateThrottle: TimeInterval = 0.1
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if musicManager.volumeControlSupported {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        showVolumeSlider.toggle()
                    }
                }
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(musicManager.volumeControlSupported ? .white : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!musicManager.volumeControlSupported)
            .frame(width: 24)

            if showVolumeSlider && musicManager.volumeControlSupported {
                CustomSlider(
                    value: $volumeSliderValue,
                    range: 0.0...1.0,
                    color: .white,
                    dragging: $dragging,
                    lastDragged: .constant(Date.distantPast),
                    onValueChange: { newValue in
                        MusicManager.shared.setVolume(to: newValue)
                    },
                    onDragChange: { newValue in
                        let now = Date()
                        if now.timeIntervalSince(lastVolumeUpdateTime) > volumeUpdateThrottle {
                            MusicManager.shared.setVolume(to: newValue)
                            lastVolumeUpdateTime = now
                        }
                    }
                )
                .frame(width: 48, height: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .clipped()
        .onReceive(musicManager.$volume) { volume in
            if !dragging {
                volumeSliderValue = volume
            }
        }
        .onReceive(musicManager.$volumeControlSupported) { supported in
            if !supported {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showVolumeSlider = false
                }
            }
        }
        .onChange(of: showVolumeSlider) { _, isShowing in
            if isShowing {
                // Sync volume from app when slider appears
                Task {
                    await MusicManager.shared.syncVolumeFromActiveApp()
                }
            }
        }
        .onDisappear {
            // volumeUpdateTask?.cancel() // No longer needed
        }
    }
    
    
    private var volumeIcon: String {
        if !musicManager.volumeControlSupported {
            return "speaker.slash"
        } else if volumeSliderValue == 0 {
            return "speaker.slash.fill"
        } else if volumeSliderValue < 0.33 {
            return "speaker.1.fill"
        } else if volumeSliderValue < 0.66 {
            return "speaker.2.fill"
        } else {
            return "speaker.3.fill"
        }
    }
}

// MARK: - Main View

struct NotchHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    let albumArtNamespace: Namespace.ID

    var body: some View {
        Group {
            if !coordinator.firstLaunch {
                // PROTOTYPE: mock home (Now Playing + next event + quick launcher).
                PrototypeHomeView(albumArtNamespace: albumArtNamespace)
                    .environmentObject(vm)
            }
        }
        // simplified: use a straightforward opacity transition
        .transition(.opacity)
    }

    // NOTE (prototype): legacy live home kept below for reference, not shown.
    private var shouldShowCamera: Bool {
        Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
    }

    private var legacyMainContent: some View {
        HStack(alignment: .top, spacing: (shouldShowCamera && Defaults[.showCalendar]) ? 10 : 15) {
            MusicPlayerView(albumArtNamespace: albumArtNamespace)

            if Defaults[.showCalendar] {
                CalendarView()
                    .frame(width: shouldShowCamera ? 170 : 215)
                    .onHover { isHovering in
                        vm.isHoveringCalendar = isHovering
                    }
                    .environmentObject(vm)
                    .transition(.opacity)
            }

            if shouldShowCamera {
                CameraPreviewView(webcamManager: webcamManager)
                    .scaledToFit()
                    .opacity(vm.notchState == .closed ? 0 : 1)
                    .blur(radius: vm.notchState == .closed ? 20 : 0)
                    .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.76, blendDuration: 0), value: shouldShowCamera)
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        .blur(radius: vm.notchState == .closed ? 30 : 0)
    }
}

struct MusicSliderView: View {
    @Binding var sliderValue: Double
    @Binding var duration: Double
    @Binding var lastDragged: Date
    var color: NSColor
    @Binding var dragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    var onValueChange: (Double) -> Void
    var isEnabled: Bool = true


    var body: some View {
        VStack {
            CustomSlider(
                value: $sliderValue,
                range: 0...duration,
                color: Defaults[.sliderColor] == SliderColorEnum.albumArt
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.8)
                    : Defaults[.sliderColor] == SliderColorEnum.accent ? .effectiveAccent : .white,
                dragging: $dragging,
                lastDragged: $lastDragged,
                onValueChange: onValueChange,
                isEnabled: isEnabled
            )
            .frame(height: 10, alignment: .center)

            HStack {
                Text(timeString(from: sliderValue))
                Spacer()
                Text(timeString(from: duration))
            }
            .fontWeight(.medium)
            .foregroundColor(
                Defaults[.playerColorTinting]
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.6) : .gray
            )
            .font(.caption)
        }
        .onChange(of: currentDate) {
           guard !dragging, timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
            sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
        }
    }

    func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .white
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var onDragChange: ((Double) -> Void)?
    /// False for sources that reject MediaRemote seeks (browser video):
    /// renders a read-only progress bar instead of a dead scrubber.
    var isEnabled: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 9 : 5)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: filledTrackWidth, height: height)
            }
            .cornerRadius(height / 2)
            .frame(height: 10)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.6)
            // AppKit-level tracking: SwiftUI gestures never fire inside the
            // notch panel (verified: mouse events reach the hosting view but
            // no DragGesture/TapGesture recognizes), while NSView mouse
            // handlers do — same approach as the shelf's DraggableClickHandler.
            .overlay(
                SliderMouseTracker(isEnabled: isEnabled) { fraction, phase in
                    let newValue = range.lowerBound + Double(fraction) * rangeSpan
                    value = min(max(newValue, range.lowerBound), range.upperBound)
                    switch phase {
                    case .began, .changed:
                        if !dragging {
                            withAnimation { dragging = true }
                        }
                        onDragChange?(value)
                    case .ended:
                        onValueChange?(value)
                        dragging = false
                        lastDragged = Date()
                    }
                }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragging)
        }
    }
}

enum SliderTrackPhase { case began, changed, ended }

/// Reports horizontal press/drag position (0...1) over its bounds via
/// raw NSView mouse events, bypassing SwiftUI gesture recognition.
private struct SliderMouseTracker: NSViewRepresentable {
    var isEnabled: Bool
    var onTrack: (CGFloat, SliderTrackPhase) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.isEnabled = isEnabled
        view.onTrack = onTrack
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onTrack = onTrack
    }

    final class TrackingView: NSView {
        var isEnabled = true
        var onTrack: ((CGFloat, SliderTrackPhase) -> Void)?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            isEnabled ? super.hitTest(point) : nil
        }

        private func fraction(for event: NSEvent) -> CGFloat {
            let x = convert(event.locationInWindow, from: nil).x
            guard bounds.width > 0 else { return 0 }
            return min(max(x / bounds.width, 0), 1)
        }

        override func mouseDown(with event: NSEvent) {
            onTrack?(fraction(for: event), .began)
        }

        override func mouseDragged(with event: NSEvent) {
            onTrack?(fraction(for: event), .changed)
        }

        override func mouseUp(with event: NSEvent) {
            onTrack?(fraction(for: event), .ended)
        }
    }
}

// MARK: - PROTOTYPE HUB (mixed: home / scratchpad / calendar are live; others mock)

// B&W theme typeface: Geist (bundled), SF Symbols stay on system font.
extension Font {
    static func geist(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold: name = "Geist-Bold"
        case .semibold: name = "Geist-SemiBold"
        case .medium: name = "Geist-Medium"
        default: name = "Geist-Regular"
        }
        return .custom(name, size: size)
    }
}

private extension View {
    func protoCard() -> some View {
        self
            .padding(8)
            .background(Color(nsColor: .secondarySystemFill).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProtoSectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.geist(10, .semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProtoHeader: View {
    let view: NotchViews
    var body: some View {
        HStack(spacing: 8) {
            Button {
                BoringViewCoordinator.shared.navigate(to: .home)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.geist(12, .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Image(systemName: view.protoIcon)
                .font(.geist(12, .semibold))
                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                .frame(width: 26, height: 26)
                .background(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(view.protoTitle).font(.geist(13, .semibold)).foregroundStyle(.primary)
            Spacer()
            Text("Prototype").font(.geist(9)).foregroundStyle(.gray)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color(nsColor: .tertiarySystemFill))
                .clipShape(Capsule())
        }
    }
}

private struct ProtoStatTile: View {
    let label: String
    let value: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.geist(9)).foregroundStyle(.gray)
            Text(value).font(.geist(14, .bold)).foregroundStyle(.primary).lineLimit(1)
            Text(sub).font(.geist(9)).foregroundStyle(.primary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .protoCard()
    }
}

private struct ProtoBarRow: View {
    let label: String
    let value: String
    let frac: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.geist(10)).foregroundStyle(.primary).lineLimit(1)
                Spacer()
                Text(value).font(.geist(10)).foregroundStyle(.gray)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.25)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.8)).frame(width: g.size.width * frac, height: 5)
                }
            }.frame(height: 5)
        }
    }
}

private struct ProtoMockRow: View {
    let icon: String
    let title: String
    let sub: String
    let trailing: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.gray).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.geist(11)).foregroundStyle(.primary).lineLimit(1)
                Text(sub).font(.geist(9)).foregroundStyle(.gray).lineLimit(1)
            }
            Spacer()
            Text(trailing).font(.geist(10, .medium)).foregroundStyle(.primary).lineLimit(1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProtoPill: View {
    let text: String
    let selected: Bool
    var body: some View {
        Text(text).font(.system(size: 10, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color(nsColor: .windowBackgroundColor) : .primary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(selected ? Color.primary : Color(nsColor: .tertiarySystemFill))
            .clipShape(Capsule())
    }
}

// MARK: - Proto calendar helpers

private enum ProtoCalendarHelpers {
    static func filteredEvents(_ events: [EventModel]) -> [EventModel] {
        EventListView.filteredEvents(events: events)
    }

    static func nextHighlightEvent(in events: [EventModel], now: Date = Date()) -> EventModel? {
        let filtered = filteredEvents(events)
        return filtered.first(where: { !$0.isAllDay && $0.end > now })
            ?? filtered.first(where: { $0.isAllDay })
    }

    static func remainingTodayCount(in events: [EventModel], excluding highlight: EventModel?) -> Int {
        let filtered = filteredEvents(events).filter {
            Calendar.current.isDateInToday($0.start) && $0.eventStatus != .ended
        }
        guard let highlight else { return filtered.count }
        return max(0, filtered.filter { $0.id != highlight.id }.count)
    }

    static func relativeEventSubtitle(for event: EventModel, now: Date = Date()) -> String {
        if event.isAllDay { return "All day" }
        let time = event.start.formatted(date: .omitted, time: .shortened)
        switch event.eventStatus {
        case .inProgress:
            return "\(time) · Now"
        case .upcoming:
            let minutes = max(0, Int(event.start.timeIntervalSince(now) / 60))
            if minutes < 60 { return "\(time) · in \(minutes) min" }
            let hours = minutes / 60
            return "\(time) · in \(hours)h \(minutes % 60)m"
        case .ended:
            return time
        }
    }

    static func eventIcon(for event: EventModel) -> String {
        if event.type.isReminder { return "checkmark.circle" }
        if event.isAllDay { return "sun.max.fill" }
        return "calendar"
    }

    static func weekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let anchor = calendar.startOfDay(for: date)
        let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func weekdayLetter(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.narrow))
    }
}

// MARK: 1 — Home (Now Playing + next event)

struct PrototypeHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var calendarManager = CalendarManager.shared
    let albumArtNamespace: Namespace.ID

    @State private var sliderValue: Double = 0
    @State private var draggingSlider = false
    @State private var lastSliderDrag = Date.distantPast

    private var nextEvent: EventModel? {
        ProtoCalendarHelpers.nextHighlightEvent(in: calendarManager.events)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                nowPlayingCard
                nextEventCard
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
        .onAppear {
            musicManager.forceUpdate()
        }
        .task {
            await calendarManager.checkCalendarAuthorization()
            await calendarManager.checkReminderAuthorization()
            await calendarManager.updateCurrentDate(Date.now)
        }
    }

    private var nowPlayingCard: some View {
        HStack(spacing: 8) {
            Button {
                musicManager.openMusicApp()
            } label: {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Now Playing").font(.geist(9)).foregroundStyle(.gray)
                if musicManager.hasActiveMediaSession {
                    Text(musicManager.songTitle).font(.geist(12, .semibold)).foregroundStyle(.primary).lineLimit(1)
                    Text(musicManager.artistName).font(.geist(10)).foregroundStyle(.gray).lineLimit(1)
                    if musicManager.songDuration > 0 {
                        protoPlaybackSlider
                    }
                    nowPlayingTransportControls
                } else {
                    Text("Nothing playing").font(.geist(12, .semibold)).foregroundStyle(.primary).lineLimit(1)
                    Text("Start music in any app").font(.geist(10)).foregroundStyle(.gray).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .protoCard()
    }

    private var protoPlaybackSlider: some View {
        TimelineView(.animation(minimumInterval: musicManager.isPlaying && musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            let livePosition = musicManager.estimatedPlaybackPosition(at: timeline.date)
            CustomSlider(
                value: Binding(
                    get: {
                        if draggingSlider { return sliderValue }
                        return livePosition
                    },
                    set: { sliderValue = $0 }
                ),
                range: 0...max(musicManager.songDuration, 1),
                color: .primary,
                dragging: $draggingSlider,
                lastDragged: $lastSliderDrag,
                onValueChange: { newValue in
                    MusicManager.shared.seek(to: newValue)
                },
                isEnabled: musicManager.canSeek
            )
            .frame(height: 14)
            .help(musicManager.canSeek ? "" : "Seeking isn't supported for Firefox video — use the page player")
            .onChange(of: livePosition) { _, newValue in
                // Hold the user's seek target briefly: browser backends
                // (Safari/Chrome via mediaremote-adapter) can take ~1s to
                // emit the new elapsedTime. Without this the slider snaps
                // back to the stale position right after release.
                guard !draggingSlider, lastSliderDrag.timeIntervalSinceNow > -1.0 else { return }
                sliderValue = newValue
            }
        }
    }

    private var nowPlayingTransportControls: some View {
        HStack(spacing: 6) {
            if musicManager.usesBrowserStyleTransport {
                transportButton(systemName: "gobackward.15", disabled: !musicManager.canSeek) {
                    MusicManager.shared.transportBackward()
                }
                transportButton(
                    systemName: musicManager.isPlaying ? "pause.fill" : "play.fill",
                    prominent: true
                ) {
                    MusicManager.shared.togglePlay()
                }
                transportButton(systemName: "goforward.15", disabled: !musicManager.canSeek) {
                    MusicManager.shared.transportForward()
                }
            } else {
                transportButton(systemName: "backward.fill") {
                    MusicManager.shared.transportBackward()
                }
                transportButton(
                    systemName: musicManager.isPlaying ? "pause.fill" : "play.fill",
                    prominent: true
                ) {
                    MusicManager.shared.togglePlay()
                }
                transportButton(systemName: "forward.fill") {
                    MusicManager.shared.transportForward()
                }
                transportButton(systemName: "gobackward.15") {
                    MusicManager.shared.skip(seconds: -15)
                }
                transportButton(systemName: "goforward.15") {
                    MusicManager.shared.skip(seconds: 15)
                }
            }
        }
        .font(.geist(11))
        .padding(.top, 2)
    }

    private func transportButton(
        systemName: String,
        prominent: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            BoringViewCoordinator.shared.pokeNavGrace()
            action()
        } label: {
            Image(systemName: systemName)
                .foregroundStyle(prominent ? Color.primary : Color.gray)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .help(disabled ? "Seeking isn't supported for Firefox video — use the page player" : "")
    }

    @ViewBuilder
    private var nextEventCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Next event").font(.geist(9)).foregroundStyle(.gray)
            if calendarManager.calendarAuthorizationStatus == .denied
                || calendarManager.calendarAuthorizationStatus == .restricted
            {
                Text("Calendar access off").font(.geist(12, .semibold)).foregroundStyle(.primary).lineLimit(1)
                Button("Open Settings") {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.geist(10))
                .foregroundStyle(.gray)
            } else if let event = nextEvent {
                Text(event.title).font(.geist(12, .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(ProtoCalendarHelpers.relativeEventSubtitle(for: event))
                    .font(.geist(10)).foregroundStyle(.primary).lineLimit(1)
                let more = ProtoCalendarHelpers.remainingTodayCount(
                    in: calendarManager.events, excluding: event)
                Text(more == 0 ? "No other events today" : "\(more) more today")
                    .font(.geist(9)).foregroundStyle(.gray)
            } else {
                Text("Nothing scheduled").font(.geist(12, .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text("Enjoy the free time").font(.geist(10)).foregroundStyle(.gray).lineLimit(1)
            }
        }
        .frame(width: 150, alignment: .leading)
        .protoCard()
    }
}

// MARK: 2 — Revenue (Stripe / Polar / Dodo / Lemon Squeezy)

struct RevenuePrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .revenue)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ProtoPill(text: "Stripe", selected: true)
                        ProtoPill(text: "Polar", selected: false)
                        ProtoPill(text: "Dodo", selected: false)
                        ProtoPill(text: "Lemon", selected: false)
                    }
                    HStack(spacing: 6) {
                        ProtoStatTile(label: "Today", value: "$482", sub: "+12% mock")
                        ProtoStatTile(label: "MRR", value: "$8.4k", sub: "+3.1% mock")
                        ProtoStatTile(label: "Orders", value: "36", sub: "mock")
                    }
                    ProtoSectionTitle(text: "Transactions — mock")
                    VStack(spacing: 4) {
                        ProtoMockRow(icon: "creditcard", title: "Pro plan — Acme", sub: "Stripe · 2m ago", trailing: "+$49")
                        ProtoMockRow(icon: "bolt.fill", title: "Lifetime — K. Rao", sub: "Polar · 1h ago", trailing: "+$149")
                        ProtoMockRow(icon: "cart", title: "Add-on — Studio", sub: "Dodo · 3h ago", trailing: "+$19")
                    }
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 3 — Analytics (DataFast / GA)

struct AnalyticsPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .analytics)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) { ProtoPill(text: "DataFast", selected: true); ProtoPill(text: "GA4", selected: false); Spacer() }
                    HStack(spacing: 6) {
                        ProtoStatTile(label: "Visitors", value: "1,204", sub: "mock")
                        ProtoStatTile(label: "Pageviews", value: "3,810", sub: "mock")
                        ProtoStatTile(label: "Bounce", value: "38%", sub: "mock")
                        ProtoStatTile(label: "Avg time", value: "2m 14s", sub: "mock")
                    }
                    ProtoSectionTitle(text: "Top pages — mock")
                    VStack(spacing: 4) {
                        ProtoMockRow(icon: "doc", title: "/pricing", sub: "842 views", trailing: "32%")
                        ProtoMockRow(icon: "doc", title: "/blog/notch-guide", sub: "511 views", trailing: "19%")
                        ProtoMockRow(icon: "doc", title: "/", sub: "406 views", trailing: "15%")
                    }
                    ProtoSectionTitle(text: "Referrers — mock")
                    HStack(spacing: 6) { ProtoPill(text: "X / Twitter", selected: false); ProtoPill(text: "Product Hunt", selected: false); ProtoPill(text: "Google", selected: false) }
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 4 — Scratchpad

struct ScratchpadPrototypeView: View {
    @AppStorage("protoScratchpadText") private var text = ""
    @AppStorage("protoScratchpadPinned") private var pinned = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .scratchpad)
            HStack {
                Text("Saved on this Mac").font(.geist(10)).foregroundStyle(.gray)
                Spacer()
                Button {
                    pinned.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: pinned ? "pin.fill" : "pin")
                            .font(.system(size: 10))
                            .foregroundStyle(pinned ? .primary : .secondary)
                        Text(pinned ? "Pinned" : "Pin").font(.geist(10)).foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(nsColor: .tertiarySystemFill)).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Jot anything here…")
                        .font(.geist(11))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.geist(11))
                    .foregroundStyle(.primary)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .protoCard()
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 6 — Calendar (7-day agenda + reminders)

struct CalendarPrototypeView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()
    @Environment(\.openURL) private var openURL

    private var filteredEvents: [EventModel] {
        ProtoCalendarHelpers.filteredEvents(calendarManager.events)
    }

    private var calendarEvents: [EventModel] {
        filteredEvents.filter { !$0.type.isReminder }
    }

    private var reminders: [EventModel] {
        filteredEvents.filter { $0.type.isReminder }
    }

    private var daysInSelectedWeek: [Date] {
        ProtoCalendarHelpers.weekDates(containing: selectedDate)
    }

    private var sectionTitle: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .calendarHub)
            if calendarManager.calendarAuthorizationStatus == .denied
                || calendarManager.calendarAuthorizationStatus == .restricted
            {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calendar access is required to show events.")
                        .font(.geist(11))
                        .foregroundStyle(.primary)
                    Button("Open Privacy Settings") {
                        if let url = URL(
                            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
                        {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.geist(10, .semibold))
                }
                .protoCard()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(daysInSelectedWeek, id: \.self) { day in
                                ProtoWeekDayCell(
                                    day: day,
                                    selectedDate: selectedDate,
                                    hasEvents: Calendar.current.isDate(day, inSameDayAs: selectedDate) && !filteredEvents.isEmpty
                                ) {
                                    selectedDate = day
                                    Task { await calendarManager.updateCurrentDate(day) }
                                }
                            }
                        }

                        ProtoSectionTitle(text: sectionTitle)
                        if calendarEvents.isEmpty {
                            Text("No events")
                                .font(.geist(11))
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .protoCard()
                        } else {
                            VStack(spacing: 4) {
                                ForEach(calendarEvents) { event in
                                    Button {
                                        if let url = event.calendarAppURL() { openURL(url) }
                                    } label: {
                                        ProtoLiveEventRow(event: event)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !reminders.isEmpty {
                            ProtoSectionTitle(text: "Reminders")
                            VStack(spacing: 4) {
                                ForEach(reminders) { reminder in
                                    ProtoLiveReminderRow(event: reminder)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
        .task {
            await calendarManager.checkCalendarAuthorization()
            await calendarManager.checkReminderAuthorization()
            await calendarManager.updateCurrentDate(Date.now)
            selectedDate = Date.now
        }
    }
}

private struct ProtoWeekDayCell: View {
    let day: Date
    let selectedDate: Date
    let hasEvents: Bool
    let onSelect: () -> Void

    private var isSelected: Bool {
        Calendar.current.isDate(day, inSameDayAs: selectedDate)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Text(ProtoCalendarHelpers.weekdayLetter(for: day))
                    .font(.geist(9))
                    .foregroundStyle(isSelected ? Color.primary : Color.gray)
                Text(day.formatted(.dateTime.day()))
                    .font(.geist(11, .semibold))
                    .foregroundStyle(isSelected ? Color(nsColor: .windowBackgroundColor) : .primary)
                    .frame(width: 22, height: 22)
                    .background(isSelected ? Color.primary : (isToday ? Color.primary.opacity(0.12) : Color.clear))
                    .clipShape(Circle())
                Circle()
                    .fill(isSelected && hasEvents ? Color.primary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .protoCard()
        }
        .buttonStyle(.plain)
    }
}

private struct ProtoLiveEventRow: View {
    let event: EventModel

    var body: some View {
        let trailing: String = {
            if event.isAllDay { return "All day" }
            if let location = event.location, !location.isEmpty {
                return location
            }
            return event.end.formatted(date: .omitted, time: .shortened)
        }()
        ProtoMockRow(
            icon: ProtoCalendarHelpers.eventIcon(for: event),
            title: event.title,
            sub: ProtoCalendarHelpers.relativeEventSubtitle(for: event),
            trailing: trailing
        )
    }
}

private struct ProtoLiveReminderRow: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    let event: EventModel

    private var isCompleted: Bool {
        if case .reminder(let completed) = event.type { return completed }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await calendarManager.setReminderCompleted(reminderID: event.id, completed: !isCompleted)
                }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .primary : .secondary)
                    .font(.geist(13))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.geist(11))
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                    .lineLimit(1)
                if !event.isAllDay {
                    Text(event.start.formatted(date: .omitted, time: .shortened))
                        .font(.geist(9))
                        .foregroundStyle(.gray)
                }
            }
            Spacer()
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: 7 — Timers

struct TimersPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .timers)
            HStack(spacing: 6) { ProtoPill(text: "Pomodoro", selected: true); ProtoPill(text: "Countdown", selected: false); ProtoPill(text: "Stopwatch", selected: false); ProtoPill(text: "Hydration", selected: false) }
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.25), lineWidth: 8).frame(width: 84, height: 84)
                    Circle().trim(from: 0, to: 0.65).stroke(Color.primary, lineWidth: 8).frame(width: 84, height: 84).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) { Text("16:20").font(.geist(16, .bold)).foregroundStyle(.primary); Text("Focus (mock)").font(.geist(9)).foregroundStyle(.gray) }
                }.protoCard()
                VStack(alignment: .leading, spacing: 6) {
                    ProtoSectionTitle(text: "Laps — mock")
                    ProtoMockRow(icon: "flag", title: "Lap 1", sub: "25:00", trailing: "")
                    ProtoMockRow(icon: "flag", title: "Lap 2", sub: "24:41", trailing: "")
                    HStack(spacing: 6) { ProtoPill(text: "Start", selected: true); ProtoPill(text: "Reset", selected: false) }
                }
            }
            Text("Hydration reminder: every 60 min (mock)").font(.geist(10)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 8 — Stats

struct StatsPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .stats)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ProtoBarRow(label: "CPU  24% (mock)", value: "4.2 GHz", frac: 0.24)
                    ProtoBarRow(label: "Memory  61% (mock)", value: "9.8 / 16 GB", frac: 0.61)
                    ProtoBarRow(label: "Disk  72% (mock)", value: "342 / 476 GB", frac: 0.72)
                    ProtoBarRow(label: "Network ↓↑ (mock)", value: "12 / 3 Mbps", frac: 0.4)
                    ProtoMockRow(icon: "battery.75", title: "Battery health 91%", sub: "Cycle 214 (mock)", trailing: "Normal")
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 9 — Screen Time

struct ScreenTimePrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .screentime)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ProtoStatTile(label: "Today", value: "4h 12m", sub: "mock")
                        ProtoStatTile(label: "Most used", value: "Xcode", sub: "1h 48m mock")
                        ProtoStatTile(label: "Pickups", value: "62", sub: "mock")
                    }
                    ProtoSectionTitle(text: "7-day breakdown — mock")
                    VStack(spacing: 5) {
                        ProtoBarRow(label: "Xcode", value: "9h 20m", frac: 0.9)
                        ProtoBarRow(label: "Safari", value: "6h 05m", frac: 0.6)
                        ProtoBarRow(label: "Figma", value: "4h 44m", frac: 0.47)
                        ProtoBarRow(label: "Slack", value: "3h 10m", frac: 0.32)
                    }
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 10 — Weather

struct WeatherPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .weather)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Bengaluru (mock)").font(.geist(11)).foregroundStyle(.gray)
                            Text("28°").font(.geist(32, .bold)).foregroundStyle(.primary)
                            Text("Feels 30° · Hum 62% · Wind 11 km/h · Rain 10%").font(.geist(9)).foregroundStyle(.gray)
                        }
                        Spacer()
                        Image(systemName: "cloud.sun.fill").font(.system(size: 34)).foregroundStyle(.primary)
                    }.protoCard()
                    ProtoSectionTitle(text: "Hourly — mock")
                    HStack(spacing: 6) {
                        ForEach(["2PM 29°", "3PM 29°", "4PM 28°", "5PM 27°", "6PM 26°"], id: \.self) { h in
                            Text(h).font(.geist(9)).foregroundStyle(.primary).padding(6).background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    ProtoSectionTitle(text: "7-day — mock")
                    VStack(spacing: 4) {
                        ProtoMockRow(icon: "sun.max.fill", title: "Today", sub: "Sunny", trailing: "29° / 21°")
                        ProtoMockRow(icon: "cloud.rain.fill", title: "Tue", sub: "Showers", trailing: "27° / 20°")
                        ProtoMockRow(icon: "cloud.fill", title: "Wed", sub: "Cloudy", trailing: "28° / 20°")
                    }
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 11 — Clipboard

struct ClipboardPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .clipboard)
            HStack(spacing: 6) { ProtoPill(text: "All", selected: true); ProtoPill(text: "Text", selected: false); ProtoPill(text: "Links", selected: false); ProtoPill(text: "Images", selected: false); ProtoPill(text: "Files", selected: false) }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.gray).font(.system(size: 11))
                Text("Search history… (mock)").font(.geist(11)).foregroundStyle(.gray)
                Spacer()
            }.padding(7).background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ProtoMockRow(icon: "doc.plaintext", title: "PRD snippet: notch launcher", sub: "Notes · 2m ago (mock)", trailing: "Copy")
                    ProtoMockRow(icon: "link", title: "github.com/TheBoredTeam/…", sub: "Safari · 18m ago (mock)", trailing: "Copy")
                    ProtoMockRow(icon: "photo", title: "Screenshot 2026-09-24", sub: "Preview · 1h ago (mock)", trailing: "View")
                    ProtoMockRow(icon: "doc.fill", title: "invoice-aug.pdf", sub: "Finder · 3h ago (mock)", trailing: "Open")
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 12 — Notes

struct NotesPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .notes)
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(["Launch checklist", "Meeting notes", "Ideas"], id: \.self) { t in
                        Text(t).font(.geist(10)).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                            .background(Color.primary.opacity(t == "Launch checklist" ? 0.1 : 0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                }.frame(width: 130)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch checklist (mock)").font(.geist(12, .semibold)).foregroundStyle(.primary)
                    Text("— Test on non-notch Mac\n— Polish empty states\n— Write release notes")
                        .font(.geist(11)).foregroundStyle(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .protoCard()
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 13 — Files (convert / compress)

struct FilesPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .files)
            HStack(spacing: 6) { ProtoPill(text: "JPEG", selected: true); ProtoPill(text: "PNG", selected: false); ProtoPill(text: "HEIC", selected: false); ProtoPill(text: "PDF", selected: false) }
            HStack {
                VStack(alignment: .leading) { Text("Quality (mock)").font(.geist(10)).foregroundStyle(.gray); ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3)).frame(height: 4); RoundedRectangle(cornerRadius: 2).fill(Color.primary).frame(width: 120, height: 4) } }
                Spacer()
                VStack(alignment: .leading) { Text("Max size (mock)").font(.geist(10)).foregroundStyle(.gray); Text("2048 px").font(.geist(11)).foregroundStyle(.primary) }
            }.protoCard()
            HStack {
                Image(systemName: "square.and.arrow.down").foregroundStyle(.gray)
                Text("Drop images here (mock)").font(.geist(11)).foregroundStyle(.gray)
                Spacer()
                Text("Convert").font(.geist(11, .semibold)).foregroundStyle(Color(nsColor: .windowBackgroundColor)).padding(.horizontal, 10).padding(.vertical, 5).background(Color.primary).clipShape(Capsule())
            }.padding(10).background(Color.primary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(Color.gray.opacity(0.4)))
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 14 — Links

struct LinksPrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .links)
            HStack(spacing: 6) { ProtoPill(text: "Google", selected: true); ProtoPill(text: "DuckDuckGo", selected: false); ProtoPill(text: "Perplexity", selected: false); ProtoPill(text: "YouTube", selected: false); ProtoPill(text: "GitHub", selected: false) }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.gray).font(.system(size: 11))
                Text("Search… (mock)").font(.geist(11)).foregroundStyle(.gray)
                Spacer()
            }.padding(7).background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
            ProtoSectionTitle(text: "Pinned — mock")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                ForEach(["Linear", "Figma", "GitHub", "Vercel", "Notion", "X", "HN", "+"], id: \.self) { s in
                    Text(s).font(.geist(10)).foregroundStyle(.primary).frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 15 — Emoji

struct EmojiPrototypeView: View {
    let emojis = ["😀", "🎉", "🔥", "👍", "❤️", "🚀", "☕", "💡", "🎧", "📦", "🌈", "⚡️", "🐶", "🌙", "🍕", "💻", "📚", "✨", "🎨", "🏆", "🤝", "📌", "💤", "🦄"]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .emoji)
            HStack(spacing: 6) { ProtoPill(text: "All", selected: true); ProtoPill(text: "Smileys", selected: false); ProtoPill(text: "Objects", selected: false); ProtoPill(text: "Symbols", selected: false) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 4) {
                ForEach(emojis, id: \.self) { e in
                    Text(e).font(.geist(15)).frame(maxWidth: .infinity).padding(.vertical, 4).background(Color.primary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
            Text("Prototype: tap does nothing.").font(.geist(9)).foregroundStyle(.gray)
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 16 — Sounds

struct SoundsPrototypeView: View {
    let sounds = ["Rain", "Forest", "Coffee shop", "Office", "Lo-fi", "Fireworks", "Whispers", "Waves"]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .sounds)
            Text("Layer multiple sounds (mock)").font(.geist(10)).foregroundStyle(.gray)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                ForEach(sounds, id: \.self) { s in
                    VStack(spacing: 3) {
                        Image(systemName: s == "Rain" || s == "Waves" ? "drop.fill" : "speaker.wave.2.fill").foregroundStyle(s == "Rain" || s == "Lo-fi" ? .primary : .secondary).font(.system(size: 13))
                        Text(s).font(.geist(9)).foregroundStyle(.primary).lineLimit(1)
                        Text(s == "Rain" || s == "Lo-fi" ? "On · 60%" : "Off").font(.geist(8)).foregroundStyle(.gray)
                    }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.primary.opacity(s == "Rain" || s == "Lo-fi" ? 0.1 : 0.05)).clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 17 — Message (scrolling dot-matrix)

struct MessagePrototypeView: View {
    @State private var text = "Hello notch ✦ prototype"
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .message)
            HStack {
                Image(systemName: "text.bubble").foregroundStyle(.gray).font(.system(size: 11))
                TextField("Custom message…", text: $text).textFieldStyle(.plain).font(.geist(11))
            }.padding(7).background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 6) { ProtoPill(text: "Bounce", selected: true); ProtoPill(text: "Wave", selected: false); ProtoPill(text: "Sparkle", selected: false); ProtoPill(text: "Pulse", selected: false); ProtoPill(text: "Rainbow", selected: false) }
            Text("● ● ●  \(text)  ● ● ●").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.black).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
            Text("Prototype: preview only, no notch animation.").font(.geist(9)).foregroundStyle(.gray)
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 18 — Claude (code stats)

struct ClaudePrototypeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .claude)
            HStack(spacing: 6) {
                ProtoStatTile(label: "Tokens", value: "1.2M", sub: "mock")
                ProtoStatTile(label: "Messages", value: "3,418", sub: "mock")
                ProtoStatTile(label: "Tool calls", value: "892", sub: "mock")
            }
            HStack(spacing: 6) {
                ProtoStatTile(label: "Sessions", value: "47", sub: "mock")
                ProtoStatTile(label: "Projects", value: "6", sub: "mock")
                ProtoStatTile(label: "Streak", value: "12d 🔥", sub: "mock")
            }
            ProtoSectionTitle(text: "Activity — mock")
            HStack(alignment: .bottom, spacing: 5) {
                ForEach([0.3, 0.5, 0.4, 0.8, 0.6, 0.9, 0.7], id: \.self) { h in
                    RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.85)).frame(maxWidth: .infinity, maxHeight: .infinity).scaleEffect(y: h, anchor: .bottom).frame(height: 44)
                }
            }.frame(height: 48).protoCard()
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: 19 — Units

struct UnitsPrototypeView: View {
    @State private var input = "100"
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtoHeader(view: .units)
            HStack(spacing: 6) { ProtoPill(text: "Length", selected: true); ProtoPill(text: "Weight", selected: false); ProtoPill(text: "Temp", selected: false); ProtoPill(text: "Currency", selected: false) }
            HStack(spacing: 8) {
                VStack(alignment: .leading) {
                    Text("From (mock)").font(.geist(9)).foregroundStyle(.gray)
                    HStack { TextField("100", text: $input).textFieldStyle(.plain).font(.geist(14, .bold)); Text("km").font(.geist(11)).foregroundStyle(.gray) }
                    .padding(8).background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Image(systemName: "arrow.right").foregroundStyle(.gray)
                VStack(alignment: .leading) {
                    Text("To (mock)").font(.geist(9)).foregroundStyle(.gray)
                    HStack { Text("62.14").font(.geist(14, .bold)).foregroundStyle(.primary); Text("mi").font(.geist(11)).foregroundStyle(.gray); Spacer() }
                    .padding(8).background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            ProtoSectionTitle(text: "Quick conversions — mock")
            VStack(spacing: 4) {
                ProtoMockRow(icon: "ruler", title: "1 km → 0.62 mi", sub: "Length", trailing: "")
                ProtoMockRow(icon: "thermometer", title: "25°C → 77°F", sub: "Temperature", trailing: "")
                ProtoMockRow(icon: "dollarsign", title: "$100 → ₹8,340", sub: "Currency (mock rate)", trailing: "")
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 6)
    }
}

// MARK: - PROTOTYPE DOCK (bottom navbar, content above — like the reference dock)
// Icons: genuine macOS app icons via NSWorkspace where a real app maps to the
// feature (same visual language as macosicons galleries); SF Symbols elsewhere.
// B&W theme: app icons desaturated, selected item = white circle (reference style).

private enum ProtoIconProvider {
    static func appPath(for view: NotchViews) -> String? {
        switch view {
        case .revenue: return "/Applications/Numbers.app"
        case .scratchpad: return "/System/Applications/Stickies.app"
        case .calendarHub: return "/System/Applications/Calendar.app"
        case .stats: return "/System/Applications/Utilities/Activity Monitor.app"
        case .weather: return "/System/Applications/Weather.app"
        case .notes: return "/System/Applications/Notes.app"
        case .files: return "/System/Library/CoreServices/Finder.app"
        case .links: return "/Applications/Safari.app"
        case .sounds: return "/System/Applications/Music.app"
        case .message: return "/System/Applications/Messages.app"
        case .units: return "/System/Applications/Calculator.app"
        default: return nil
        }
    }

    private static var cache: [String: NSImage] = [:]

    static func nsImage(for view: NotchViews) -> NSImage? {
        guard let path = appPath(for: view),
              FileManager.default.fileExists(atPath: path)
        else { return nil }
        if let hit = cache[path] { return hit }
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 64, height: 64)
        cache[path] = img
        return img
    }
}

private struct ProtoDockIcon: View {
    let view: NotchViews
    let selected: Bool
    var body: some View {
        ZStack {
            if selected {
                Circle().fill(.primary).frame(width: 22, height: 22)
            }
            Group {
                if let nsImg = ProtoIconProvider.nsImage(for: view) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .saturation(0)
                        .opacity(selected ? 1 : 0.6)
                } else {
                    Image(systemName: view.protoIcon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selected ? Color(nsColor: .windowBackgroundColor) : .secondary)
                }
            }
            .frame(width: 18, height: 18)
        }
        .frame(width: 24, height: 24)
    }
}

private struct ProtoDockButtons: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    var body: some View {
        ForEach(NotchViews.dockItems, id: \.protoTitle) { item in
            Button {
                coordinator.navigate(to: item)
            } label: {
                ProtoDockIcon(view: item, selected: coordinator.currentView == item)
            }
            .buttonStyle(.plain)
            .help(item.protoTitle)
        }
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 20)
        Button {
            coordinator.pokeNavGrace()
            withAnimation(.smooth) { coordinator.protoDockVertical.toggle() }
        } label: {
            Image(systemName: coordinator.protoDockVertical ? "arrow.left.and.right" : "arrow.up.and.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(coordinator.protoDockVertical ? "Horizontal dock" : "Vertical rail")
        Button {
            withAnimation(.smooth) { coordinator.protoDarkMode.toggle() }
        } label: {
            Image(systemName: coordinator.protoDarkMode ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(coordinator.protoDarkMode ? "Light mode" : "Dark mode")
    }
}

private struct ProtoDockBar: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ProtoDockButtons()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(Color.primary.opacity(0.07))
        .clipShape(Capsule())
    }
}

private struct ProtoRailBar: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                ProtoDockButtons()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 48)
        .background(Color.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// Content above, dock navbar pinned at bottom always (horizontal) or rail full-height (vertical).
struct ProtoShell<Content: View>: View {
    let content: Content
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if coordinator.protoDockVertical {
                HStack(alignment: .top, spacing: 8) {
                    ProtoRailBar()
                        .frame(maxHeight: .infinity)
                    content
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    content
                        .frame(maxWidth: .infinity, alignment: .top)
                    Spacer(minLength: 0)
                    ProtoDockBar()
                }
            }
        }
    }
}
