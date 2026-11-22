import SwiftUI

extension View {
    /// Present a report dialog for the bound target. Set the binding to show;
    /// the dialog clears it on dismiss. Submits via `ModerationService` and
    /// confirms with a toast, so call sites need no extra state.
    func reportDialog(target: Binding<ReportTarget?>) -> some View {
        modifier(ReportDialogModifier(target: target))
    }
}

private struct ReportDialogModifier: ViewModifier {
    @Binding var target: ReportTarget?
    @State private var toast: OuestToast?

    private var isPresented: Binding<Bool> {
        Binding(
            get: { target != nil },
            set: { if !$0 { target = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Report \(target?.displayName ?? "")",
                isPresented: isPresented,
                titleVisibility: .visible,
                presenting: target
            ) { target in
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.label) {
                        submit(target, reason: reason)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("Reports are anonymous and reviewed by the Ouest team.")
            }
            .ouestToast($toast)
    }

    private func submit(_ target: ReportTarget, reason: ReportReason) {
        Task {
            do {
                let reporterId = try await SupabaseManager.client.auth.session.user.id
                try await ModerationService.report(target, reason: reason, reporterId: reporterId)
                HapticFeedback.success()
                toast = .success("Thanks — we'll take a look.")
            } catch {
                HapticFeedback.error()
                toast = .failure("Couldn't send report. Try again.")
                #if DEBUG
                print("[Report] failed: \(error)")
                #endif
            }
        }
    }
}
