import SwiftUI

/// Paste-anything-AI-extracts-an-itinerary view.
///
/// Users paste:
///   • TikTok / Instagram / YouTube / blog URLs (server-side fetches OG tags + page text)
///   • Captions / transcripts / their own freeform notes (used directly)
///
/// On submit, the Edge Function calls Claude, populates `itinerary_days` +
/// `itinerary_activities`, and we re-fetch the itinerary in the parent ViewModel.
struct AIImportView: View {

    let trip: Trip
    @Bindable var viewModel: ItineraryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var inputText: String = ""
    @State private var appeared = false
    @FocusState private var inputFocused: Bool

    private var trimmed: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canImport: Bool {
        trimmed.count >= 10 && !viewModel.isGeneratingAI
    }

    private var characterCount: Int { trimmed.count }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isGeneratingAI {
                    loadingView
                } else {
                    formView
                }
            }
            .navigationTitle("Import with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isGeneratingAI)
                }
            }
            .alert(
                "Couldn't import itinerary",
                isPresented: aiErrorBinding,
                presenting: viewModel.aiError
            ) { _ in
                Button("OK", role: .cancel) { viewModel.aiError = nil }
            } message: { msg in
                Text(msg)
            }
            .onAppear {
                withAnimation(OuestTheme.Anim.smooth) {
                    appeared = true
                }
                // Auto-focus the text editor after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    inputFocused = true
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxl) {
                header

                supportedSourcesCard

                proTipCard

                inputSection

                importButton

                fineprint
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(OuestTheme.Colors.brandGradient)
                Text("Paste anything")
                    .font(OuestTheme.Typography.screenTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
            }
            Text("Drop a link, caption, or quick description and we'll turn it into a real itinerary for \(trip.destination).")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
        .fadeSlideIn(isVisible: appeared, delay: 0)
    }

    private var supportedSourcesCard: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Works with")
                .font(OuestTheme.Typography.micro)
                .fontWeight(.semibold)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            FlowingRow {
                sourcePill("Blog posts",       icon: "doc.text.fill")
                sourcePill("TikTok",           icon: "play.rectangle.fill")
                sourcePill("Instagram",        icon: "camera.fill")
                sourcePill("Reels",            icon: "film.fill")
                sourcePill("YouTube",          icon: "play.tv.fill")
                sourcePill("Your own notes",   icon: "note.text")
            }
        }
        .fadeSlideIn(isVisible: appeared, delay: 0.05)
    }

    // MARK: - Pro Tip Callout

    private var proTipCard: some View {
        HStack(alignment: .top, spacing: OuestTheme.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Pro tip")
                        .font(OuestTheme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                    Text("·")
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    Text("YouTube + travel blogs work best")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                Text("Travel YouTubers paste day-by-day breakdowns in their video descriptions, and blogs have full article text — both extract almost perfectly. TikTok and Instagram captions work too, just shorter.")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(OuestTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: OuestTheme.Radius.md)
                .fill(OuestTheme.Colors.brandLight)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OuestTheme.Radius.md)
                .strokeBorder(OuestTheme.Colors.brand.opacity(0.18), lineWidth: 1)
        }
        .fadeSlideIn(isVisible: appeared, delay: 0.08)
    }

    private func sourcePill(_ label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(OuestTheme.Typography.micro)
                .fontWeight(.medium)
        }
        .padding(.horizontal, OuestTheme.Spacing.sm)
        .padding(.vertical, 5)
        .background(OuestTheme.Colors.surfaceSecondary)
        .foregroundStyle(OuestTheme.Colors.textSecondary)
        .clipShape(Capsule())
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack {
                Text("Your input")
                    .font(OuestTheme.Typography.sectionTitle)
                Spacer()
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .focused($inputFocused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(OuestTheme.Spacing.md)
                    .frame(minHeight: 180, maxHeight: 320)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                    .autocorrectionDisabled(false)

                // Placeholder overlay
                if inputText.isEmpty {
                    Text("e.g. paste a TikTok link or describe what you want — \"3 days in Lisbon, hidden tapas spots, viewpoints, lots of walking\"")
                        .font(.body)
                        .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.5))
                        .padding(.horizontal, OuestTheme.Spacing.md + 4)
                        .padding(.vertical, OuestTheme.Spacing.md + 8)
                        .allowsHitTesting(false)
                }
            }

            // Character count + helper line
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: characterCount < 10 ? "info.circle" : "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(characterCount < 10 ? OuestTheme.Colors.textSecondary : OuestTheme.Colors.success)
                Text(characterCount < 10
                     ? "Paste at least a short caption or link"
                     : "\(characterCount) characters — looks good")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Spacer()
            }
        }
        .fadeSlideIn(isVisible: appeared, delay: 0.1)
    }

    // MARK: - Import Button

    private var importButton: some View {
        OuestButton(
            title: existingDaysCount > 0 ? "Replace with imported itinerary" : "Import itinerary",
            isLoading: viewModel.isGeneratingAI
        ) {
            Task {
                let success = await viewModel.importAIItinerary(inputText: trimmed)
                if success {
                    dismiss()
                }
            }
        }
        .disabled(!canImport)
        .opacity(canImport ? 1 : 0.5)
        .fadeSlideIn(isVisible: appeared, delay: 0.15)
    }

    private var existingDaysCount: Int {
        viewModel.days.count
    }

    private var fineprint: some View {
        VStack(spacing: OuestTheme.Spacing.xs) {
            if existingDaysCount > 0 {
                Label(
                    "This will replace your current \(existingDaysCount)-day itinerary.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.warning)
                .multilineTextAlignment(.center)
            }
            Text("If a link doesn't extract well, paste the caption text directly — it works just as well.")
                .font(OuestTheme.Typography.micro)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OuestTheme.Spacing.lg)
        }
        .fadeSlideIn(isVisible: appeared, delay: 0.2)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        AIProgressView(
            icon: "wand.and.stars",
            phases: [
                "Reading your input…",
                "Extracting itinerary details…",
                "Looking up locations…",
                "Building your day-by-day plan…",
                "Adding final touches…",
            ],
            estimatedDuration: 32
        )
    }

    // MARK: - Helpers

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else { return }
        HapticFeedback.selection()
        if inputText.isEmpty {
            inputText = pasted
        } else {
            inputText += "\n" + pasted
        }
    }

    private var aiErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.aiError != nil },
            set: { if !$0 { viewModel.aiError = nil } }
        )
    }
}

// MARK: - Flowing Row (wraps source pills onto multiple lines)

/// Simple multi-line wrapping HStack that flows children left-to-right, wrapping
/// to the next row when they overflow the container width.
private struct FlowingRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // SwiftUI's `Layout` could do this more cleanly, but a simple LazyVGrid
        // with adaptive minimum gives the same visual effect with no custom layout code.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            content()
        }
    }
}

#Preview {
    let trip = Trip(
        id: UUID(), createdBy: UUID(),
        title: "Lisbon", destination: "Lisbon, Portugal",
        startDate: Date(),
        endDate: Date().addingTimeInterval(4 * 86400),
        status: .planning, isPublic: false,
        createdAt: Date(), updatedAt: Date()
    )
    return AIImportView(
        trip: trip,
        viewModel: ItineraryViewModel(trip: trip)
    )
    .environment(AuthViewModel())
}
