import SwiftUI

/// A one-shot toast that surfaces the outcome of an action (`saved`,
/// `couldn't send`, etc.). Sits on `Layout.tabBarInset` so it clears the
/// floating tab bar; the two ad-hoc capsules in ExpensesView and
/// ExploreView both sat at `Spacing.xxxl` (32pt) and landed *under* the
/// bar. Replacing them with `.ouestToast(_:)` fixes that and gets the
/// design brief's opaque 800-step fills instead of a translucent tint.
///
/// Usage:
///
///     .ouestToast($vm.toast)
///
/// The binding auto-clears itself after ~2.5s so callers only have to
/// set it; failure toasts with a retry stay put until the user acts on
/// them.

struct OuestToast: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case success
        case failure(retry: Retry? = nil)
    }

    struct Retry: Equatable, Sendable {
        /// Label shown as tappable red-300 text on the failure fill.
        let title: String
        /// Trigger identity — Equatable-only so the whole struct stays
        /// Equatable. The actual closure is held on the modifier via
        /// its `onRetry` callback (see below).
        let id: UUID
    }

    let text: String
    let kind: Kind

    static func success(_ text: String) -> OuestToast {
        OuestToast(text: text, kind: .success)
    }

    static func failure(_ text: String, retry: Retry? = nil) -> OuestToast {
        OuestToast(text: text, kind: .failure(retry: retry))
    }
}

extension View {
    /// Present a toast tied to a binding on the view model.
    ///
    /// - Parameters:
    ///   - toast: Set to a value to show, `nil` to dismiss.
    ///   - onRetry: Fires when the user taps the retry pill on a failure
    ///     toast. Match on `toast.kind` to know which retry ran.
    func ouestToast(
        _ toast: Binding<OuestToast?>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(OuestToastModifier(toast: toast, onRetry: onRetry))
    }
}

// MARK: - Modifier

private struct OuestToastModifier: ViewModifier {
    @Binding var toast: OuestToast?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let value = toast {
                    ToastView(toast: value, onRetry: onRetry)
                        .padding(.horizontal, OuestTheme.Layout.pageGutter)
                        .padding(.bottom, OuestTheme.Layout.tabBarInset)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: value) { await autodismiss(for: value) }
                }
            }
            .animation(OuestTheme.Anim.smooth, value: toast)
    }

    /// Success toasts self-dismiss after ~2.5s. Failure toasts that offer
    /// a retry stick around — the user has to act on them. Plain failure
    /// toasts (no retry) auto-dismiss like success.
    private func autodismiss(for value: OuestToast) async {
        switch value.kind {
        case .success, .failure(retry: nil):
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if toast == value { toast = nil }
        case .failure(retry: _):
            break
        }
    }
}

// MARK: - Presentation

private struct ToastView: View {
    let toast: OuestToast
    let onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: symbol)
                .font(OuestTheme.Icon.inline.weight(.semibold))
                .foregroundStyle(.white)

            Text(toast.text)
                .font(OuestTheme.Typography.body)
                .foregroundStyle(.white)
                .lineLimit(2)

            if case let .failure(retry?) = toast.kind, let onRetry {
                Spacer(minLength: OuestTheme.Spacing.sm)
                Button(retry.title, action: onRetry)
                    .font(OuestTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(Color("ToastFailureRetry"))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.lg)
        .padding(.vertical, OuestTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .ouestElevation(.lg, cornerRadius: OuestTheme.Radius.md)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch toast.kind {
        case .success:  return "checkmark.circle.fill"
        case .failure:  return "exclamationmark.triangle.fill"
        }
    }

    private var background: Color {
        switch toast.kind {
        case .success: return Color("ToastSuccessFill")
        case .failure: return Color("ToastFailureFill")
        }
    }
}

// MARK: - Previews

private struct _ToastPreviewHost: View {
    @State private var toast: OuestToast?

    var body: some View {
        ZStack {
            OuestTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: OuestTheme.Spacing.md) {
                Button("Show success") {
                    toast = .success("Trip settings saved.")
                }
                Button("Show failure with retry") {
                    toast = .failure("Couldn't sync expenses.", retry: .init(title: "Retry", id: UUID()))
                }
                Button("Show plain failure") {
                    toast = .failure("Removed from feed.")
                }
            }
        }
        .ouestToast($toast) {
            toast = .success("Retried.")
        }
    }
}

#Preview("Toast host") { _ToastPreviewHost() }
#Preview("Toast host — Dark") {
    _ToastPreviewHost().preferredColorScheme(.dark)
}
