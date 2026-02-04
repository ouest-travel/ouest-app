import SwiftUI

// MARK: - Trip Detail Tab

enum TripDetailTab: String, CaseIterable {
    case overview = "Overview"
    case budget = "Budget"
    case chat = "Chat"
    case members = "Members"

    var icon: String {
        switch self {
        case .overview: return "info.circle"
        case .budget: return "creditcard"
        case .chat: return "bubble.left"
        case .members: return "person.2"
        }
    }
}

// MARK: - Trip Detail View

struct TripDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: TripDetailViewModel
    @State private var selectedTab: TripDetailTab = .overview
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) var dismiss

    let trip: Trip

    init(trip: Trip, repositories: RepositoryProvider? = nil) {
        self.trip = trip
        let repos = repositories ?? RepositoryProvider()
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(
            trip: trip,
            tripRepository: repos.tripRepository,
            expenseRepository: repos.expenseRepository,
            tripMemberRepository: repos.tripMemberRepository
        ))
    }

    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab Selector
                tabSelector

                // Tab Content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(TripDetailTab.overview)

                    budgetTab
                        .tag(TripDetailTab.budget)

                    chatTab
                        .tag(TripDetailTab.chat)

                    membersTab
                        .tag(TripDetailTab.members)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle(viewModel.trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Trip", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(OuestTheme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditTripSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete Trip",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    // TODO: Implement delete
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this trip? This action cannot be undone.")
        }
        .task {
            await viewModel.loadData()
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                ForEach(TripDetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(OuestTheme.Animation.spring) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(OuestTheme.Fonts.subheadline)
                        }
                        .foregroundColor(selectedTab == tab ? .white : OuestTheme.Colors.textSecondary)
                        .padding(.horizontal, OuestTheme.Spacing.md)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                        .background(
                            selectedTab == tab
                                ? AnyView(OuestTheme.Gradients.primary)
                                : AnyView(OuestTheme.Colors.inputBackground)
                        )
                        .cornerRadius(OuestTheme.CornerRadius.pill)
                    }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .padding(.vertical, OuestTheme.Spacing.sm)
        }
        .background(OuestTheme.Colors.cardBackground)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.lg) {
                // Trip Header Card
                tripHeaderCard

                // Quick Stats
                quickStatsGrid

                // Countdown / Status
                tripStatusCard

                // Description
                if let description = viewModel.trip.description, !description.isEmpty {
                    descriptionCard(description)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .padding(.vertical, OuestTheme.Spacing.md)
        }
    }

    private var tripHeaderCard: some View {
        OuestGradientCard(gradient: tripGradient) {
            VStack(spacing: OuestTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.trip.destination)
                            .font(OuestTheme.Fonts.title2)
                            .foregroundColor(.white)

                        Text(viewModel.trip.formattedDateRange)
                            .font(OuestTheme.Fonts.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Text(viewModel.trip.destinationEmoji)
                        .font(.system(size: 48))
                }

                if let budget = viewModel.trip.budget, budget > 0 {
                    Divider()
                        .background(Color.white.opacity(0.3))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Budget")
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(CurrencyFormatter.format(amount: budget, currency: viewModel.trip.currency))
                                .font(OuestTheme.Fonts.headline)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Spent")
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(CurrencyFormatter.format(amount: viewModel.totalSpent, currency: viewModel.trip.currency))
                                .font(OuestTheme.Fonts.headline)
                                .foregroundColor(.white)
                        }
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 8)

                            Capsule()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * min(viewModel.spentPercentage, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    private var tripGradient: LinearGradient {
        switch viewModel.trip.status {
        case .planning:
            return LinearGradient(colors: [OuestTheme.Colors.Brand.blue, OuestTheme.Colors.Brand.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .upcoming:
            return LinearGradient(colors: [OuestTheme.Colors.Brand.coral, OuestTheme.Colors.Brand.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .active:
            return OuestTheme.Gradients.primary
        case .completed:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: OuestTheme.Spacing.sm) {
            StatCard(
                title: "Days",
                value: "\(viewModel.trip.daysUntilStart ?? 0)",
                subtitle: viewModel.trip.status == .upcoming ? "until trip" : "total",
                icon: "calendar"
            )

            StatCard(
                title: "Members",
                value: "\(viewModel.members.count)",
                subtitle: "traveling",
                icon: "person.2"
            )

            StatCard(
                title: "Expenses",
                value: "\(viewModel.expenses.count)",
                subtitle: "tracked",
                icon: "receipt"
            )
        }
    }

    private var tripStatusCard: some View {
        OuestCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip Status")
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.textSecondary)

                    Text(viewModel.trip.status.displayName)
                        .font(OuestTheme.Fonts.headline)
                        .foregroundColor(viewModel.trip.status.color)
                }

                Spacer()

                Image(systemName: viewModel.trip.status.icon)
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.trip.status.color)
            }
        }
    }

    private func descriptionCard(_ description: String) -> some View {
        OuestCard {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                Text("About this trip")
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.textSecondary)

                Text(description)
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.text)
            }
        }
    }

    // MARK: - Budget Tab

    private var budgetTab: some View {
        BudgetTabContent(viewModel: viewModel)
    }

    // MARK: - Chat Tab

    private var chatTab: some View {
        ChatTabContent(
            trip: viewModel.trip,
            repositories: appState.repositories
        )
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        MembersTabContent(viewModel: viewModel)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var body: some View {
        OuestCard {
            VStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(OuestTheme.Colors.primary)

                Text(value)
                    .font(OuestTheme.Fonts.title2)
                    .foregroundColor(OuestTheme.Colors.text)

                Text(subtitle)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Budget Tab Content

struct BudgetTabContent: View {
    @ObservedObject var viewModel: TripDetailViewModel
    @State private var showAddExpense = false
    @State private var showSettleDebts = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.lg) {
                    // Budget Summary
                    budgetSummaryCard

                    // Settle Up Button (if there are debts)
                    if !viewModel.debts.isEmpty {
                        settleUpButton
                    }

                    // Category Breakdown
                    if !viewModel.expenses.isEmpty {
                        categoryBreakdown
                    }

                    // Expenses List
                    expensesSection
                }
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.md)
                .padding(.bottom, 80)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    OuestFAB(icon: "plus") {
                        showAddExpense = true
                    }
                    .padding(.trailing, OuestTheme.Spacing.md)
                    .padding(.bottom, OuestTheme.Spacing.md)
                }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(
                trip: viewModel.trip,
                members: viewModel.members
            ) { request in
                await viewModel.addExpense(request)
            }
        }
        .sheet(isPresented: $showSettleDebts) {
            SettleDebtsView(
                debts: viewModel.debts,
                trip: viewModel.trip
            ) { debt in
                // TODO: Implement settle debt
            }
        }
    }

    private var settleUpButton: some View {
        Button {
            showSettleDebts = true
        } label: {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16))

                Text("Settle Up")
                    .font(OuestTheme.Fonts.headline)

                Spacer()

                Text("\(viewModel.debts.count) payments")
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(OuestTheme.Colors.textTertiary)
            }
            .foregroundColor(OuestTheme.Colors.text)
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.cardBackground)
            .cornerRadius(OuestTheme.CornerRadius.medium)
        }
    }

    private var budgetSummaryCard: some View {
        OuestGradientCard {
            VStack(spacing: OuestTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Budget")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.8))

                        if viewModel.totalBudget > 0 {
                            Text(CurrencyFormatter.format(amount: viewModel.totalBudget, currency: viewModel.trip.currency))
                                .font(OuestTheme.Fonts.title)
                                .foregroundColor(.white)
                        } else {
                            Text("Not set")
                                .font(OuestTheme.Fonts.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()

                    Text(viewModel.trip.destinationEmoji)
                        .font(.system(size: 40))
                }

                if viewModel.totalBudget > 0 {
                    Divider()
                        .background(Color.white.opacity(0.3))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Spent")
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(CurrencyFormatter.format(amount: viewModel.totalSpent, currency: viewModel.trip.currency))
                                .font(OuestTheme.Fonts.headline)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Remaining")
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(CurrencyFormatter.format(amount: viewModel.remaining, currency: viewModel.trip.currency))
                                .font(OuestTheme.Fonts.headline)
                                .foregroundColor(viewModel.isOverBudget ? OuestTheme.Colors.error : .white)
                        }
                    }
                }
            }
        }
    }

    private var categoryBreakdown: some View {
        OuestCard {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                Text("By Category")
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)

                ForEach(Array(viewModel.expensesByCategory.keys), id: \.self) { category in
                    let expenses = viewModel.expensesByCategory[category] ?? []
                    let total = expenses.reduce(Decimal(0)) { $0 + $1.amount }

                    HStack {
                        Text(category.emoji)
                            .font(.system(size: 20))

                        Text(category.displayName)
                            .font(OuestTheme.Fonts.body)
                            .foregroundColor(OuestTheme.Colors.text)

                        Spacer()

                        Text(CurrencyFormatter.format(amount: total, currency: viewModel.trip.currency))
                            .font(OuestTheme.Fonts.headline)
                            .foregroundColor(OuestTheme.Colors.text)
                    }
                    .padding(.vertical, OuestTheme.Spacing.xxs)
                }
            }
        }
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("All Expenses")
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)

            if viewModel.expenses.isEmpty {
                emptyExpensesView
            } else {
                LazyVStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(viewModel.expenses) { expense in
                        ExpenseRowView(expense: expense) {
                            Task {
                                await viewModel.deleteExpense(expense)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyExpensesView: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "receipt")
                .font(.system(size: 40))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No expenses yet")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            Text("Tap + to add your first expense")
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OuestTheme.Spacing.xl)
    }
}

// MARK: - Expense Row View

struct ExpenseRowView: View {
    let expense: Expense
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(expense.category.emoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.text)

                Text(expense.category.displayName)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }

            Spacer()

            Text(expense.formattedAmount)
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)
        }
        .padding(OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Chat Tab Content

struct ChatTabContent: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ChatViewModel

    init(trip: Trip, repositories: RepositoryProvider) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            tripId: trip.id,
            chatRepository: repositories.chatRepository
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: OuestTheme.Spacing.sm) {
                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.messages.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(viewModel.messages) { message in
                                ChatMessageRow(
                                    message: message,
                                    isCurrentUser: viewModel.isCurrentUser(message)
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.vertical, OuestTheme.Spacing.sm)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input
            chatInputView
        }
        .task {
            await viewModel.loadMessages()
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    private var loadingView: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            ForEach(0..<5, id: \.self) { index in
                HStack {
                    if index % 2 == 0 { Spacer() }
                    RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                        .fill(OuestTheme.Colors.inputBackground)
                        .frame(width: 200, height: 60)
                        .shimmer()
                    if index % 2 != 0 { Spacer() }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No messages yet")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            Text("Start the conversation!")
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OuestTheme.Spacing.xxl)
    }

    private var chatInputView: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            TextField("Type a message...", text: $viewModel.newMessageText)
                .font(OuestTheme.Fonts.body)
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.sm)
                .background(OuestTheme.Colors.inputBackground)
                .cornerRadius(20)

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.canSend ? OuestTheme.Colors.primary : OuestTheme.Colors.textTertiary)
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, OuestTheme.Spacing.md)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.cardBackground)
    }
}

// MARK: - Members Tab Content

struct MembersTabContent: View {
    @ObservedObject var viewModel: TripDetailViewModel
    @State private var showInviteSheet = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.lg) {
                    // Members List
                    membersListView

                    // Debts Section
                    if !viewModel.debts.isEmpty {
                        debtsSection
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.md)
                .padding(.bottom, 80)
            }

            // Invite FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    OuestFAB(icon: "person.badge.plus") {
                        showInviteSheet = true
                    }
                    .padding(.trailing, OuestTheme.Spacing.md)
                    .padding(.bottom, OuestTheme.Spacing.md)
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteMemberSheet(viewModel: viewModel)
        }
    }

    private var membersListView: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack {
                Text("Trip Members")
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)

                Spacer()

                Text("\(viewModel.members.count) people")
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }

            if viewModel.members.isEmpty {
                emptyMembersView
            } else {
                LazyVStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(viewModel.members) { member in
                        MemberRowView(member: member) {
                            Task {
                                await viewModel.removeMember(member)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyMembersView: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No members yet")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            Text("Invite friends to join this trip")
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OuestTheme.Spacing.xl)
    }

    private var debtsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Who Owes What")
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)

            ForEach(viewModel.debts) { debt in
                DebtRowView(debt: debt)
            }
        }
    }
}

// MARK: - Member Row View

struct MemberRowView: View {
    let member: TripMember
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            OuestAvatar(member.profile, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.profile?.displayNameOrEmail ?? "Unknown")
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.text)

                Text(member.role.displayName)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(member.role == .owner ? OuestTheme.Colors.primary : OuestTheme.Colors.textSecondary)
            }

            Spacer()

            if member.role == .owner {
                Image(systemName: "crown.fill")
                    .foregroundColor(OuestTheme.Colors.warning)
            }
        }
        .padding(OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
        .contextMenu {
            if member.role != .owner {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove", systemImage: "person.badge.minus")
                }
            }
        }
    }
}

// MARK: - Debt Row View

struct DebtRowView: View {
    let debt: Debt

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            OuestAvatar(debt.fromProfile, size: .small)

            Image(systemName: "arrow.right")
                .font(.system(size: 12))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            OuestAvatar(debt.toProfile, size: .small)

            Spacer()

            Text(CurrencyFormatter.format(amount: debt.amount, currency: debt.currency))
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.error)
        }
        .padding(OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
    }
}

// MARK: - Edit Trip Sheet

struct EditTripSheet: View {
    @ObservedObject var viewModel: TripDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var destination: String
    @State private var description: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var budget: Decimal?
    @State private var isPublic: Bool
    @State private var isSaving = false

    init(viewModel: TripDetailViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.trip.name)
        _destination = State(initialValue: viewModel.trip.destination)
        _description = State(initialValue: viewModel.trip.description ?? "")
        _startDate = State(initialValue: viewModel.trip.startDate ?? Date())
        _endDate = State(initialValue: viewModel.trip.endDate ?? Date())
        _budget = State(initialValue: viewModel.trip.budget)
        _isPublic = State(initialValue: viewModel.trip.isPublic)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip Name", text: $name)
                    TextField("Destination", text: $destination)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                Section("Budget") {
                    HStack {
                        TextField("Budget", value: $budget, format: .number)
                            .keyboardType(.decimalPad)
                        Text(viewModel.trip.currency)
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                    }
                }

                Section {
                    Toggle("Share with community", isOn: $isPublic)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveTrip() }
                    }
                    .disabled(name.isEmpty || destination.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveTrip() async {
        isSaving = true

        let request = UpdateTripRequest(
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            budget: budget,
            currency: nil,
            isPublic: isPublic,
            votingEnabled: nil,
            coverImage: nil,
            description: description.isEmpty ? nil : description,
            status: nil
        )

        await viewModel.updateTrip(request)
        dismiss()
    }
}

// MARK: - Invite Member Sheet

struct InviteMemberSheet: View {
    @ObservedObject var viewModel: TripDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var isInviting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite by Email") {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Text("The person will receive an invitation to join this trip.")
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        // TODO: Implement invite
                        dismiss()
                    }
                    .disabled(email.isEmpty || isInviting)
                }
            }
        }
    }
}

// MARK: - Trip Status Extension

extension TripStatus {
    var icon: String {
        switch self {
        case .planning: return "pencil.circle"
        case .upcoming: return "calendar.badge.clock"
        case .active: return "airplane"
        case .completed: return "checkmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .planning: return OuestTheme.Colors.Brand.blue
        case .upcoming: return OuestTheme.Colors.Brand.coral
        case .active: return OuestTheme.Colors.success
        case .completed: return OuestTheme.Colors.textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TripDetailView(
            trip: DemoModeManager.demoTrips[0],
            repositories: RepositoryProvider(isDemoMode: true)
        )
        .environmentObject(AppState(isDemoMode: true))
    }
}
