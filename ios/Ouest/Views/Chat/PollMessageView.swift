import SwiftUI

// MARK: - Poll Model

struct Poll: Identifiable, Codable {
    let id: String
    let question: String
    let options: [PollOption]
    let createdBy: String
    let createdAt: Date
    var isAnonymous: Bool
    var allowMultiple: Bool
    var endsAt: Date?

    struct PollOption: Identifiable, Codable {
        let id: String
        let text: String
        var votes: [String] // User IDs who voted for this option
    }

    var totalVotes: Int {
        options.reduce(0) { $0 + $1.votes.count }
    }

    var uniqueVoters: Set<String> {
        var voters = Set<String>()
        options.forEach { voters.formUnion($0.votes) }
        return voters
    }

    func hasVoted(_ userId: String) -> Bool {
        options.contains { $0.votes.contains(userId) }
    }

    func votedOption(for userId: String) -> PollOption? {
        options.first { $0.votes.contains(userId) }
    }
}

// MARK: - Poll Message View

struct PollMessageView: View {
    let poll: Poll
    let isCurrentUser: Bool
    let currentUserId: String
    let onVote: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            // Header
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(OuestTheme.Colors.primary)

                Text("Poll")
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }

            // Question
            Text(poll.question)
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)

            // Options
            VStack(spacing: OuestTheme.Spacing.xs) {
                ForEach(poll.options) { option in
                    PollOptionRow(
                        option: option,
                        totalVotes: poll.totalVotes,
                        hasVoted: poll.hasVoted(currentUserId),
                        isSelected: option.votes.contains(currentUserId),
                        onTap: { onVote(option.id) }
                    )
                }
            }

            // Footer
            HStack {
                Text("\(poll.uniqueVoters.count) \(poll.uniqueVoters.count == 1 ? "vote" : "votes")")
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textTertiary)

                if let endsAt = poll.endsAt {
                    Spacer()
                    Text("Ends \(endsAt.formatted(.relative(presentation: .named)))")
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.textTertiary)
                }
            }
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Poll Option Row

struct PollOptionRow: View {
    let option: Poll.PollOption
    let totalVotes: Int
    let hasVoted: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var percentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(option.votes.count) / Double(totalVotes)
    }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.small)
                        .fill(OuestTheme.Colors.inputBackground)

                    // Progress fill (only show if someone has voted)
                    if hasVoted {
                        RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.small)
                            .fill(
                                isSelected
                                    ? OuestTheme.Colors.primary.opacity(0.2)
                                    : OuestTheme.Colors.textTertiary.opacity(0.1)
                            )
                            .frame(width: geometry.size.width * percentage)
                    }

                    // Content
                    HStack {
                        // Selection indicator
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? OuestTheme.Colors.primary : OuestTheme.Colors.textTertiary)
                            .font(.system(size: 18))

                        Text(option.text)
                            .font(OuestTheme.Fonts.body)
                            .foregroundColor(OuestTheme.Colors.text)

                        Spacer()

                        if hasVoted {
                            Text("\(Int(percentage * 100))%")
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(OuestTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.sm)
                    .padding(.vertical, OuestTheme.Spacing.xs)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 44)
    }
}

// MARK: - Create Poll View

struct CreatePollView: View {
    @Environment(\.dismiss) var dismiss

    let tripId: String
    let onCreate: (Poll) -> Void

    @State private var question = ""
    @State private var options: [String] = ["", ""]
    @State private var isAnonymous = false
    @State private var allowMultiple = false
    @State private var hasEndDate = false
    @State private var endDate = Date().addingTimeInterval(24 * 60 * 60) // 24 hours from now

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Question
                        questionSection

                        // Options
                        optionsSection

                        // Settings
                        settingsSection
                    }
                    .padding(OuestTheme.Spacing.md)
                }
            }
            .navigationTitle("Create Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPoll()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !question.isEmpty && options.filter { !$0.isEmpty }.count >= 2
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text("Question")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            TextField("What do you want to ask?", text: $question, axis: .vertical)
                .font(OuestTheme.Fonts.body)
                .lineLimit(3...6)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.cardBackground)
                .cornerRadius(OuestTheme.CornerRadius.medium)
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Options")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            ForEach(options.indices, id: \.self) { index in
                HStack {
                    TextField("Option \(index + 1)", text: $options[index])
                        .font(OuestTheme.Fonts.body)
                        .padding(OuestTheme.Spacing.md)
                        .background(OuestTheme.Colors.cardBackground)
                        .cornerRadius(OuestTheme.CornerRadius.medium)

                    if options.count > 2 {
                        Button {
                            options.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(OuestTheme.Colors.error)
                        }
                    }
                }
            }

            if options.count < 6 {
                Button {
                    options.append("")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Option")
                    }
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.primary)
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Settings")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            OuestCard {
                VStack(spacing: 0) {
                    Toggle("Anonymous voting", isOn: $isAnonymous)
                        .font(OuestTheme.Fonts.body)
                        .padding(.vertical, OuestTheme.Spacing.xs)

                    Divider()

                    Toggle("Allow multiple choices", isOn: $allowMultiple)
                        .font(OuestTheme.Fonts.body)
                        .padding(.vertical, OuestTheme.Spacing.xs)

                    Divider()

                    Toggle("Set end date", isOn: $hasEndDate)
                        .font(OuestTheme.Fonts.body)
                        .padding(.vertical, OuestTheme.Spacing.xs)

                    if hasEndDate {
                        DatePicker("", selection: $endDate, in: Date()...)
                            .datePickerStyle(.compact)
                            .padding(.top, OuestTheme.Spacing.xs)
                    }
                }
            }
        }
    }

    private func createPoll() {
        let validOptions = options.filter { !$0.isEmpty }

        let poll = Poll(
            id: UUID().uuidString,
            question: question,
            options: validOptions.enumerated().map { index, text in
                Poll.PollOption(
                    id: UUID().uuidString,
                    text: text,
                    votes: []
                )
            },
            createdBy: "current-user", // TODO: Get current user
            createdAt: Date(),
            isAnonymous: isAnonymous,
            allowMultiple: allowMultiple,
            endsAt: hasEndDate ? endDate : nil
        )

        onCreate(poll)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Poll Message") {
    VStack(spacing: 16) {
        PollMessageView(
            poll: Poll(
                id: "1",
                question: "What day should we visit Tokyo Tower?",
                options: [
                    Poll.PollOption(id: "a", text: "Monday", votes: ["user1", "user2"]),
                    Poll.PollOption(id: "b", text: "Tuesday", votes: ["user3"]),
                    Poll.PollOption(id: "c", text: "Wednesday", votes: [])
                ],
                createdBy: "user1",
                createdAt: Date(),
                isAnonymous: false,
                allowMultiple: false,
                endsAt: nil
            ),
            isCurrentUser: false,
            currentUserId: "user1"
        ) { _ in }

        PollMessageView(
            poll: Poll(
                id: "2",
                question: "Which restaurant for dinner?",
                options: [
                    Poll.PollOption(id: "a", text: "Sushi place", votes: []),
                    Poll.PollOption(id: "b", text: "Ramen shop", votes: [])
                ],
                createdBy: "user2",
                createdAt: Date(),
                isAnonymous: false,
                allowMultiple: false,
                endsAt: Date().addingTimeInterval(3600)
            ),
            isCurrentUser: true,
            currentUserId: "user3"
        ) { _ in }
    }
    .padding()
    .background(OuestTheme.Colors.background)
}

#Preview("Create Poll") {
    CreatePollView(tripId: "demo-trip") { _ in }
}
