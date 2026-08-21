import StoreKit
import SwiftUI

struct ToDoPlusView: View {
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @EnvironmentObject private var authStore: SupabaseAuthStore
    @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
    @Environment(\.settingsDetailPresentation) private var settingsDetailPresentation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRedeemingOfferCode = false
    @State private var selectedProductForDetails: ToDoProductCatalog.ProductID?
    @State private var isMembershipIconGlowing = false

    var body: some View {
        Group {
            if settingsDetailPresentation == .sidePanel {
                SettingsSubmenuContainer(title: "toDō+") {
                    content
                }
            } else {
                ScrollView {
                    content
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .settingsNativeNavigationTitle("toDō+", colorScheme: colorScheme, background: AppColor.main)
            }
        }
        .background(AppColor.surface)
        .modifier(ToDoOfferCodeRedemptionModifier(isPresented: $isRedeemingOfferCode) {
            Task { await purchaseManager.refreshAfterOfferCodeRedemption() }
        })
        .sheet(item: $selectedProductForDetails) { productID in
            ToDoSubscriptionDetailsSheet(productID: productID)
                .environmentObject(purchaseManager)
        }
        .task {
            await purchaseManager.start(account: authStore.commerceAccount)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let bannerText = connectivityMonitor.bannerText {
                messageView(bannerText, systemName: "wifi.slash", color: AppColor.destructive)
            }

            membershipSection
            if purchaseManager.displayedShouldShowPlusPurchaseOptions {
                plusSection
            }
            appreciationSection
            offerCodeButton
            restoreButton
            manageSubscriptionsButton

            if let statusMessage = purchaseManager.statusMessage {
                messageView(statusMessage, systemName: "checkmark.circle.fill", color: AppColor.secondary)
            }

            if let errorMessage = purchaseManager.errorMessage {
                messageView(errorMessage, systemName: "exclamationmark.triangle.fill", color: AppColor.destructive)
            }

        }
    }

    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            membershipIdentityBlock

            if !authStore.isAuthenticated {
                Text("Sign in to connect your membership and recognition to your toDō account.")
                    .font(.appBody(13, relativeTo: .footnote))
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if purchaseManager.hasWebReadOnlyAccess {
                Label("Some membership access is currently limited.", systemImage: "eye.fill")
                    .font(.appBodyStrong(13, relativeTo: .footnote))
                    .foregroundStyle(AppColor.main)
            }
        }
    }

    private var hasRecognizedMembership: Bool {
        purchaseManager.displayedHasPlus || purchaseManager.displayedIsFoundingSupporter || purchaseManager.displayedIsPioneer
    }

    private var membershipIdentityBlock: some View {
        let isPioneer = purchaseManager.displayedIsPioneer
        let isFoundingSupporter = purchaseManager.displayedIsFoundingSupporter
        let isRecognized = isPioneer || isFoundingSupporter
        let foreground = isRecognized ? AppColor.white : AppColor.textPrimary
        let titleColor = isPioneer ? AppColor.white : isFoundingSupporter ? AppColor.secondary : AppColor.textPrimary
        let iconColor = isPioneer ? AppColor.white : isFoundingSupporter ? AppColor.tertiary : foreground

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isPioneer ? "sparkles" : isFoundingSupporter ? "heart.fill" : purchaseManager.displayedHasPlus ? "checkmark.seal.fill" : "person.crop.circle")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(isPioneer ? AppColor.white : iconColor)
                    .frame(width: 28, height: 28)
                    .shadow(
                        color: isPioneer ? AppColor.secondary.opacity(isMembershipIconGlowing ? 1.0 : 0.62) : .clear,
                        radius: isPioneer ? (isMembershipIconGlowing ? 14 : 6) : 0
                    )
                    .onAppear {
                        guard isPioneer, !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                            isMembershipIconGlowing = true
                        }
                    }
                    .onChange(of: reduceMotion) { _, isReduced in
                        if isReduced {
                            isMembershipIconGlowing = false
                        } else if isPioneer {
                            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                                isMembershipIconGlowing = true
                            }
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isPioneer ? "toDō Pioneer" : isFoundingSupporter ? "Founding Supporter" : purchaseManager.displayedHasPlus ? "toDō+" : "toDō")
                        .font(.appDisplay(isRecognized ? 29 : 25, relativeTo: .title2))
                        .tracking(0.5)
                        .foregroundStyle(titleColor)

                    if isPioneer && isFoundingSupporter {
                        Text("Founding Supporter")
                            .font(.appDisplay(18, relativeTo: .headline))
                            .tracking(0.25)
                            .foregroundStyle(foreground)
                    }
                }

                Spacer(minLength: 8)

                if purchaseManager.isLoading || purchaseManager.isLoadingAccountEntitlements {
                    ProgressView()
                        .tint(isRecognized ? AppColor.secondary : foreground)
                }
            }

            if isFoundingSupporter && !isPioneer {
                Text("Founding Supporter")
                    .font(.appBodyStrong(15, relativeTo: .subheadline))
                    .foregroundStyle(foreground)
            } else {
                Text(purchaseManager.displayedMembershipLabel)
                    .font(hasRecognizedMembership ? .appBodyStrong(14, relativeTo: .subheadline) : .appBody(14, relativeTo: .subheadline))
                    .foregroundStyle(foreground)
            }

            if isPioneer {
                Text("Every feature, free and paid, now and ahead, is included.")
                    .font(.appBodyStrong(14, relativeTo: .subheadline))
                    .foregroundStyle(foreground)
            } else if isFoundingSupporter {
                Text("A lasting thank-you for backing toDō early.")
                    .font(.appBodyStrong(14, relativeTo: .subheadline))
                    .foregroundStyle(foreground)
            }

            if !isRecognized && !purchaseManager.displayedHasPlus {
                Text("Choose the membership that fits how you work.")
                    .font(.appBody(14, relativeTo: .subheadline))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                if isRecognized {
                    ToDoBrandRecognitionBackground()
                } else {
                    AppColor.surfaceMuted
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay {
            if isRecognized {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppColor.secondary.opacity(0.35), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var plusSection: some View {
        section(title: "toDō+") {
            VStack(alignment: .leading, spacing: 8) {
                benefitRow("Send unlimited personal Collab invitations", systemName: "paperplane.fill")
                benefitRow("Receive new toDō+ features as they are released", systemName: "sparkles")
                benefitRow("Share eligible purchases with your Apple family", systemName: "figure.2.and.child.holdinghands")
            }

            Text("Monthly, Annual, and Lifetime unlock the same toDō+ membership. Choose how you prefer to pay.")
                .font(.appBody(13, relativeTo: .footnote))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            productButton(
                id: .plusMonthly,
                title: "Monthly",
                detail: plusProductDetail(.plusMonthly),
                presentsDetails: true
            )
            productButton(
                id: .plusYearly,
                title: "Annual",
                detail: plusProductDetail(.plusYearly),
                presentsDetails: true
            )
            productButton(
                id: .plusLifetime,
                title: "Lifetime",
                detail: "One payment. Permanent access to toDō+.",
                presentsDetails: true
            )

            Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Your Apple Account is charged at confirmation and manages renewal.")
                .font(.appBody(12, relativeTo: .caption))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var offerCodeButton: some View {
        Button {
            isRedeemingOfferCode = true
        } label: {
            actionRow(title: "Redeem an Offer Code", systemName: "ticket.fill")
        }
        .buttonStyle(.plain)
        .disabled(!connectivityMonitor.isAvailable)
    }

    private var appreciationSection: some View {
        section(title: "Keep toDō moving") {
            Text("Optional one-time thanks. These purchases do not unlock features.")
                .font(.appBody(14, relativeTo: .subheadline))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            productButton(id: .appreciationCoffee, title: "Coffee for toDō", detail: "Thanks. Here's a coffee.")
            productButton(id: .appreciationLunch, title: "Lunch for toDō", detail: "I've been getting real value from toDō.")
            productButton(id: .appreciationPatron, title: "Patron of Dōing", detail: "I believe in where this project is going.")

            if purchaseManager.displayedShouldShowFoundingSupporterPurchase,
               purchaseManager.products[ToDoProductCatalog.ProductID.appreciationFounding.rawValue] != nil
                || !purchaseManager.missingProductIDs.contains(ToDoProductCatalog.ProductID.appreciationFounding.rawValue) {
                productButton(
                    id: .appreciationFounding,
                    title: "Founding Supporter",
                    detail: purchaseManager.isFoundingSupporter
                        ? "Permanent recognition"
                        : "One-time recognition available for 14 days after launch"
                )
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await purchaseManager.restorePurchases() }
        } label: {
            actionRow(title: "Restore Purchases", systemName: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .disabled(purchaseManager.isLoading || purchaseManager.activePurchaseProductID != nil || !connectivityMonitor.isAvailable)
    }

    private var manageSubscriptionsButton: some View {
        externalLinkRow(
            title: "Manage Subscriptions",
            systemName: "person.crop.circle",
            destination: URL(string: "https://apps.apple.com/account/subscriptions")!
        )
        .disabled(!connectivityMonitor.isAvailable)
    }

    private func benefitRow(_ title: LocalizedStringKey, systemName: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColor.actionPrimary)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(.appBody(14, relativeTo: .subheadline))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func plusProductDetail(_ productID: ToDoProductCatalog.ProductID) -> LocalizedStringKey {
        switch productID {
        case .plusMonthly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusMonthly)
                ? "First week free for new subscribers. Renews monthly."
                : "Renews monthly."
        case .plusYearly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusYearly)
                ? "First two weeks free for new subscribers. Renews annually."
                : "Renews annually."
        case .plusLifetime:
            return "One payment. Permanent access to toDō+."
        default:
            return ""
        }
    }

    private func actionRow(title: LocalizedStringKey, systemName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColor.actionPrimary)
                .frame(width: 22, height: 22)

            Text(title)
                .font(.appBodyStrong(16, relativeTo: .body))
                .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 18))
        .contentShape(.rect(cornerRadius: 18))
    }

    private func externalLinkRow(
        title: LocalizedStringKey,
        systemName: String,
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColor.actionPrimary)
                    .frame(width: 22, height: 22)

                Text(title)
                    .font(.appBodyStrong(16, relativeTo: .body))
                    .foregroundStyle(AppColor.textPrimary)

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppColor.actionPrimary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 18))
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func productButton(
        id: ToDoProductCatalog.ProductID,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        presentsDetails: Bool = false
    ) -> some View {
        let product = purchaseManager.products[id.rawValue]
        let isOwned = purchaseManager.activeProductIDs.contains(id.rawValue)
        let isPurchasing = purchaseManager.activePurchaseProductID == id.rawValue

        return Button {
            Task {
                if product == nil {
                    await purchaseManager.loadProducts()
                }
                guard purchaseManager.products[id.rawValue] != nil else { return }
                if presentsDetails {
                    selectedProductForDetails = id
                } else {
                    await purchaseManager.purchase(productID: id.rawValue)
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.appBodyStrong(16, relativeTo: .body))
                        .foregroundStyle(AppColor.textPrimary)

                    Text(detail)
                        .font(.appBody(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if isPurchasing {
                    ProgressView()
                        .tint(AppColor.secondary)
                } else if isOwned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.secondary)
                } else {
                    Text(product?.displayPrice ?? String(localized: "Retry"))
                        .font(.appBodyStrong(16, relativeTo: .body))
                        .foregroundStyle(AppColor.actionPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(isOwned || purchaseManager.isLoading || purchaseManager.activePurchaseProductID != nil || !connectivityMonitor.isAvailable)
        .accessibilityHint(isOwned ? Text("Already purchased") : Text(presentsDetails ? "Double-tap to review membership details" : "Double-tap to purchase"))
    }

    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.appDisplay(22, relativeTo: .title3))
                .foregroundStyle(AppColor.secondary)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
        }
    }

    private func messageView(_ message: String, systemName: String, color: Color) -> some View {
        Label(message, systemImage: systemName)
            .font(.appBodyStrong(13, relativeTo: .footnote))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(color.opacity(0.08), in: .rect(cornerRadius: 18))
    }
}

private struct ToDoSubscriptionDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
    let productID: ToDoProductCatalog.ProductID

    private var product: Product? {
        purchaseManager.products[productID.rawValue]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(product?.displayName ?? productID.rawValue)
                            .font(.appViewTitle(30, relativeTo: .largeTitle))
                            .foregroundStyle(AppColor.textPrimary)

                        if let product {
                            Text(product.displayPrice)
                                .font(.appBodyStrong(22, relativeTo: .title2))
                                .foregroundStyle(AppColor.actionPrimary)
                        }
                    }

                    Text(plusDetail(for: productID))
                        .font(.appBodyStrong(15, relativeTo: .subheadline))
                        .foregroundStyle(AppColor.textPrimary)

                    VStack(alignment: .leading, spacing: 10) {
                        benefitRow("Send unlimited personal Collab invitations", systemName: "paperplane.fill")
                        benefitRow("Receive new toDō+ features as they are released", systemName: "sparkles")
                        benefitRow("Share eligible purchases with your Apple family", systemName: "figure.2.and.child.holdinghands")
                    }

                    Button {
                        Task {
                            await purchaseManager.purchase(productID: productID.rawValue)
                            dismiss()
                        }
                    } label: {
                        Text("Continue")
                            .font(.appButton(17, relativeTo: .body))
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(AppSemanticTextButtonStyle(intent: .proceed))
                    .disabled(product == nil || purchaseManager.isLoading || purchaseManager.activePurchaseProductID != nil || !connectivityMonitor.isAvailable)
                }
                .padding(22)
            }
            .background(AppColor.surface)
            .navigationTitle("Membership")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func plusDetail(for productID: ToDoProductCatalog.ProductID) -> LocalizedStringKey {
        switch productID {
        case .plusMonthly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusMonthly)
                ? "First week free for new subscribers. Renews monthly."
                : "Renews monthly."
        case .plusYearly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusYearly)
                ? "First two weeks free for new subscribers. Renews annually."
                : "Renews annually."
        case .plusLifetime:
            return "One payment. Permanent access to toDō+."
        default:
            return ""
        }
    }

    private func benefitRow(_ title: LocalizedStringKey, systemName: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColor.actionPrimary)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(.appBodyStrong(14, relativeTo: .body))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
