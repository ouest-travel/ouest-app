import SwiftUI

struct BalanceSummaryView: View {
    @Bindable var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var contentAppeared = false

    /// Settlement queued for the "are you sure?" confirmation. Lifted to the
    /// root view so a single dialog handles every settlement card.
    @State private var settlementToConfirm: Settlement?
    @State private var isSettling = false

    /// Group queued for undo confirmation.
    @State private var groupToUndo: SettledGroup?
    @State private var isUndoing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xl) {
                    // Member balances
                    balancesSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                    // Settlements
                    if !viewModel.settlements.isEmpty {
                        settlementsSection
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)
                    }

                    // Already-settled — with per-group Undo
                    if !viewModel.settledGroups.isEmpty {
                        settledSection
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.lg)
                .padding(.vertical, OuestTheme.Spacing.md)
            }
            .navigationTitle("Balances")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
            .confirmationDialog(
                settlementToConfirm.map {
                    "Mark \($0.formattedAmount) from \(firstName($0.from.name)) to \(firstName($0.to.name)) as paid?"
                } ?? "",
                isPresented: confirmBinding,
                titleVisibility: .visible,
                presenting: settlementToConfirm
            ) { settlement in
                Button("Mark Paid") {
                    let s = settlement
                    Task {
                        isSettling = true
                        await viewModel.markSettlementPaid(s)
                        isSettling = false
                        settlementToConfirm = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    settlementToConfirm = nil
                }
            } message: { _ in
                Text("This marks the matching unsettled splits as paid. If it was a mistake, you can undo it from the Settled section below.")
            }
            .confirmationDialog(
                groupToUndo.map {
                    "Undo \(formatCurrency($0.amount)) from \(firstName($0.debtorName)) to \(firstName($0.payerName))?"
                } ?? "",
                isPresented: undoBinding,
                titleVisibility: .visible,
                presenting: groupToUndo
            ) { group in
                Button("Undo", role: .destructive) {
                    let g = group
                    Task {
                        isUndoing = true
                        await viewModel.unsettleGroup(g)
                        isUndoing = false
                        groupToUndo = nil
                    }
                }
                Button("Keep as settled", role: .cancel) {
                    groupToUndo = nil
                }
            } message: { _ in
                Text("This will re-open the underlying splits as unpaid so they show up in Suggested Settlements again.")
            }
        }
    }

    private var confirmBinding: Binding<Bool> {
        Binding(
            get: { settlementToConfirm != nil },
            set: { if !$0 { settlementToConfirm = nil } }
        )
    }

    // MARK: - Balances Section

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Who Paid What")
                .font(OuestTheme.Typography.sectionTitle)

            VStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(viewModel.memberBalances) { balance in
                    HStack(spacing: OuestTheme.Spacing.md) {
                        AvatarView(url: balance.avatarUrl, size: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(balance.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            // Concatenated into a SINGLE Text so the runtime
                            // treats "Paid US$995.00 · Owes US$0.00" as one
                            // layout unit. Previously each fragment was its
                            // own Text inside an HStack, which meant SwiftUI
                            // could line-break in the middle of a currency
                            // value (e.g. "US$995." / "00" stacked).
                            (
                                Text("Paid ").foregroundStyle(OuestTheme.Colors.textSecondary)
                                + Text(formatCurrency(balance.totalPaid)).fontWeight(.medium)
                                + Text("  ·  ").foregroundStyle(OuestTheme.Colors.textSecondary)
                                + Text("Owes ").foregroundStyle(OuestTheme.Colors.textSecondary)
                                + Text(formatCurrency(balance.totalOwed)).fontWeight(.medium)
                            )
                            .font(OuestTheme.Typography.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .minimumScaleFactor(0.85)
                        }

                        Spacer(minLength: OuestTheme.Spacing.sm)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(balance.formattedBalance)
                                .font(OuestTheme.Typography.cardTitle)
                                .fontWeight(.semibold)
                                .foregroundStyle(balanceColor(balance.netBalance))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(balanceLabel(balance.netBalance))
                                .font(OuestTheme.Typography.micro)
                                .foregroundStyle(balanceColor(balance.netBalance))
                                .lineLimit(1)
                        }
                        // Keep the trailing balance from elbowing the leading
                        // summary off the row when both have large numbers.
                        .layoutPriority(0.5)
                    }
                    .padding(OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                    .ouestElevation(.sm)
                }
            }
        }
    }

    // MARK: - Settlements Section

    private var settlementsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(OuestTheme.Colors.brand)
                Text("Suggested Settlements")
                    .font(OuestTheme.Typography.sectionTitle)
            }

            VStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(viewModel.settlements) { settlement in
                    settlementCard(settlement)
                }
            }
        }
    }

    /// One row in the suggested-settlements list. From-avatar → amount →
    /// to-avatar on the top half, "Mark Paid" CTA on the bottom half. Taps
    /// the CTA → confirmation dialog → batch-settle the direct splits.
    private func settlementCard(_ settlement: Settlement) -> some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.md) {
                // From person
                VStack(spacing: 2) {
                    AvatarView(url: settlement.from.avatarUrl, size: 36)
                    Text(firstName(settlement.from.name))
                        .font(OuestTheme.Typography.micro)
                        .lineLimit(1)
                }
                .frame(width: 56)

                // Arrow with amount
                VStack(spacing: 2) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(OuestTheme.Colors.brand)
                    Text(settlement.formattedAmount)
                        .font(OuestTheme.Typography.cardTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(OuestTheme.Colors.brand)
                }

                // To person
                VStack(spacing: 2) {
                    AvatarView(url: settlement.to.avatarUrl, size: 36)
                    Text(firstName(settlement.to.name))
                        .font(OuestTheme.Typography.micro)
                        .lineLimit(1)
                }
                .frame(width: 56)

                Spacer()
            }

            Button {
                HapticFeedback.light()
                settlementToConfirm = settlement
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Mark Paid")
                }
                .font(OuestTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(OuestTheme.Colors.brand)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSettling)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.brand.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
    }

    // MARK: - Settled Section

    private var settledSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(OuestTheme.Colors.success)
                Text("Settled")
                    .font(OuestTheme.Typography.sectionTitle)
            }

            VStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(viewModel.settledGroups) { group in
                    settledCard(group)
                }
            }
        }
    }

    /// One row per (debtor, payer) with a subtle Undo pill. Symmetric to
    /// `settlementCard`, but tinted success-green and gated by a confirmation
    /// dialog so a fat-fingered undo doesn't silently resurface old debts.
    private func settledCard(_ group: SettledGroup) -> some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            // From (debtor) — the one who paid it back
            VStack(spacing: 2) {
                AvatarView(url: group.debtorAvatarUrl, size: 36)
                Text(firstName(group.debtorName))
                    .font(OuestTheme.Typography.micro)
                    .lineLimit(1)
            }
            .frame(width: 56)

            // Amount + "settled …ago"
            VStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundStyle(OuestTheme.Colors.success)
                Text(formatCurrency(group.amount))
                    .font(OuestTheme.Typography.cardTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(OuestTheme.Colors.success)
                if let when = group.latestSettledAt {
                    Text(relativeSettledLabel(when))
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            // To (payer)
            VStack(spacing: 2) {
                AvatarView(url: group.payerAvatarUrl, size: 36)
                Text(firstName(group.payerName))
                    .font(OuestTheme.Typography.micro)
                    .lineLimit(1)
            }
            .frame(width: 56)

            Spacer()

            Button {
                HapticFeedback.light()
                groupToUndo = group
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                    Text("Undo")
                }
                .font(OuestTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(OuestTheme.Colors.surface)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isUndoing)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.success.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
    }

    private var undoBinding: Binding<Bool> {
        Binding(
            get: { groupToUndo != nil },
            set: { if !$0 { groupToUndo = nil } }
        )
    }

    // MARK: - Helpers

    private func balanceColor(_ net: Double) -> Color {
        if net > 0.01 { return OuestTheme.Colors.success }
        if net < -0.01 { return OuestTheme.Colors.error }
        return OuestTheme.Colors.textSecondary
    }

    private func balanceLabel(_ net: Double) -> String {
        if net > 0.01 { return "gets back" }
        if net < -0.01 { return "owes" }
        return "settled"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.trip.currency ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func firstName(_ fullName: String) -> String {
        fullName.components(separatedBy: " ").first ?? fullName
    }

    /// "5m ago", "3h ago", "2d ago" — matches the tone of other timestamps in
    /// the app without pulling in a full formatter dependency.
    private func relativeSettledLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    BalanceSummaryView(viewModel: ExpensesViewModel(trip: Trip(
        id: UUID(), createdBy: UUID(),
        title: "Test", destination: "Test",
        status: .planning, isPublic: false,
        createdAt: Date(), updatedAt: Date()
    )))
}
