import SwiftUI
import AVFoundation

/// View displaying timed metadata from body camera or specialized video files
public struct MetadataDisplayView: View {
    @ObservedObject var metadataService: TimedMetadataService
    @State private var searchText = ""

    public init(metadataService: TimedMetadataService) {
        self.metadataService = metadataService
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.blue)
                Text("Video Metadata")
                    .font(.headline)

                Spacer()

                if metadataService.hasTimedMetadata {
                    Text("\(metadataService.metadataEntries.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if metadataService.hasTimedMetadata {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search metadata...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .padding(.horizontal)
                .padding(.top, 8)

                // Current metadata display (at current video time)
                if !metadataService.currentMetadata.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Metadata")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(metadataService.currentMetadata.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    Text(metadataService.currentMetadata[key] ?? "")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)

                    Divider()
                }

                // All metadata entries
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredEntries) { entry in
                            MetadataEntryRow(entry: entry)
                        }
                    }
                    .padding()
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Timed Metadata")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("This video does not contain embedded metadata tracks.\n\nBody camera footage typically includes GPS, timestamps, and officer IDs.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var filteredEntries: [TimedMetadataEntry] {
        if searchText.isEmpty {
            return metadataService.metadataEntries
        }
        return metadataService.metadataEntries.filter { entry in
            entry.key.localizedCaseInsensitiveContains(searchText) ||
            entry.value.localizedCaseInsensitiveContains(searchText)
        }
    }
}

/// Individual metadata entry row
struct MetadataEntryRow: View {
    let entry: TimedMetadataEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Timestamp header
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatTime(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let identifier = entry.identifier {
                    Text(identifier)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Key-value pair
            HStack(alignment: .top, spacing: 8) {
                Text(entry.key)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(width: 120, alignment: .leading)

                Text(entry.value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func formatTime(_ time: CMTime) -> String {
        let seconds = time.seconds
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%03d", hours, minutes, secs, ms)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, secs, ms)
        }
    }
}

#Preview {
    MetadataDisplayView(metadataService: TimedMetadataService())
        .frame(width: 400, height: 600)
}
