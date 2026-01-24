import SwiftUI
import SharedUtilities

/// View for displaying transcript with search and interaction
public struct TranscriptView: View {

    @ObservedObject public var viewModel: TranscriptViewModel
    public var onEntryTapped: ((TranscriptEntry) -> Void)?

    @State private var editingEntry: TranscriptEntry?
    @State private var editedText: String = ""

    public init(viewModel: TranscriptViewModel, onEntryTapped: ((TranscriptEntry) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onEntryTapped = onEntryTapped
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search transcript", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Transcript list
            if viewModel.entries.isEmpty {
                placeholderView
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.filteredEntries) { entry in
                            TranscriptEntryRow(
                                entry: entry,
                                isActive: entry.id == viewModel.currentEntryID,
                                isEditing: editingEntry?.id == entry.id,
                                editedText: $editedText,
                                onTap: {
                                    onEntryTapped?(entry)
                                },
                                onEdit: {
                                    editingEntry = entry
                                    editedText = entry.text
                                },
                                onSave: {
                                    viewModel.updateEntry(entry, text: editedText)
                                    editingEntry = nil
                                },
                                onCancel: {
                                    editingEntry = nil
                                }
                            )
                            .id(entry.id)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: viewModel.currentEntryID) { newID in
                        if let newID = newID {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }

    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.bubble")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Transcript Yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Load a video to automatically generate a transcript")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Individual transcript entry row
struct TranscriptEntryRow: View {
    let entry: TranscriptEntry
    let isActive: Bool
    let isEditing: Bool
    @Binding var editedText: String
    let onTap: () -> Void
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Text content
            VStack(alignment: .leading, spacing: 6) {
                if isEditing {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 60)
                        .font(.body)

                    HStack {
                        Button("Cancel") { onCancel() }
                        Button("Save") { onSave() }
                            .keyboardShortcut(.return, modifiers: [.command])
                    }
                } else {
                    Text(entry.text)
                        .font(.body)
                        .foregroundColor(isActive ? .primary : .secondary)
                        .fontWeight(isActive ? .medium : .regular)
                }
            }

            Spacer(minLength: 8)

            // Time bubble at trailing edge
            Text(TimeFormatter.toDisplayFormat(entry.startTime))
                .font(.caption2)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .foregroundColor(.secondary)
                .cornerRadius(8)
        }
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onTap()
            }
        }
        .contextMenu {
            Button("Edit") {
                onEdit()
            }
        }
    }
}
