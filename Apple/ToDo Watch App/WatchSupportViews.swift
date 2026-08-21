import AuthenticationServices
import Combine
import CoreLocation
import SwiftUI
import WatchKit

enum WatchLocalization {
   static var displayLocale: Locale {
      let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
      if identifier.hasPrefix("ar") {
         return Locale(identifier: "ar_SA@numbers=arab")
      }
      if identifier.hasPrefix("ur") {
         return Locale(identifier: "ur_PK@numbers=arabext")
      }
      if identifier.hasPrefix("hi") {
         return Locale(identifier: "hi_IN@numbers=deva")
      }
      if identifier.hasPrefix("th") {
         return Locale(identifier: "th_TH@numbers=thai")
      }
      return Locale(identifier: identifier)
   }

   static func dateTimeString(_ date: Date) -> String {
      formatted(date, dateStyle: .medium, timeStyle: .short)
   }

   static func shortDateTimeString(_ date: Date) -> String {
      dateTimeString(date)
   }

   static func dateString(_ date: Date) -> String {
      formatted(date, dateStyle: .medium, timeStyle: .none)
   }

   static func monthDayString(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = displayLocale
      formatter.calendar = displayCalendar
      formatter.setLocalizedDateFormatFromTemplate("MMMd")
      return formatter.string(from: date)
   }

   static func timeString(_ date: Date) -> String {
      formatted(date, dateStyle: .none, timeStyle: .short)
   }

   static func numberString(_ number: Int) -> String {
      let formatter = NumberFormatter()
      formatter.locale = displayLocale
      formatter.numberStyle = .none
      return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
   }

   static func localizedCount(_ count: Int, singularKey: String, pluralKey: String) -> String {
      String(
         format: String(localized: String.LocalizationValue(count == 1 ? singularKey : pluralKey)),
         numberString(count)
      )
   }

   private static var displayCalendar: Calendar {
      let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
      var calendar = Calendar(identifier: identifier.hasPrefix("ar") ? .islamicUmmAlQura : .gregorian)
      calendar.locale = displayLocale
      calendar.timeZone = .current
      return calendar
   }

   private static func formatted(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
      let formatter = DateFormatter()
      formatter.locale = displayLocale
      formatter.calendar = displayCalendar
      formatter.dateStyle = dateStyle
      formatter.timeStyle = timeStyle
      return formatter.string(from: date)
   }
}

private enum WatchRecurrenceUnitOption: String, CaseIterable, Identifiable {
   case days
   case weeks
   case months
   case years

   var id: String { rawValue }

   var title: String {
      switch self {
      case .days: return String(localized: "Days")
      case .weeks: return String(localized: "Weeks")
      case .months: return String(localized: "Months")
      case .years: return String(localized: "Years")
      }
   }
}

private enum WatchRecurrenceModeOption: String, CaseIterable, Identifiable {
   case finite
   case continuous

   var id: String { rawValue }

   var title: String {
      switch self {
      case .finite: return String(localized: "Limited")
      case .continuous: return String(localized: "Ongoing")
      }
   }
}

private enum WatchLocationTriggerOption: String, CaseIterable, Identifiable {
   case arriving
   case leaving

   var id: String { rawValue }

   var title: String {
      switch self {
      case .arriving: return String(localized: "Arriving")
      case .leaving: return String(localized: "Leaving")
      }
   }
}

@MainActor
private final class WatchLocationCaptureService: NSObject, ObservableObject, CLLocationManagerDelegate {
   @Published var isLocating = false
   @Published var statusText: String?

   private let manager = CLLocationManager()
   private var continuation: CheckedContinuation<CLLocation?, Never>?

   override init() {
      super.init()
      manager.delegate = self
      manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
   }

   func requestLocation() async -> CLLocation? {
      guard !isLocating else { return nil }

      let status = manager.authorizationStatus
      if status == .notDetermined {
         manager.requestWhenInUseAuthorization()
         statusText = String(localized: "Approve location access, then tap again.")
         return nil
      }

      guard status == .authorizedWhenInUse || status == .authorizedAlways else {
         statusText = String(localized: "Location access is off.")
         return nil
      }

      isLocating = true
      statusText = String(localized: "Finding Location")
      return await withCheckedContinuation { continuation in
         self.continuation = continuation
         manager.requestLocation()
      }
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      Task { @MainActor in
         isLocating = false
         statusText = String(localized: "Location captured")
         continuation?.resume(returning: locations.last)
         continuation = nil
      }
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
      Task { @MainActor in
         isLocating = false
         statusText = String(localized: "Location access is unavailable.")
         continuation?.resume(returning: nil)
         continuation = nil
      }
   }
}

struct WatchAccountView: View {
   @Environment(\.dismiss) private var dismiss
   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @ObservedObject var authStore: WatchAuthStore
   @ObservedObject var store: WatchToDoStore
   let openDoneToDos: () -> Void
   @State private var currentAppleNonce = ""
   @State private var expectedUsername = ""
   @State private var submittedUsername: String?
#if DEBUG
   @State private var simulatorEmail = ""
   @State private var simulatorPassword = ""
#endif

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Settings",
               systemImage: "gearshape.fill",
               accent: WatchAppColor.main
            )

            syncStatusCard
            accountCard
            migrationCard
            settingsCard
            doneToDosCard
            watchBrandFooter
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
	      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
      .accessibilityIdentifier("watch.todo.create")
	   }

   private var accountCard: some View {
      WatchCard(spacing: 8) {
         WatchMetadataRow(
            systemImage: authStore.authState.isAuthenticated ? "person.crop.circle.badge.checkmark" : "icloud.slash",
            title: "Account",
            value: authStore.authState.detail,
            accent: authStore.authState.isAuthenticated ? WatchAppColor.actionSuccess : WatchAppColor.main
         )

         if let errorMessage = authStore.errorMessage {
            Text(errorMessage)
               .font(.watchBody(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.destructive)
         }

         if authStore.isSigningIn {
            HStack(spacing: 8) {
               ProgressView()
                  .controlSize(.mini)
               Text("Signing in")
                  .font(.watchBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(WatchAppColor.textSecondary)
            }
            .padding(.top, 2)
         } else if authStore.authState.isAuthenticated {
            Button(role: .destructive) {
               authStore.signOut()
               expectedUsername = ""
               submittedUsername = nil
            } label: {
               Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.destructive))

         } else {
            HStack(spacing: 7) {
               TextField("Username", text: $expectedUsername)
                  .textInputAutocapitalization(.never)
                  .autocorrectionDisabled()
                  .submitLabel(.continue)
                  .onSubmit(showProviderChoices)
                  .font(.watchBodyStrong(11, relativeTo: .caption))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .padding(.vertical, 7)
                  .padding(.horizontal, 9)
                  .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

               Button(action: showProviderChoices) {
                  Image(systemName: "arrow.right")
                     .font(.watchSymbol(13, weight: .bold))
                     .frame(width: 34, height: 34)
               }
               .buttonStyle(WatchCircleButtonStyle())
               .disabled(normalizedUsername == nil || authStore.isSigningIn)
               .opacity(normalizedUsername == nil ? 0.42 : 1)
               .accessibilityLabel("Continue")
            }

            if let submittedUsername {
               SignInWithAppleButton(.signIn) { request in
                  guard let nonce = WatchAuthNonceGenerator.random() else {
                     currentAppleNonce = ""
                     return
                  }
                  currentAppleNonce = nonce
                  request.requestedScopes = [.email]
                  request.nonce = WatchAuthNonceGenerator.sha256(nonce)
               } onCompletion: { result in
                  handleAppleSignIn(result, expectedUsername: submittedUsername)
               }
               .signInWithAppleButtonStyle(.white)
               .frame(height: 44)
               .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
               .padding(.top, 2)
               .transition(providerChoicesTransition)
            }

            Button(action: skipAuthentication) {
               VStack(alignment: .leading, spacing: 3) {
                  HStack(spacing: 7) {
                     Image(systemName: "externaldrive")
                     Text("You can stay on this device.")
                     Spacer(minLength: 4)
                     Image(systemName: "arrow.right.circle.fill")
                        .accessibilityHidden(true)
                  }

                  Text("Local toDōs stay on this Watch. Account toDōs stay private until you sign in again.")
                     .font(.watchBody(9, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.textSecondary)
                     .fixedSize(horizontal: false, vertical: true)
               }
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))

#if DEBUG
            simulatorSignInControls
#endif

            if authStore.authState.source == .iPhone {
               Text("This Watch is using your iPhone account. Sign in here only if you want the Watch to hold its own account session.")
                  .font(.watchBody(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }
      }
      .onChange(of: expectedUsername) { _, _ in
         collapseProviderChoicesWhenUsernameChanges()
      }
   }

   private var normalizedUsername: String? {
      WatchUsernamePolicy.normalized(expectedUsername)
   }

   private var providerChoicesTransition: AnyTransition {
      reduceMotion
         ? .opacity
         : .move(edge: .trailing).combined(with: .opacity)
   }

   private func showProviderChoices() {
      guard let normalizedUsername else { return }
      withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
         submittedUsername = normalizedUsername
      }
   }

   private func collapseProviderChoicesWhenUsernameChanges() {
      guard let submittedUsername,
            submittedUsername != normalizedUsername else { return }
      withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
         self.submittedUsername = nil
      }
   }

   private func skipAuthentication() {
      authStore.continueWithoutSigningIn()
      expectedUsername = ""
      submittedUsername = nil
      dismiss()
   }

#if DEBUG
   private var simulatorSignInControls: some View {
      VStack(alignment: .leading, spacing: 7) {
         Text("Simulator sign-in")
            .font(.watchDisplay(16, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.main)

         TextField("test account email", text: $simulatorEmail)
            .textContentType(.emailAddress)
            .font(.watchBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

         SecureField("password", text: $simulatorPassword)
            .textContentType(.password)
            .font(.watchBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

         Button {
            Task {
               await authStore.signInWithSimulatorAccount(email: simulatorEmail, password: simulatorPassword)
            }
         } label: {
            Label("Use Test Account", systemImage: "ladybug.fill")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))

         Text("Debug simulator only. This does not ship in Release or device builds.")
            .font(.watchBody(9, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, 4)
   }
#endif

   private func handleAppleSignIn(
      _ result: Result<ASAuthorization, Error>,
      expectedUsername: String
   ) {
      switch result {
      case .success(let authorization):
         guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let identityToken = credential.identityToken,
               let idToken = String(data: identityToken, encoding: .utf8),
               !currentAppleNonce.isEmpty
         else {
            return
         }

         let rawNonce = currentAppleNonce
         currentAppleNonce = ""
         Task {
            await authStore.signInWithApple(
               idToken: idToken,
               rawNonce: rawNonce,
               expectedUsername: expectedUsername
            )
         }
      case .failure:
         currentAppleNonce = ""
      }
   }

   private var syncStatusCard: some View {
      WatchCard(spacing: 8) {
         WatchMetadataRow(
            systemImage: "arrow.clockwise.icloud",
            title: "Updated",
            value: updatedText,
            accent: statusColor
         )

         if store.queuedActionCount > 0 {
            WatchMetadataRow(
               systemImage: "tray.and.arrow.up.fill",
               title: "Queued",
               value: String(format: String(localized: "%@ pending"), WatchLocalization.numberString(store.queuedActionCount)),
               accent: WatchAppColor.main
            )
         }

         Button {
            store.requestRefresh()
         } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))
      }
   }

   @ViewBuilder
   private var migrationCard: some View {
      if authStore.standaloneSession != nil, store.hasQueuedLocalActions {
         WatchActionGroup(title: "Watch Merge", systemImage: "arrow.triangle.merge", accent: WatchAppColor.main) {
            WatchMetadataRow(
               systemImage: "applewatch",
               title: "Local toDōs",
               value: String(format: String(localized: "%@ waiting"), WatchLocalization.numberString(store.queuedCreateActions.count)),
               accent: WatchAppColor.main
            )

            NavigationLink(value: WatchRoute.migrationReview) {
               Label("Review Duplicates", systemImage: "rectangle.stack.badge.person.crop")
                  .font(.watchButton(18, relativeTo: .headline))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))

            Button {
               Task {
                  _ = await store.mergeQueuedLocalActionsDirectly()
               }
            } label: {
               Label("Merge with Account", systemImage: "arrow.triangle.merge")
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionSuccess))

            Button {
               store.keepQueuedLocalActionsSeparateForNow()
            } label: {
               Label("Keep Separate", systemImage: "pause.circle")
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.main))
         }
      }
   }

   private var settingsCard: some View {
      VStack(alignment: .leading, spacing: 10) {
         WatchActionGroup(title: "Notifications", systemImage: "bell.badge", accent: WatchAppColor.secondary) {
            WatchMetadataRow(
               systemImage: "bell.badge",
               title: "Alerts",
               value: String(localized: "Uses your iPhone and Watch notification settings"),
               accent: WatchAppColor.secondary
            )

            NavigationLink {
               WatchSnoozeOptionsView()
            } label: {
               Text("Snooze Options")
                  .font(.watchButton(18, relativeTo: .headline))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))
         }

         WatchActionGroup(title: "Behavior", systemImage: "slider.horizontal.3", accent: WatchAppColor.main) {
            WatchMetadataRow(
               systemImage: "checkmark.circle",
               title: "Completion",
               value: String(localized: "Done and delete actions sync with iPhone, iPad, and Mac."),
               accent: WatchAppColor.actionSuccess
            )

            WatchMetadataRow(
               systemImage: "iphone.and.arrow.forward",
               title: "Deep Edits",
               value: String(localized: "Use iPhone for maps, recurrence rules, and full tag editing."),
               accent: WatchAppColor.main
            )
         }

         WatchActionGroup(title: "Watch", systemImage: "applewatch", accent: WatchAppColor.actionPrimary) {
            WatchMetadataRow(
               systemImage: store.canOpenOnPhone ? "iphone.gen3.radiowaves.left.and.right" : "iphone.slash",
               title: "Companion",
               value: store.canOpenOnPhone ? String(localized: "iPhone is reachable") : String(localized: "Works standalone when signed in"),
               accent: store.canOpenOnPhone ? WatchAppColor.actionSuccess : WatchAppColor.textSecondary
            )
         }

         WatchActionGroup(title: "About", systemImage: "info.circle.fill", accent: WatchAppColor.secondary) {
            NavigationLink {
               WatchAboutView()
            } label: {
               HStack {
                  Text("About toDō")
                     .font(.watchButton(18, relativeTo: .headline))
                  Spacer(minLength: 6)
                  Text(verbatim: watchVersionLabel)
                     .font(.watchBodyStrong(11, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.textSecondary)
               }
               .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))
         }
      }
   }

   private var watchVersionLabel: String {
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
   }

   private var legacySettingsCard: some View {
      WatchActionGroup(title: "Notifications", systemImage: "bell.badge", accent: WatchAppColor.secondary) {
         WatchMetadataRow(
            systemImage: "bell.badge",
            title: "Alerts",
            value: String(localized: "Uses your iPhone and Watch notification settings"),
            accent: WatchAppColor.secondary
         )

         NavigationLink {
            WatchSnoozeOptionsView()
         } label: {
            Label("Snooze", systemImage: "zzz")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))
      }
   }

   private struct WatchAboutView: View {
      @State private var isShowingReleaseHistory = false

      var body: some View {
         ScrollView {
            VStack(alignment: .leading, spacing: 0) {
               WatchCard(spacing: 8) {
                  Text("toDō is a productivity system built for the user to help you stay organized without getting in your way. From everyday tasks and shopping lists to bigger plans and everything beyond, it’s designed to work the way you do.")
                     .font(.watchBody(14, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .lineSpacing(4)
                     .fixedSize(horizontal: false, vertical: true)

                  Text("Take a little time to explore. Try different ways of organizing your tasks, make the app your own, and see what works best for you. Visit yourtodo.today to learn more about toDō, and follow my Substack for release notes, engineering talk, and the thinking behind each update.")
                     .font(.watchBody(14, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .lineSpacing(4)
                     .fixedSize(horizontal: false, vertical: true)

                  Text("\(Text("Hi, I’m moin.").fontWeight(.heavy)) I built toDō because I wanted a productivity app that felt simple, thoughtful, and enjoyable to use every day. It’s been a long journey, and I’m still making it better with every release. If you’d like to learn more about my work, you’ll find me at iamshift.dev.")
                     .font(.watchBody(14, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .lineSpacing(4)
                     .fixedSize(horizontal: false, vertical: true)

                  Text("shift beneath the view")
                     .font(.watchBodyStrong(14, relativeTo: .body))
                     .fontWeight(.black)
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .tracking(0.6)
                     .padding(.top, 5)
                     .accessibilityAddTraits(.isHeader)
               }
               .padding(.top, 8)
               .padding(.bottom, 4)

               WatchCard(spacing: 8) {
                  VStack(alignment: .leading, spacing: 5) {
                     HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                           .font(.watchSymbol(14, weight: .bold))
                           .foregroundStyle(WatchAppColor.secondary)
                           .frame(width: 16, height: 16)

                        Text("Release Notes")
                           .font(.watchDisplay(18, relativeTo: .headline))
                           .foregroundStyle(WatchAppColor.textPrimary)
                     }

                     Text("Version \(versionLabel)")
                        .font(.watchBodyStrong(11, relativeTo: .caption))
                        .foregroundStyle(WatchAppColor.secondary)
                  }

                  ForEach(Array(currentReleaseNotes.enumerated()), id: \.offset) { index, note in
                     releasePreviewRow(note, isHighlight: index < 2)
                  }

                  Button {
                     isShowingReleaseHistory = true
                  } label: {
                     HStack(spacing: 5) {
                        Text("All Release History")
                        Image(systemName: "arrow.up.right")
                           .accessibilityHidden(true)
                     }
                     .font(.watchBodyStrong(10, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.actionPrimary)
                     .padding(.horizontal, 8)
                     .padding(.vertical, 8)
                     .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                  }
                  .buttonStyle(.plain)
                  .accessibilityHint("Shows release notes for every version")
               }
               .padding(.bottom, 8)

               Text("Made with Intention")
                  .font(.watchDisplay(18, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.secondary)
                  .padding(.top, 16)
                  .padding(.bottom, 4)

               HStack(spacing: 10) {
                  watchBrandLink(
                     "moin.shift()",
                     destination: "https://iamshift.dev"
                  )
                  watchBrandLink(
                     "toDō today",
                     logoName: "todo-today-logo",
                     destination: "https://yourtodo.today"
                  )
               }
               .frame(maxWidth: 164)
               .frame(maxWidth: .infinity)

               Link(destination: URL(string: "mailto:support@iamshift.dev")!) {
                  HStack(spacing: 5) {
                     Image(systemName: "envelope.fill")
                        .accessibilityHidden(true)
                     Text(verbatim: "support@iamshift.dev")
                        .font(.watchBodyStrong(11, relativeTo: .caption))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .layoutPriority(1)
                     Spacer(minLength: 0)
                  }
                  .frame(maxWidth: .infinity)
               }
               .buttonStyle(WatchFilledButtonStyle(fill: WatchAppColor.white))
               .frame(maxWidth: 164, minHeight: 38)
               .frame(maxWidth: .infinity)

               Text("Legal")
                  .font(.watchDisplay(18, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.secondary)
                  .padding(.top, 16)
                  .padding(.bottom, 4)

               VStack(spacing: 8) {
                  aboutLink("Privacy Policy", destination: "https://yourtodo.today/legal/privacy.html")
                  aboutLink("Terms of Use", destination: "https://yourtodo.today/legal/terms.html")
               }
               .frame(maxWidth: 164)
               .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 12)
         }
         .background(WatchAppColor.surface)
         .tint(WatchAppColor.actionPrimary)
         .navigationTitle("About toDō")
         .navigationBarTitleDisplayMode(.inline)
         .sheet(isPresented: $isShowingReleaseHistory) {
            WatchReleaseHistoryView(currentVersion: versionLabel)
         }
      }

      private func aboutLink(
         _ title: LocalizedStringKey,
         destination: String
      ) -> some View {
         Link(destination: URL(string: destination)!) {
            HStack(spacing: 8) {
               Text(title)
                  .font(.watchBodyStrong(12, relativeTo: .caption))
               Spacer(minLength: 4)
               Image(systemName: "arrow.up.right")
                  .font(.watchSymbol(10, weight: .heavy))
                  .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))
      }

      private var currentReleaseNotes: [LocalizedStringKey] {
         [
            "Added toDō+ membership, Pioneer recognition, account profiles, and expanded personal Collabs.",
            "Improved custom reminders, NanoDos, task completion, and account-safe sync.",
            "Improved task entry, onboarding, and accessibility.",
            "Expanded standalone Apple Watch sync and account-aware behavior.",
            "And much more, shaped around the way you work."
         ]
      }

      private func releasePreviewRow(_ text: LocalizedStringKey, isHighlight: Bool = false) -> some View {
         HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle()
               .fill(WatchAppColor.main)
               .frame(width: 5, height: 5)
               .frame(width: 16, alignment: .center)

            Text(text)
               .font(.watchCode(.caption2))
               .fontWeight(isHighlight ? .bold : .regular)
               .foregroundStyle(WatchAppColor.textPrimary)
               .fixedSize(horizontal: false, vertical: true)
         }
      }

      private func watchBrandLink(
         _ title: LocalizedStringKey,
         logoName: String = "brand-logomark",
         destination: String
      ) -> some View {
         Link(destination: URL(string: destination)!) {
            VStack(spacing: 6) {
               HStack {
                  Spacer()
                  Image(systemName: "arrow.up.right")
                     .font(.watchSymbol(12, weight: .heavy))
                     .foregroundStyle(WatchAppColor.secondary)
               }

               Image(logoName)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 36, height: 36)

               Text(title)
                  .font(.watchBodyStrong(12, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.7)
            }
            .padding(8)
            .frame(width: 76, height: 76)
         }
         .buttonStyle(.plain)
      }

      private var versionLabel: String {
         Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
      }

      private struct WatchReleaseHistoryView: View {
         @Environment(\.dismiss) private var dismiss

         let currentVersion: String

         private var releases: [(version: String, isCurrent: Bool, notes: [LocalizedStringKey])] {
            [
               (currentVersion, true, [
                  "Added toDō+ membership, Pioneer recognition, account profiles, and expanded personal Collabs.",
                  "Improved custom reminders, NanoDos, task completion, and account-safe sync.",
                  "Improved task entry, onboarding, and accessibility.",
                  "Expanded standalone Apple Watch sync and account-aware behavior.",
                  "And much more, shaped around the way you work."
               ]),
               ("3.0.1", false, [
                  "Improved sync reliability across devices.",
                  "Refined notifications, widgets, Live Activities, and localization.",
                  "Fixed stability and presentation issues reported after 3.0."
               ]),
               ("3.0", false, [
                  "Introduced Home, Momentum, and the redesigned toDō workflow.",
                  "Added toDō Sync, Apple Watch, Mac, widgets, and Live Activities.",
                  "Rebuilt the app around a consistent cross-platform design."
               ])
            ]
         }

         var body: some View {
            ScrollView {
               VStack(alignment: .leading, spacing: 12) {
                  HStack(spacing: 8) {
                     Text("Release History")
                        .font(.watchDisplay(23, relativeTo: .title3))
                        .foregroundStyle(WatchAppColor.textPrimary)
                     Spacer(minLength: 4)
                     Button {
                        dismiss()
                     } label: {
                        Image(systemName: "xmark")
                     }
                     .buttonStyle(WatchCompactIconButtonStyle(
                        fill: WatchAppColor.destructive,
                        foreground: WatchAppColor.onAction,
                        size: 32,
                        symbolSize: 15
                     ))
                     .accessibilityLabel("Close")
                  }

                  ForEach(Array(releases.enumerated()), id: \.offset) { _, release in
                     WatchCard(spacing: 8) {
                        HStack(spacing: 7) {
                           Text(verbatim: release.version)
                              .font(.watchDisplay(19, relativeTo: .headline))
                           if release.isCurrent {
                              Text("Latest")
                                 .font(.watchBodyStrong(9, relativeTo: .caption2))
                                 .foregroundStyle(WatchAppColor.onAction)
                                 .padding(.horizontal, 7)
                                 .padding(.vertical, 3)
                                 .background(WatchAppColor.actionPrimary, in: Capsule())
                           }
                        }

                        ForEach(Array(release.notes.enumerated()), id: \.offset) { index, note in
                           HStack(alignment: .firstTextBaseline, spacing: 7) {
                              Circle()
                                 .fill(WatchAppColor.main)
                                 .frame(width: 5, height: 5)
                              Text(note)
                                 .font(.watchCode(.caption2))
                                 .fontWeight(release.isCurrent && index < 2 ? .bold : .regular)
                                 .foregroundStyle(WatchAppColor.textPrimary)
                                 .fixedSize(horizontal: false, vertical: true)
                           }
                        }
                     }
                  }
               }
               .padding(.bottom, 12)
            }
            .background(WatchAppColor.surface)
         }
      }
   }

   private var doneToDosCard: some View {
      WatchActionGroup(title: "Done toDōs", systemImage: "tray.full", accent: WatchAppColor.actionSuccess) {
         Button(action: openDoneToDos) {
            Label(doneToDosLabel, systemImage: "tray.full")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionSuccess))
      }
   }

   private var doneToDosLabel: String {
      let count = store.doneItems.count
      return WatchLocalization.localizedCount(count, singularKey: "%@ done toDō", pluralKey: "%@ done toDōs")
   }

   private var watchBrandFooter: some View {
      VStack(spacing: 10) {
         Text("\(Text("toDō").foregroundStyle(WatchAppColor.main).bold()) \(Text(String(localized: "what matters")))")
            .font(.watchAccent(13, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)
            .multilineTextAlignment(.center)

         Link(destination: URL(string: "https://yourtodo.today")!) {
            Text("yourtodo.today")
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.secondary)
         }
         .buttonStyle(.plain)

         watchBrandWordmark

         Link(destination: URL(string: "https://iamshift.dev")!) {
            Image("brand-logomark")
               .resizable()
               .scaledToFit()
               .frame(width: 42, height: 42)
         }
         .buttonStyle(.plain)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 8)
      .padding(.bottom, 4)
   }

   private var watchBrandWordmark: some View {
      HStack(spacing: 0) {
         Text("mo")
            .font(watchBrandWordmarkFont)
         Text("i").italic()
            .font(watchBrandWordmarkItalicFont)
         Text("n.")
            .font(watchBrandWordmarkFont)
         Text("sh").italic()
            .font(watchBrandWordmarkItalicFont)
         Text("i")
            .font(watchBrandWordmarkFont)
         Text("ft()").italic()
            .font(watchBrandWordmarkItalicFont)
      }
      .foregroundStyle(WatchAppColor.textPrimary)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("moin.shift()")
   }

   private var watchBrandWordmarkFont: Font {
      .custom("Aleo", size: 15, relativeTo: .caption)
         .weight(.medium)
   }

   private var watchBrandWordmarkItalicFont: Font {
      .custom("Aleo", size: 15, relativeTo: .caption)
         .weight(.regular)
         .italic()
   }

   private var updatedText: String {
      if store.queuedActionCount > 0 {
         return String(localized: "Queued")
      }

      if let lastUpdated = store.lastUpdated {
         return WatchLocalization.timeString(lastUpdated)
      }

      return String(localized: String.LocalizationValue(store.statusText))
   }

   private var statusColor: Color {
      switch store.statusText {
      case "Updated", "Saved", "Connected", "Account Ready":
         return WatchAppColor.actionSuccess
      case "Sending", "Syncing":
         return WatchAppColor.main
      case "Queued":
         return WatchAppColor.secondary
      default:
         return WatchAppColor.textSecondary
      }
   }
}

struct WatchQueuedMigrationReviewView: View {
   @ObservedObject var store: WatchToDoStore
   @Environment(\.dismiss) private var dismiss
   @State private var isMerging = false

   private var rows: [WatchDuplicateReviewRow] {
      store.duplicateReviewRows()
   }

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Review",
               systemImage: "rectangle.stack.badge.person.crop",
               accent: WatchAppColor.secondary
            )

            WatchCard(spacing: 9) {
               Text("Check local Watch toDōs before merging them into this account.")
                  .font(.watchBody(12, relativeTo: .caption))
                  .foregroundStyle(WatchAppColor.textSecondaryStrong)
                  .fixedSize(horizontal: false, vertical: true)

               if rows.isEmpty {
                  Text("No local Watch toDōs are waiting.")
                     .font(.watchBodyStrong(12, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textSecondary)
               } else {
                  ForEach(rows) { row in
                     WatchDuplicateReviewItem(row: row)
                  }
               }
            }

            Button {
               Task {
                  isMerging = true
                  defer { isMerging = false }
                  if await store.mergeQueuedLocalActionsDirectly() {
                     dismiss()
                  }
               }
            } label: {
               if isMerging {
                  HStack(spacing: 8) {
                     ProgressView()
                        .controlSize(.mini)
                     Text("Merging")
                  }
               } else {
                  Label("Merge", systemImage: "arrow.triangle.merge")
               }
            }
            .buttonStyle(WatchProminentButtonStyle())
            .disabled(rows.isEmpty || isMerging)

            Text(store.statusText)
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(statusColor(for: store.statusText))
               .frame(maxWidth: .infinity, alignment: .center)
               .multilineTextAlignment(.center)

            Button(role: .destructive) {
               store.discardQueuedLocalActions()
               dismiss()
            } label: {
               Label("Clear Local", systemImage: "trash")
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.destructive))
            .disabled(rows.isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .background(WatchAppColor.surface)
      .toolbarBackground(.hidden, for: .navigationBar)
      .tint(WatchAppColor.actionPrimary)
   }

   private func statusColor(for status: String) -> Color {
      switch status {
      case "Merged":
         return WatchAppColor.actionSuccess
      case "Merging":
         return WatchAppColor.main
      case "No local toDōs", "Sign in first", "Direct sync unavailable":
         return WatchAppColor.destructive
      default:
         return WatchAppColor.textSecondary
      }
   }
}

private struct WatchDuplicateReviewItem: View {
   let row: WatchDuplicateReviewRow

   var body: some View {
      VStack(alignment: .leading, spacing: 5) {
         HStack(spacing: 7) {
            Image(systemName: row.hasDuplicate ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
               .font(.watchSymbol(13, weight: .bold))
               .foregroundStyle(row.hasDuplicate ? WatchAppColor.destructive : WatchAppColor.actionSuccess)

            Text(row.task)
               .font(.watchBodyStrong(13, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.textPrimary)
               .lineLimit(2)
         }

         if let dueDate = row.dueDate {
            Text(WatchLocalization.dateTimeString(dueDate))
               .font(.watchBody(10, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)
         }

         if let duplicateTask = row.duplicateTask {
            Text(String(format: String(localized: "Possible duplicate: %@"), duplicateTask))
               .font(.watchBody(10, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.destructive)
               .fixedSize(horizontal: false, vertical: true)
         }
      }
      .padding(9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
   }
}

struct WatchDoneToDosView: View {
   @ObservedObject var store: WatchToDoStore

   private var doneItems: [WatchToDoItem] {
      store.doneItems
   }

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Done",
               systemImage: "tray.full",
               accent: WatchAppColor.actionSuccess
            )

            if doneItems.isEmpty {
               WatchCard(spacing: 8) {
                  Image(systemName: "tray")
                     .font(.watchDisplay(22, relativeTo: .title3))
                     .foregroundStyle(WatchAppColor.textSecondary)

                  Text("No done toDōs yet.")
                     .font(.watchBodyStrong(13, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)
               }
            } else {
               WatchCard(spacing: 7) {
                  ForEach(doneItems) { item in
                     NavigationLink(value: WatchRoute.toDoDetail(item.id)) {
                        WatchToDoRow(item: item, accent: WatchAppColor.actionSuccess)
                     }
                     .buttonStyle(.plain)
                  }
               }
            }
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("Done")
      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
   }
}

struct WatchSnoozeOptionsView: View {
   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Snooze Options",
               systemImage: "zzz",
               accent: WatchAppColor.secondary
            )

            ForEach(WatchSnoozeUnit.allCases) { unit in
               WatchActionGroup(title: unit.title, systemImage: "clock", accent: WatchAppColor.secondary) {
                  ForEach(Array(unit.values.enumerated()), id: \.offset) { _, value in
                     WatchMetadataRow(
                        systemImage: "timer",
                        title: unit.label(for: value),
                        value: String(localized: "Available from any due toDō"),
                        accent: WatchAppColor.secondary
                     )
                  }
               }
            }
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("Snooze Options")
      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
   }
}

struct ToDoSection: View {
   let title: String
   let items: [WatchToDoItem]
   let accent: Color
   let systemImage: String
   @ObservedObject var store: WatchToDoStore

   var body: some View {
      if !items.isEmpty {
         VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
               Image(systemName: systemImage)
                  .font(.watchBodyStrong(12, relativeTo: .caption2))
                  .foregroundStyle(accent)

               Text(LocalizedStringKey(title))
                  .font(.watchDisplay(18, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.textPrimary)

               Text(WatchLocalization.numberString(items.count))
                  .font(.watchBodyStrong(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(WatchAppColor.surfaceMuted, in: Capsule())
            }
            .padding(.horizontal, 4)

            ForEach(items) { item in
               NavigationLink(value: WatchRoute.toDoDetail(item.id)) {
                  WatchToDoRow(item: item, accent: accent)
               }
               .buttonStyle(.plain)
            }
         }
         .padding(.top, 3)
      }
   }
}

private struct WatchTagEditorSection: View {
   @Binding var tagNames: [String]
   @Binding var draft: String

   var body: some View {
      WatchActionGroup(title: "Tags", systemImage: "tag.fill", accent: WatchAppColor.secondary, cardSpacing: 8) {
         if !tagNames.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 6)], alignment: .leading, spacing: 6) {
               ForEach(tagNames, id: \.self) { tagName in
                  Button {
                     tagNames.removeAll { $0 == tagName }
                  } label: {
                     HStack(spacing: 4) {
                        Text(tagName)
                           .lineLimit(1)
                           .minimumScaleFactor(0.7)
                        Image(systemName: "xmark")
                           .font(.watchSymbol(8, weight: .black))
                     }
                     .font(.watchBodyStrong(11, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .padding(.horizontal, 8)
                     .padding(.vertical, 5)
                     .background(WatchAppColor.surfaceMuted, in: Capsule())
                  }
                  .buttonStyle(.plain)
               }
            }
         }

         HStack(spacing: 8) {
            TextField("Add tag", text: $draft)
               .font(.watchUserEntry(13, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.textPrimary)
               .textInputAutocapitalization(.never)

            Button {
               addDraft()
            } label: {
               Image(systemName: "plus")
            }
            .buttonStyle(WatchCompactIconButtonStyle(
               fill: WatchAppColor.secondary,
               size: 30,
               minHeight: 30,
               symbolSize: 13,
               cornerRadius: 15
            ))
            .disabled(sanitized(draft).isEmpty)
         }
      }
   }

   private func addDraft() {
      let name = sanitized(draft)
      guard !name.isEmpty else { return }
      if !tagNames.contains(name), tagNames.count < 5 {
         tagNames.append(name)
      }
      draft = ""
   }

   private func sanitized(_ value: String) -> String {
      value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
   }
}

private struct WatchRecurrenceEditorSection: View {
   @Binding var isEnabled: Bool
   @Binding var unitRaw: String
   @Binding var interval: Int
   @Binding var modeRaw: String
   @Binding var count: Int
   let hasDueDate: Bool

   var body: some View {
      WatchActionGroup(title: "Repeat", systemImage: "repeat", accent: WatchAppColor.secondary, cardSpacing: 8) {
         Toggle(isOn: Binding(
            get: { isEnabled },
            set: { newValue in isEnabled = hasDueDate && newValue }
         )) {
            Text("Repeat this toDō")
               .font(.watchBodyStrong(13, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.textPrimary)
         }
         .tint(WatchAppColor.secondary)

         if !hasDueDate {
            Text("Add a due date first.")
               .font(.watchBody(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)
         }

         if isEnabled {
            Stepper(value: $interval, in: 1...30) {
               Text(String(format: String(localized: "Every %@"), WatchLocalization.numberString(interval)))
                  .font(.watchBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(WatchAppColor.textPrimary)
            }

            Picker("Unit", selection: $unitRaw) {
               ForEach(WatchRecurrenceUnitOption.allCases) { option in
                  Text(option.title).tag(option.rawValue)
               }
            }
            .pickerStyle(.navigationLink)
            .tint(WatchAppColor.secondary)

            Picker("Ending", selection: $modeRaw) {
               ForEach(WatchRecurrenceModeOption.allCases) { option in
                  Text(option.title).tag(option.rawValue)
               }
            }
            .pickerStyle(.navigationLink)
            .tint(WatchAppColor.secondary)

            if modeRaw == WatchRecurrenceModeOption.finite.rawValue {
               Stepper(value: $count, in: 1...24) {
                  Text(String(format: String(localized: "%@ reminders"), WatchLocalization.numberString(count)))
                     .font(.watchBodyStrong(12, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)
               }
            }
         }
      }
   }
}

private struct WatchLocationReminderEditorSection: View {
   @Binding var isEnabled: Bool
   @Binding var latitude: Double?
   @Binding var longitude: Double?
   @Binding var radius: Double
   @Binding var triggerRaw: String
   @Binding var label: String
   @ObservedObject var locationService: WatchLocationCaptureService

   var body: some View {
      WatchActionGroup(title: "Place", systemImage: "location.fill", accent: WatchAppColor.actionSuccess, cardSpacing: 8) {
         Toggle(isOn: $isEnabled) {
            Text("Remind by place")
               .font(.watchBodyStrong(13, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.textPrimary)
         }
         .tint(WatchAppColor.actionSuccess)

         if isEnabled {
            Picker("Trigger", selection: $triggerRaw) {
               ForEach(WatchLocationTriggerOption.allCases) { option in
                  Text(option.title).tag(option.rawValue)
               }
            }
            .pickerStyle(.navigationLink)
            .tint(WatchAppColor.actionSuccess)

            Stepper(value: $radius, in: 100...800, step: 50) {
               Text(String(format: String(localized: "%@ m radius"), WatchLocalization.numberString(Int(radius))))
                  .font(.watchBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(WatchAppColor.textPrimary)
            }

            TextField("Place label", text: $label)
               .font(.watchUserEntry(13, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.textPrimary)

            Button {
               Task {
                  if let location = await locationService.requestLocation() {
                     latitude = location.coordinate.latitude
                     longitude = location.coordinate.longitude
                     if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        label = String(localized: "Current Location")
                     }
                  }
               }
            } label: {
               if locationService.isLocating {
                  ProgressView()
                     .controlSize(.mini)
               } else {
                  Label(latitude == nil ? "Use Current Location" : "Update Location", systemImage: "location.circle.fill")
               }
            }
            .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionSuccess))

            if let statusText = locationService.statusText {
               Text(statusText)
                  .font(.watchBody(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
            }
         }
      }
   }
}

struct CaptureToDoView: View {
   @ObservedObject var store: WatchToDoStore
   var onCreated: (() -> Void)?
   @Environment(\.dismiss) private var dismiss
   @State private var task = ""
   @State private var notes = ""
   @State private var tagDraft = ""
   @State private var tagNames: [String] = []
   @State private var nanoDoDraft = ""
   @State private var nanoDoTasks: [String] = []
   @State private var dueDate: Date?
   @State private var isTimeSensitive = false
   @State private var recurrenceEnabled = false
   @State private var recurrenceUnitRaw = WatchRecurrenceUnitOption.days.rawValue
   @State private var recurrenceInterval = 1
   @State private var recurrenceModeRaw = WatchRecurrenceModeOption.finite.rawValue
   @State private var recurrenceCount = 1
   @State private var locationEnabled = false
   @State private var locationLatitude: Double?
   @State private var locationLongitude: Double?
   @State private var locationRadius = 150.0
   @State private var locationTriggerRaw = WatchLocationTriggerOption.arriving.rawValue
   @State private var locationLabel = ""
   @StateObject private var locationService = WatchLocationCaptureService()

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "New toDō",
               systemImage: "plus",
               accent: WatchAppColor.actionPrimary
            )

            ZStack(alignment: .topTrailing) {
               WatchCard {
                  TextField("what toDō today?", text: $task, axis: .vertical)
                     .font(.watchUserEntry(17, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .lineLimit(1...4)
                     .textInputAutocapitalization(.sentences)
               }

               Button {
                  extractDetailsFromTask()
               } label: {
                  Image(systemName: "mic.fill")
               }
               .buttonStyle(WatchCompactIconButtonStyle(
                  fill: WatchAppColor.actionPrimary,
                  size: 32,
                  minHeight: 32,
                  symbolSize: 15,
                  cornerRadius: 16
               ))
               .accessibilityLabel("Extract from text")
               .offset(x: -6, y: -8)
            }

            WatchCard(spacing: 12) {
               WatchScheduleSummary(dueDate: dueDate)

               if dueDate == nil {
                  Button {
                     dueDate = date(atHour: defaultTodayHour, minute: 0, on: Date())
                  } label: {
                     WatchScheduleWideAction(
                        title: "Add Due Date",
                        systemImage: "calendar",
                        accent: WatchAppColor.actionPrimary
                     )
                  }
                  .buttonStyle(.plain)
               } else {
                  HStack(spacing: 8) {
                     NavigationLink {
                        WatchDateSelectionView(
                           title: "Due Date",
                           selection: Binding(
                              get: { dueDate ?? defaultDateForNewSelection() },
                              set: { dueDate = merge(date: $0, withTimeFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Date",
                           value: dueDate.map(WatchLocalization.monthDayString) ?? "",
                           systemImage: "calendar",
                           accent: WatchAppColor.actionPrimary
                        )
                     }
                     .buttonStyle(.plain)

                     NavigationLink {
                        WatchTimeSelectionView(
                           title: "Due Time",
                           selection: Binding(
                              get: { dueDate ?? defaultDateForNewSelection() },
                              set: { dueDate = merge(time: $0, withDateFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Time",
                           value: dueDate.map(WatchLocalization.timeString) ?? "",
                           systemImage: "clock",
                           accent: WatchAppColor.secondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               VStack(alignment: .leading, spacing: 7) {
                  Text("Quick Picks")
                     .font(.watchBodyStrong(10, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.textSecondary)
                     .padding(.horizontal, 2)

                  HStack(spacing: 8) {
                     Button {
                        setQuickDue(.today)
                     } label: {
                        WatchSchedulePill(title: "Today", value: formattedDefaultTodayTime, accent: WatchAppColor.actionPrimary)
                     }
                     .buttonStyle(.plain)

                     Button {
                        setQuickDue(.tomorrow)
                     } label: {
                        WatchSchedulePill(title: "Tomorrow", value: formattedDefaultTomorrowTime, accent: WatchAppColor.secondary)
                     }
                     .buttonStyle(.plain)
                  }

                  if dueDate != nil {
                     Button {
                        dueDate = nil
                        isTimeSensitive = false
                     } label: {
                        WatchScheduleWideAction(
                           title: "Clear Due Date",
                           systemImage: "xmark",
                           accent: WatchAppColor.textSecondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               WatchScheduleToggleRow(
                  isOn: $isTimeSensitive,
                  dueDate: $dueDate,
                  defaultDueDate: { date(atHour: defaultTodayHour, minute: 0, on: Date()) }
               )
            }

            WatchRecurrenceEditorSection(
               isEnabled: $recurrenceEnabled,
               unitRaw: $recurrenceUnitRaw,
               interval: $recurrenceInterval,
               modeRaw: $recurrenceModeRaw,
               count: $recurrenceCount,
               hasDueDate: dueDate != nil
            )

            WatchTagEditorSection(tagNames: $tagNames, draft: $tagDraft)

            WatchLocationReminderEditorSection(
               isEnabled: $locationEnabled,
               latitude: $locationLatitude,
               longitude: $locationLongitude,
               radius: $locationRadius,
               triggerRaw: $locationTriggerRaw,
               label: $locationLabel,
               locationService: locationService
            )

            WatchActionGroup(title: "Notes", systemImage: "note.text", accent: WatchAppColor.secondary, cardSpacing: 8) {
               TextField("Add notes", text: $notes, axis: .vertical)
                  .font(.watchUserEntry(14, relativeTo: .body))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1...4)
            }

            WatchActionGroup(title: "NanoDos", systemImage: "smallcircle.filled.circle", accent: WatchAppColor.main, cardSpacing: 8) {
               ForEach(Array(nanoDoTasks.enumerated()), id: \.offset) { index, nanoDoTask in
                  HStack(spacing: 8) {
                     Text(nanoDoTask)
                        .font(.watchUserEntry(13, relativeTo: .caption))
                        .foregroundStyle(WatchAppColor.textPrimary)
                        .lineLimit(2)

                     Spacer(minLength: 0)

                     Button {
                        nanoDoTasks.remove(at: index)
                     } label: {
                        Image(systemName: "xmark")
                           .font(.watchSymbol(10, weight: .black))
                     }
                     .buttonStyle(WatchCompactIconButtonStyle(
                        fill: WatchAppColor.destructive,
                        size: 26,
                        minHeight: 26,
                        symbolSize: 10,
                        cornerRadius: 13
                     ))
                     .accessibilityLabel("Remove nanoDo")
                  }
               }

               HStack(spacing: 8) {
                  TextField("Add nanoDo", text: $nanoDoDraft)
                     .font(.watchUserEntry(13, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  Button {
                     addNanoDoDraft()
                  } label: {
                     Image(systemName: "plus")
                  }
                  .buttonStyle(WatchCompactIconButtonStyle(
                     fill: WatchAppColor.main,
                     size: 30,
                     minHeight: 30,
                     symbolSize: 13,
                     cornerRadius: 15
                  ))
                  .disabled(nanoDoDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
               }
            }

            Button {
               store.create(
                  task: task,
                  dueDate: dueDate,
                  isTimeSensitive: isTimeSensitive,
                  notes: notes,
                  tagNames: tagNames,
                  recurrenceUnitRaw: recurrenceEnabled && dueDate != nil ? recurrenceUnitRaw : nil,
                  recurrenceInterval: recurrenceEnabled && dueDate != nil ? recurrenceInterval : nil,
                  recurrenceModeRaw: recurrenceEnabled && dueDate != nil ? recurrenceModeRaw : nil,
                  recurrenceCount: recurrenceEnabled && dueDate != nil && recurrenceModeRaw == WatchRecurrenceModeOption.finite.rawValue ? recurrenceCount : nil,
                  locationReminderLatitude: locationEnabled ? locationLatitude : nil,
                  locationReminderLongitude: locationEnabled ? locationLongitude : nil,
                  locationReminderRadius: locationEnabled ? locationRadius : nil,
                  locationReminderTriggerRaw: locationEnabled ? locationTriggerRaw : nil,
                  locationReminderLabel: locationEnabled ? locationLabel : nil,
                  nanoDoTasks: nanoDoTasks
               )
               onCreated?()
               dismiss()
            } label: {
               Text("Add toDō")
                  .font(.watchButton(20, relativeTo: .title3))
            }
            .buttonStyle(WatchProminentButtonStyle())
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("")
      .toolbar {
         ToolbarItem(placement: .cancellationAction) {
            Button {
               dismiss()
            } label: {
               WatchCloseIconButton()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
         }
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
   }

   private enum QuickDue { case today, tomorrow }

   private func addNanoDoDraft() {
      let trimmed = nanoDoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }
      nanoDoTasks.append(trimmed)
      nanoDoDraft = ""
   }

   private var defaultTodayHour: Int { 17 }
   private var defaultTomorrowHour: Int { 9 }

   private func defaultDateForNewSelection() -> Date {
      Date()
   }

   private func date(atHour hour: Int, minute: Int, on baseDay: Date) -> Date {
      var comps = Calendar.current.dateComponents([.year, .month, .day], from: baseDay)
      comps.hour = hour
      comps.minute = minute
      comps.second = 0
      return Calendar.current.date(from: comps) ?? baseDay
   }

   private func merge(date newDay: Date, withTimeFrom base: Date?) -> Date {
      let cal = Calendar.current
      let baseTimeSource = base ?? date(atHour: defaultTodayHour, minute: 0, on: newDay)
      let time = cal.dateComponents([.hour, .minute, .second], from: baseTimeSource)
      var comps = cal.dateComponents([.year, .month, .day], from: newDay)
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = time.second
      return cal.date(from: comps) ?? newDay
   }

   private func merge(time newTime: Date, withDateFrom base: Date?) -> Date {
      let cal = Calendar.current
      let baseDay = base ?? newTime
      let time = cal.dateComponents([.hour, .minute, .second], from: newTime)
      var comps = cal.dateComponents([.year, .month, .day], from: baseDay)
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = time.second
      return cal.date(from: comps) ?? newTime
   }

   private var formattedDefaultTodayTime: String {
      WatchLocalization.timeString(date(atHour: defaultTodayHour, minute: 0, on: Date()))
   }

   private var formattedDefaultTomorrowTime: String {
      let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      return WatchLocalization.timeString(date(atHour: defaultTomorrowHour, minute: 0, on: tomorrow))
   }

   private func setQuickDue(_ quick: QuickDue) {
      let cal = Calendar.current
      switch quick {
      case .today:
         let today = cal.startOfDay(for: Date())
         let defaultBase = date(atHour: defaultTodayHour, minute: 0, on: today)
         let baseTime = dueDate ?? defaultBase
         dueDate = merge(date: today, withTimeFrom: baseTime)
      case .tomorrow:
         let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
         let defaultBase = date(atHour: defaultTomorrowHour, minute: 0, on: tomorrow)
         let baseTime = dueDate ?? defaultBase
         dueDate = merge(date: tomorrow, withTimeFrom: baseTime)
      }
   }

   private func extractDetailsFromTask() {
      let input = task.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !input.isEmpty else { return }

      if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
         let ns = input as NSString
         let range = NSRange(location: 0, length: ns.length)
         if let match = detector.firstMatch(in: input, options: [], range: range),
            let matchDate = match.date {
            var resolved = matchDate
            let matchedText = ns.substring(with: match.range).lowercased()
            let hasTimeIndicators = matchedText.range(of: "(\\d{1,2}:\\d{2}|\\d{1,2}\\s?(am|pm)|am|pm)", options: .regularExpression) != nil

            if !hasTimeIndicators {
               let cal = Calendar.current
               if cal.isDateInToday(matchDate) {
                  resolved = date(atHour: defaultTodayHour, minute: 0, on: matchDate)
               } else if cal.isDateInTomorrow(matchDate) {
                  resolved = date(atHour: defaultTomorrowHour, minute: 0, on: matchDate)
               }
               if let existing = dueDate {
                  resolved = merge(date: resolved, withTimeFrom: existing)
               }
            }

            dueDate = resolved
         }
      }

      let lower = input.lowercased()
      let sensitiveKeywords = ["urgent", "asap", "time-sensitive", "time sensitive", "immediately", "now", "priority", "!!!"]
      if sensitiveKeywords.contains(where: { lower.contains($0) }) {
         isTimeSensitive = true
      }
   }
}

private enum WatchRemovalAction: String {
   case archive
   case delete

   var systemImage: String {
      switch self {
      case .archive:
         return "archivebox.fill"
      case .delete:
         return "trash.fill"
      }
   }

   var fillColor: Color {
      switch self {
      case .archive:
         return WatchAppColor.secondary
      case .delete:
         return WatchAppColor.destructive
      }
   }

   var accessibilityLabel: LocalizedStringKey {
      switch self {
      case .archive:
         return "Archive"
      case .delete:
         return "Trash"
      }
   }
}

struct WatchToDoDetailView: View {
   let itemID: String
   @ObservedObject var store: WatchToDoStore
   var onDeleted: (String) -> Void = { _ in }
   @Environment(\.dismiss) private var dismiss
   @AppStorage("doneSwipePrimaryAction") private var removalActionRaw = "delete"
   @State private var isDeleting = false
   @State private var isBackdropVisible = false

   private var todo: WatchToDoItem? {
      store.items.first { $0.id == itemID }
   }

   private var removalAction: WatchRemovalAction {
      WatchRemovalAction(rawValue: removalActionRaw) ?? .delete
   }

   var body: some View {
      if let todo = todo {
         ScrollView {
            VStack(alignment: .leading, spacing: 12) {
               HStack(alignment: .center, spacing: 8) {
                  Image(systemName: todo.isDone ? "checkmark" : "circle.fill")
                     .font(.watchSymbol(todo.isDone ? 13 : 8, weight: .black))
                     .foregroundStyle(todo.isDone ? WatchAppColor.onAction : detailAccent(for: todo))
                     .frame(width: 28, height: 28)
                     .background(todo.isDone ? WatchAppColor.actionSuccess : detailAccent(for: todo).opacity(0.16), in: Circle())

                  Text("Your toDō")
                     .font(.watchDisplay(18, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  Spacer(minLength: 0)
               }

               WatchCard(spacing: 8) {
                  Text(todo.task)
                     .font(.watchUserEntry(20, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .strikethrough(todo.isDone)

                  if let dueDate = todo.dueDate {
                     WatchMetadataRow(
                        systemImage: "calendar",
                        title: String(localized: "Due"),
                        value: formattedDetailDateTime(dueDate),
                        accent: WatchAppColor.actionPrimary
                     )
                  }

                  if todo.isTimeSensitive {
                     WatchMetadataRow(
                        systemImage: "bolt.fill",
                        title: String(localized: "Priority"),
                        value: String(localized: "Time-Sensitive"),
                        accent: WatchAppColor.destructive
                     )
                  }

                  if let recurrenceSummary = todo.recurrenceSummary {
                     WatchMetadataRow(
                        systemImage: "repeat",
                        title: String(localized: "Repeat"),
                        value: recurrenceSummary,
                        accent: WatchAppColor.secondary
                     )
                  }

                  if todo.hasLocationReminder {
                     WatchMetadataRow(
                        systemImage: "location.fill",
                        title: todo.locationReminderTriggerTitle ?? String(localized: "Place"),
                        value: todo.locationReminderLabel ?? String(localized: "Location Reminder"),
                        accent: WatchAppColor.actionSuccess
                     )
                  }
               }

               if !todo.tags.isEmpty {
                  WatchActionGroup(title: "Tags", systemImage: "tag.fill", accent: WatchAppColor.secondary) {
                     LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(todo.tags) { tag in
                           Text(tag.name)
                              .font(.watchBodyStrong(11, relativeTo: .caption2))
                              .foregroundStyle(WatchAppColor.textPrimary)
                              .lineLimit(1)
                              .minimumScaleFactor(0.75)
                              .padding(.horizontal, 8)
                              .padding(.vertical, 5)
                              .background(WatchAppColor.surfaceMuted, in: Capsule())
                        }
                     }
                  }
               }

               if !todo.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                  WatchActionGroup(title: "Notes", systemImage: "note.text", accent: WatchAppColor.main) {
                     Text(todo.notes)
                        .font(.watchUserEntry(14, relativeTo: .body))
                        .foregroundStyle(WatchAppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                  }
               }

               if !todo.nanoDos.isEmpty {
                  WatchActionGroup(title: "nanoDos", systemImage: "smallcircle.filled.circle", accent: WatchAppColor.main) {
                     ForEach(todo.nanoDos) { nanoDo in
                        WatchNanoDoRow(
                           nanoDo: nanoDo,
                           onToggleDone: {
                              nanoDo.isDone ? store.reopenNanoDo(nanoDo, in: todo) : store.completeNanoDo(nanoDo, in: todo)
                           },
                           onDelete: {
                              store.deleteNanoDo(nanoDo, in: todo)
                           }
                        )
                     }
                  }
               }

               if store.canOpenOnPhone {
                  Button {
                     store.openOnPhone(todo)
                  } label: {
                     Label("Open on iPhone", systemImage: "iphone.and.arrow.forward")
                        .font(.watchBodyStrong(12, relativeTo: .caption))
                        .frame(maxWidth: .infinity)
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.main))
                  .accessibilityLabel("Open on iPhone")
               }

               WatchCard(spacing: 10) {
                  HStack(spacing: 10) {
                     Spacer(minLength: 0)

                     Button {
                        performRemovalAction(todo)
                     } label: {
                        Image(systemName: removalAction.systemImage)
                     }
                     .buttonStyle(WatchIconButtonStyle(fill: removalAction.fillColor, symbolSize: 17, symbolWeight: .black))
                     .accessibilityLabel(removalAction.accessibilityLabel)

                     Button {
                        todo.isDone ? store.reopen(todo) : store.complete(todo)
                     } label: {
                        Image(systemName: todo.isDone ? "arrow.uturn.backward" : "checkmark")
                     }
                     .buttonStyle(WatchIconButtonStyle(fill: todo.isDone ? WatchAppColor.secondary : WatchAppColor.actionSuccess, symbolSize: 17, symbolWeight: .black))
                     .accessibilityLabel(todo.isDone ? "Mark Active" : "Mark Done")

                     Spacer(minLength: 0)
                  }
               }

               HStack(spacing: 8) {
                  if !todo.isDone {
                     NavigationLink {
                        WatchSnoozePickerView(item: todo, store: store)
                     } label: {
                        Label("Snooze", systemImage: "clock.arrow.circlepath")
                           .font(.watchBodyStrong(12, relativeTo: .caption))
                           .frame(maxWidth: .infinity)
                     }
                     .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))
                  }

                  NavigationLink {
                     WatchToDoEditView(item: todo, store: store)
                  } label: {
                     Label("Edit", systemImage: "arrow.up.right")
                        .font(.watchBodyStrong(12, relativeTo: .caption))
                        .frame(maxWidth: .infinity)
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))
               }

               WatchCard(spacing: 6) {
                  HStack {
                     VStack(alignment: .leading, spacing: 2) {
                        Text("Created")
                           .font(.watchBodyStrong(10, relativeTo: .caption2))
                           .foregroundStyle(WatchAppColor.textSecondary)
                        Text(WatchLocalization.dateString(todo.createdAt))
                           .font(.watchBody(11, relativeTo: .caption2))
                     }
                     Spacer()
                     VStack(alignment: .trailing, spacing: 2) {
                        Text("Modified")
                           .font(.watchBodyStrong(10, relativeTo: .caption2))
                           .foregroundStyle(WatchAppColor.textSecondary)
                        Text(WatchLocalization.timeString(todo.updatedAt))
                           .font(.watchBody(11, relativeTo: .caption2))
                     }
                  }
               }
               .opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 14)
         }
         .frame(maxWidth: .infinity)
         .background {
            WatchFocusedToDoBackdrop(isVisible: isBackdropVisible)
         }
         .scaleEffect(isDeleting ? 0.86 : 1)
         .opacity(isDeleting ? 0.18 : 1)
         .overlay {
            if isDeleting {
               WatchDeletionBurstView()
                  .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
         }
         .animation(.spring(response: 0.34, dampingFraction: 0.76), value: isDeleting)
         .onAppear {
            isBackdropVisible = false
            withAnimation(.easeOut(duration: 0.46).delay(0.04)) {
               isBackdropVisible = true
            }
         }
	         .onDisappear {
	            withAnimation(.easeIn(duration: 0.22)) {
	               isBackdropVisible = false
	            }
	         }
	         .accessibilityIdentifier("watch.todo.view")
	      } else {
         Color.clear
            .task {
               dismiss()
            }
      }
   }

   private func delete(_ todo: WatchToDoItem) {
      guard !isDeleting else { return }
      WKInterfaceDevice.current().play(.click)
      withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
         isDeleting = true
      }

      Task {
         try? await Task.sleep(nanoseconds: 560_000_000)
         await MainActor.run {
            store.trash(todo)
            onDeleted(String(localized: "Deleted."))
            dismiss()
         }
      }
   }

   private func performRemovalAction(_ todo: WatchToDoItem) {
      switch removalAction {
      case .archive:
         guard !isDeleting else { return }
         WKInterfaceDevice.current().play(.click)
         store.archive(todo)
         dismiss()
      case .delete:
         delete(todo)
      }
   }

   private func detailAccent(for item: WatchToDoItem) -> Color {
      item.isOverdue ? WatchAppColor.destructive : (item.isTimeSensitive ? WatchAppColor.destructive : WatchAppColor.actionPrimary)
   }

   private func formattedDetailDateTime(_ date: Date) -> String {
      WatchLocalization.dateTimeString(date)
   }
}

private struct WatchFocusedToDoBackdrop: View {
   let isVisible: Bool

   var body: some View {
      ZStack {
         WatchAppColor.surfaceElevated

         Circle()
            .fill(
               RadialGradient(
                  colors: [
                     Color.black.opacity(isVisible ? 0.62 : 0),
                     Color.black.opacity(isVisible ? 0.38 : 0),
                     Color.black.opacity(isVisible ? 0.14 : 0),
                     .clear
                  ],
                  center: .center,
                  startRadius: 6,
                  endRadius: 122
               )
            )
            .scaleEffect(isVisible ? 1.2 : 0.72)
            .blur(radius: isVisible ? 3 : 13)
            .allowsHitTesting(false)
      }
      .ignoresSafeArea()
   }
}

struct WatchNanoDoRow: View {
   let nanoDo: WatchNanoDoItem
   let onToggleDone: () -> Void
   let onDelete: () -> Void

   var body: some View {
      HStack(spacing: 8) {
         Button(action: onToggleDone) {
            ZStack {
               Circle()
                  .fill(nanoDo.isDone ? WatchAppColor.actionSuccess : Color.clear)
               Circle()
                  .stroke(nanoDo.isDone ? Color.clear : WatchAppColor.main, lineWidth: 2)
               Image(systemName: nanoDo.isDone ? "arrow.uturn.backward" : "checkmark")
                  .font(.watchSymbol(nanoDo.isDone ? 12 : 13, weight: .black))
                  .foregroundStyle(nanoDo.isDone ? WatchAppColor.onAction : WatchAppColor.main)
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
         }
         .buttonStyle(.plain)
         .accessibilityLabel(nanoDo.isDone ? "Mark nanoDo active" : "Mark nanoDo done")

         VStack(alignment: .leading, spacing: 2) {
            Text(nanoDo.task)
               .font(.watchBodyStrong(13, relativeTo: .caption))
               .foregroundStyle(nanoDo.isDone ? WatchAppColor.textSecondary : WatchAppColor.textPrimary)
               .lineLimit(2)
               .strikethrough(nanoDo.isDone)

            if let dueDate = nanoDo.dueDate {
               Text(WatchLocalization.dateTimeString(dueDate))
                  .font(.watchBody(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
            }
         }

         Spacer(minLength: 0)

         Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash")
               .font(.watchSymbol(12, weight: .bold))
               .frame(width: 28, height: 28)
         }
         .buttonStyle(.plain)
         .foregroundStyle(WatchAppColor.destructive)
         .accessibilityLabel("Delete nanoDo")
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
   }
}

struct WatchDeletionBurstView: View {
   @State private var animate = false

   var body: some View {
      ZStack {
         Circle()
            .stroke(WatchAppColor.destructive.opacity(0.42), lineWidth: 2)
            .frame(width: animate ? 96 : 38, height: animate ? 96 : 38)
            .opacity(animate ? 0 : 1)

         Circle()
            .fill(WatchAppColor.destructive)
            .frame(width: animate ? 54 : 42, height: animate ? 54 : 42)
            .shadow(color: WatchAppColor.destructive.opacity(0.35), radius: 12, y: 3)

         Image(systemName: "trash")
            .font(.watchSymbol(20, weight: .black))
            .foregroundStyle(WatchAppColor.onAction)
            .scaleEffect(animate ? 1.08 : 0.88)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear {
         withAnimation(.easeOut(duration: 0.52)) {
            animate = true
         }
      }
      .accessibilityHidden(true)
   }
}

struct WatchToastView: View {
   let message: String

   var body: some View {
      HStack(spacing: 8) {
         Image(systemName: "trash")
            .font(.watchSymbol(12, weight: .black))
            .foregroundStyle(WatchAppColor.onAction)
            .frame(width: 24, height: 24)
            .background(WatchAppColor.destructive, in: Circle())

         Text(message)
            .font(.watchBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)

         Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(WatchAppColor.surfaceElevated, in: Capsule(style: .continuous))
      .overlay {
         Capsule(style: .continuous)
            .stroke(WatchAppColor.destructive.opacity(0.42), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
      .accessibilityElement(children: .combine)
   }
}

struct WatchDueReminderBanner: View {
   let item: WatchToDoItem
   let now: Date
   let onOpen: () -> Void
   let onDone: () -> Void
   let onSnooze: () -> Void
   let onDismiss: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         HStack(alignment: .center, spacing: 7) {
            Image(systemName: item.isTimeSensitive ? "bolt.fill" : "bell.badge.fill")
               .font(.watchBodyStrong(11, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.onAction)
               .frame(width: 23, height: 23)
               .background(WatchAppColor.main, in: Circle())

            Text(item.task)
               .font(.watchUserEntry(15, relativeTo: .headline))
               .foregroundStyle(WatchAppColor.textPrimary)
               .lineLimit(1)
               .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
               WatchCloseIconButton(size: 29, symbolSize: 13)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss details")
         }

         Text(dueText)
            .font(.watchBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.main)
            .lineLimit(1)

         HStack(spacing: 8) {
            Button(action: onDone) {
               Image(systemName: "checkmark")
                  .font(.watchSymbol(13, weight: .black))
                  .frame(width: 28, height: 28)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.actionSuccess, size: 34, symbolSize: 16, symbolWeight: .black))
            .accessibilityLabel("Done")

            Button(action: onSnooze) {
               Image(systemName: "arrow.clockwise")
                  .font(.watchSymbol(14, weight: .black))
                  .frame(width: 28, height: 28)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.white, foreground: WatchAppColor.black, size: 34, symbolSize: 16, symbolWeight: .black))
            .accessibilityLabel("Snooze 15 minutes")

            Button(action: onOpen) {
               Image(systemName: "arrow.up.right")
                  .font(.watchSymbol(13, weight: .black))
                  .frame(width: 28, height: 28)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.actionPrimary, size: 34, symbolSize: 16, symbolWeight: .black))
            .accessibilityLabel("Open toDō")
         }
         .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(10)
      .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(WatchAppColor.destructive, lineWidth: item.isTimeSensitive ? 1.4 : 0)
      }
      .shadow(color: Color.black.opacity(0.24), radius: 10, y: 5)
   }

   private var dueText: String {
      guard let dueDate = item.dueDate else { return "" }
      if dueDate <= now {
         return WatchLocalization.timeString(dueDate)
      }
      return WatchLocalization.dateTimeString(dueDate)
   }
}

private struct WatchDateSelectionView: View {
   let title: String
   @Binding var selection: Date

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         WatchScreenHeader(
            title: title,
            systemImage: "calendar",
            accent: WatchAppColor.actionPrimary
         )

         WatchCard {
            DatePicker(
               title,
               selection: $selection,
               displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .tint(WatchAppColor.actionPrimary)
            .frame(maxWidth: .infinity)
         }

         Text("Use the Digital Crown here. The main form stays easy to scroll.")
            .font(.watchBody(11, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)
            .padding(.horizontal, 4)
      }
      .padding(.horizontal, 2)
      .background(WatchAppColor.surface)
      .navigationTitle("")
      .toolbarBackground(.hidden, for: .navigationBar)
      .tint(WatchAppColor.actionPrimary)
   }
}

private struct WatchTimeSelectionView: View {
   let title: String
   @Binding var selection: Date

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         WatchScreenHeader(
            title: title,
            systemImage: "clock",
            accent: WatchAppColor.secondary
         )

         WatchCard {
            DatePicker(
               title,
               selection: $selection,
               displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .tint(WatchAppColor.secondary)
            .frame(maxWidth: .infinity)
         }

         Text("Set the time here, then swipe back when finished.")
            .font(.watchBody(11, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)
            .padding(.horizontal, 4)
      }
      .padding(.horizontal, 2)
      .background(WatchAppColor.surface)
      .navigationTitle("")
      .toolbarBackground(.hidden, for: .navigationBar)
      .tint(WatchAppColor.secondary)
   }
}

struct WatchToDoEditView: View {
   let item: WatchToDoItem
   @ObservedObject var store: WatchToDoStore
   @Environment(\.dismiss) private var dismiss

   @State private var task: String
   @State private var notes: String
   @State private var tagDraft = ""
   @State private var tagNames: [String]
   @State private var nanoDoDraft = ""
   @State private var dueDate: Date?
   @State private var isTimeSensitive: Bool
   @State private var recurrenceEnabled: Bool
   @State private var recurrenceUnitRaw: String
   @State private var recurrenceInterval: Int
   @State private var recurrenceModeRaw: String
   @State private var recurrenceCount: Int
   @State private var locationEnabled: Bool
   @State private var locationLatitude: Double?
   @State private var locationLongitude: Double?
   @State private var locationRadius: Double
   @State private var locationTriggerRaw: String
   @State private var locationLabel: String
   @StateObject private var locationService = WatchLocationCaptureService()

   init(item: WatchToDoItem, store: WatchToDoStore) {
      self.item = item
      self.store = store
      _task = State(initialValue: item.task)
      _notes = State(initialValue: item.notes)
      _tagNames = State(initialValue: item.tags.map(\.name))
      _dueDate = State(initialValue: item.dueDate)
      _isTimeSensitive = State(initialValue: item.isTimeSensitive)
      _recurrenceEnabled = State(initialValue: item.recurrenceUnitRaw != nil && item.dueDate != nil)
      _recurrenceUnitRaw = State(initialValue: item.recurrenceUnitRaw ?? WatchRecurrenceUnitOption.days.rawValue)
      _recurrenceInterval = State(initialValue: max(1, item.recurrenceInterval ?? 1))
      _recurrenceModeRaw = State(initialValue: item.recurrenceModeRaw ?? WatchRecurrenceModeOption.finite.rawValue)
      _recurrenceCount = State(initialValue: max(1, item.recurrenceCount ?? 1))
      _locationEnabled = State(initialValue: item.hasLocationReminder)
      _locationLatitude = State(initialValue: item.locationReminderLatitude)
      _locationLongitude = State(initialValue: item.locationReminderLongitude)
      _locationRadius = State(initialValue: item.locationReminderRadius ?? 150)
      _locationTriggerRaw = State(initialValue: item.locationReminderTriggerRaw ?? WatchLocationTriggerOption.arriving.rawValue)
      _locationLabel = State(initialValue: item.locationReminderLabel ?? "")
   }

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Edit toDō",
               systemImage: "arrow.up.right",
               accent: WatchAppColor.actionPrimary
            )

            WatchCard {
               TextField("toDō", text: $task, axis: .vertical)
                  .font(.watchUserEntry(17, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1...4)
                  .textInputAutocapitalization(.sentences)
            }

            WatchActionGroup(title: "Schedule", systemImage: "clock", accent: WatchAppColor.actionPrimary, cardSpacing: 12) {
               WatchScheduleSummary(dueDate: dueDate)

               if dueDate == nil {
                  Button {
                     dueDate = defaultDueDate()
                  } label: {
                     WatchScheduleWideAction(
                        title: "Add Due Date",
                        systemImage: "calendar",
                        accent: WatchAppColor.actionPrimary
                     )
                  }
                  .buttonStyle(.plain)
               } else {
                  HStack(spacing: 8) {
                     NavigationLink {
                        WatchDateSelectionView(
                           title: "Due Date",
                           selection: Binding(
                              get: { dueDate ?? defaultDueDate() },
                              set: { dueDate = merge(date: $0, withTimeFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Date",
                           value: dueDate.map(WatchLocalization.monthDayString) ?? "",
                           systemImage: "calendar",
                           accent: WatchAppColor.actionPrimary
                        )
                     }
                     .buttonStyle(.plain)

                     NavigationLink {
                        WatchTimeSelectionView(
                           title: "Due Time",
                           selection: Binding(
                              get: { dueDate ?? defaultDueDate() },
                              set: { dueDate = merge(time: $0, withDateFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Time",
                           value: dueDate.map(WatchLocalization.timeString) ?? "",
                           systemImage: "clock",
                           accent: WatchAppColor.secondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               VStack(alignment: .leading, spacing: 7) {
                  Text("Quick Picks")
                     .font(.watchBodyStrong(10, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.textSecondary)
                     .padding(.horizontal, 2)

                  HStack(spacing: 8) {
                     Button {
                        dueDate = quickDueDate(.today)
                     } label: {
                        WatchSchedulePill(title: "Today", value: formattedEditTodayTime, accent: WatchAppColor.actionPrimary)
                     }
                     .buttonStyle(.plain)

                     Button {
                        dueDate = quickDueDate(.tomorrow)
                     } label: {
                        WatchSchedulePill(title: "Tomorrow", value: formattedEditTomorrowTime, accent: WatchAppColor.secondary)
                     }
                     .buttonStyle(.plain)
                  }

                  if dueDate != nil {
                     Button {
                        dueDate = nil
                        isTimeSensitive = false
                     } label: {
                        WatchScheduleWideAction(
                           title: "Clear Due Date",
                           systemImage: "xmark",
                           accent: WatchAppColor.textSecondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               WatchScheduleToggleRow(
                  isOn: $isTimeSensitive,
                  dueDate: $dueDate,
                  defaultDueDate: defaultDueDate
               )
            }

            WatchRecurrenceEditorSection(
               isEnabled: $recurrenceEnabled,
               unitRaw: $recurrenceUnitRaw,
               interval: $recurrenceInterval,
               modeRaw: $recurrenceModeRaw,
               count: $recurrenceCount,
               hasDueDate: dueDate != nil
            )

            WatchTagEditorSection(tagNames: $tagNames, draft: $tagDraft)

            WatchLocationReminderEditorSection(
               isEnabled: $locationEnabled,
               latitude: $locationLatitude,
               longitude: $locationLongitude,
               radius: $locationRadius,
               triggerRaw: $locationTriggerRaw,
               label: $locationLabel,
               locationService: locationService
            )

            WatchActionGroup(title: "Notes", systemImage: "note.text", accent: WatchAppColor.secondary, cardSpacing: 8) {
               TextField("Add notes", text: $notes, axis: .vertical)
                  .font(.watchUserEntry(14, relativeTo: .body))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1...4)
            }

            WatchActionGroup(title: "NanoDos", systemImage: "smallcircle.filled.circle", accent: WatchAppColor.main, cardSpacing: 8) {
               if item.nanoDos.isEmpty {
                  Text("No nanoDos yet.")
                     .font(.watchBody(12, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textSecondary)
               } else {
                  ForEach(item.nanoDos) { nanoDo in
                     WatchNanoDoRow(
                        nanoDo: nanoDo,
                        onToggleDone: {
                           nanoDo.isDone ? store.reopenNanoDo(nanoDo, in: item) : store.completeNanoDo(nanoDo, in: item)
                        },
                        onDelete: {
                           store.deleteNanoDo(nanoDo, in: item)
                        }
                     )
                  }
               }

               HStack(spacing: 8) {
                  TextField("Add nanoDo", text: $nanoDoDraft)
                     .font(.watchUserEntry(13, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  Button {
                     addNanoDoDraft()
                  } label: {
                     Image(systemName: "plus")
                  }
                  .buttonStyle(WatchCompactIconButtonStyle(
                     fill: WatchAppColor.main,
                     size: 30,
                     minHeight: 30,
                     symbolSize: 13,
                     cornerRadius: 15
                  ))
                  .disabled(nanoDoDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
               }
            }

            Button {
               save()
            } label: {
               Text("Save")
                  .font(.watchButton(20, relativeTo: .title3))
            }
            .buttonStyle(WatchProminentButtonStyle())
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .background(WatchAppColor.surface)
      .navigationTitle("")
      .toolbar {
         ToolbarItem(placement: .cancellationAction) {
            Button {
               dismiss()
            } label: {
               WatchCloseIconButton()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
         }
      }
   }

   private func save() {
      store.updateTask(task, for: item)
      store.updateNotes(notes, for: item)
      store.setDueDate(dueDate, for: item, isTimeSensitive: dueDate == nil ? false : isTimeSensitive)
      store.updateTags(tagNames, for: item)
      store.setRecurrence(
         enabled: recurrenceEnabled && dueDate != nil,
         unitRaw: recurrenceUnitRaw,
         interval: recurrenceInterval,
         modeRaw: recurrenceModeRaw,
         count: recurrenceModeRaw == WatchRecurrenceModeOption.finite.rawValue ? recurrenceCount : nil,
         for: item,
         anchorDueDate: dueDate
      )
      store.setLocationReminder(
         enabled: locationEnabled && locationLatitude != nil && locationLongitude != nil,
         latitude: locationLatitude,
         longitude: locationLongitude,
         radius: locationRadius,
         triggerRaw: locationTriggerRaw,
         label: locationLabel,
         for: item
      )
      dismiss()
   }

   private func addNanoDoDraft() {
      let trimmed = nanoDoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }
      store.createNanoDo(trimmed, in: item)
      nanoDoDraft = ""
   }

   private func merge(date newDay: Date, withTimeFrom base: Date?) -> Date {
      let calendar = Calendar.current
      let baseTime = base ?? newDay
      let time = calendar.dateComponents([.hour, .minute, .second], from: baseTime)
      var components = calendar.dateComponents([.year, .month, .day], from: newDay)
      components.hour = time.hour
      components.minute = time.minute
      components.second = time.second
      return calendar.date(from: components) ?? newDay
   }

   private func merge(time newTime: Date, withDateFrom base: Date?) -> Date {
      let calendar = Calendar.current
      let baseDay = base ?? newTime
      let time = calendar.dateComponents([.hour, .minute, .second], from: newTime)
      var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
      components.hour = time.hour
      components.minute = time.minute
      components.second = time.second
      return calendar.date(from: components) ?? newTime
   }

   private func defaultDueDate() -> Date {
      let calendar = Calendar.current
      let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
      components.hour = 9
      components.minute = 0
      components.second = 0
      return calendar.date(from: components) ?? tomorrow
   }

   private enum EditQuickDue { case today, tomorrow }

   private var formattedEditTodayTime: String {
      WatchLocalization.timeString(date(atHour: 17, minute: 0, on: Date()))
   }

   private var formattedEditTomorrowTime: String {
      let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      return WatchLocalization.timeString(date(atHour: 9, minute: 0, on: tomorrow))
   }

   private func quickDueDate(_ quick: EditQuickDue) -> Date {
      let calendar = Calendar.current
      switch quick {
      case .today:
         return date(atHour: 17, minute: 0, on: calendar.startOfDay(for: Date()))
      case .tomorrow:
         let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
         return date(atHour: 9, minute: 0, on: tomorrow)
      }
   }

   private func date(atHour hour: Int, minute: Int, on baseDay: Date) -> Date {
      var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDay)
      components.hour = hour
      components.minute = minute
      components.second = 0
      return Calendar.current.date(from: components) ?? baseDay
   }
}

struct WatchSnoozeView: View {
   let toDoID: String
   @ObservedObject var store: WatchToDoStore
   @Environment(\.dismiss) private var dismiss

   @State private var selectedUnit: WatchSnoozeUnit? = nil
   @State private var selectedValue: Int? = nil

   private var todo: WatchToDoItem? {
      store.items.first { $0.id == toDoID }
   }

   var body: some View {
      if let todo = todo {
         List {
            if let unit = selectedUnit {
               Section("For how long?") {
                  ForEach(Array(unit.values.enumerated()), id: \.offset) { _, value in
                     Button {
                        selectedValue = value
                        store.snooze(todo, seconds: unit.seconds(for: value))

                        Task {
                           try? await Task.sleep(nanoseconds: 300_000_000)
                           dismiss() // Returns to Detail View
                        }
                     } label: {
                        HStack {
                           Text(unit.label(for: value))
                              .font(.watchBodyStrong(15, relativeTo: .body))
                           Spacer()
                           if selectedValue == value {
                              Image(systemName: "checkmark")
                           }
                        }
                        .foregroundStyle(selectedValue == value ? WatchAppColor.actionSuccess : WatchAppColor.actionSecondary)
                     }
                  }
               }
            } else {
               Section("Snooze Unit") {
                  ForEach(WatchSnoozeUnit.allCases) { unit in
                     Button {
                        withAnimation { selectedUnit = unit }
                     } label: {
                        Text(unit.title)
                           .font(.watchBodyStrong(15, relativeTo: .body))
                     }
                  }
               }
            }
         }
         .navigationTitle(selectedUnit?.title ?? "Snooze")
      }
   }
}

struct WatchToDoRowActionButton: View {
   let item: WatchToDoItem
   let accent: Color
   let onOpen: () -> Void
   let onToggleDone: () -> Void

   var body: some View {
      WatchToDoRow(
         item: item,
         accent: accent,
         onOpen: onOpen,
         onToggleDone: onToggleDone
      )
      .accessibilityElement(children: .contain)
      .accessibilityLabel(item.task)
      .accessibilityHint("Open this toDō or use the leading control to mark it done.")
   }
}

struct WatchToDoRow: View {
   let item: WatchToDoItem
   let accent: Color
   var onOpen: (() -> Void)?
   var onToggleDone: (() -> Void)?

   var body: some View {
      HStack(alignment: .center, spacing: 9) {
         if onToggleDone != nil {
            completionControl
         }

         if let onOpen {
            Button {
               onOpen()
            } label: {
               rowContent
            }
            .buttonStyle(.plain)
         } else {
            rowContent
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 9)
      .padding(.vertical, 8)
      .background(rowBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(rowBorderColor, lineWidth: rowBorderWidth)
      }
      .scaleEffect(item.isDone ? 0.985 : 1)
      .animation(.spring(response: 0.34, dampingFraction: 0.72), value: item.isDone)
   }

   private var rowContent: some View {
      HStack(alignment: .center, spacing: 8) {
         VStack(alignment: .leading, spacing: 3) {
            Text(item.task)
               .font(.watchUserEntry(16, relativeTo: .headline))
               .foregroundStyle(taskTextColor)
               .lineLimit(2)
               .strikethrough(item.isDone)

            Text(item.dueDate.map(formattedDueText) ?? (item.isDone ? "" : String(localized: "Quiet")))
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(metadataColor)
               .lineLimit(2)
               .fixedSize(horizontal: false, vertical: true)

            if item.isTimeSensitive || !item.nanoDos.isEmpty || !item.tags.isEmpty {
               HStack(spacing: 8) {
                  if item.isTimeSensitive {
                     Label("Time-Sensitive", systemImage: "exclamationmark.circle.fill")
                        .labelStyle(.iconOnly)
                  }

                  if !item.nanoDos.isEmpty {
                     Label(WatchLocalization.numberString(item.nanoDos.count), systemImage: "smallcircle.filled.circle")
                  }

                  if !item.tags.isEmpty {
                     Label(WatchLocalization.numberString(item.tags.count), systemImage: "tag.fill")
                  }
               }
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(metadataColor)
               .lineLimit(1)
               .minimumScaleFactor(0.8)
            }
         }

         Spacer(minLength: 0)

         if onOpen != nil {
            Image(systemName: "chevron.right")
               .font(.watchBodyStrong(9, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary.opacity(0.7))
               .padding(.top, 5)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
   }

   private var completionControl: some View {
      Group {
         if let onToggleDone {
            Button {
               onToggleDone()
            } label: {
               completionIndicator
            }
            .buttonStyle(.plain)
         } else {
            completionIndicator
         }
      }
      .accessibilityLabel(item.isDone ? "Mark Active" : "Mark Done")
   }

   private var completionIndicator: some View {
      ZStack {
         Circle()
            .fill(completionFill)
            .frame(width: 32, height: 32)

         if item.isDone {
            Image(systemName: "checkmark")
               .font(.watchSymbol(14, weight: .black))
               .foregroundStyle(completionSymbolColor)
               .scaleEffect(1.04)
         }
      }
      .overlay {
         Circle()
            .stroke(completionStroke, lineWidth: item.isDone ? 0 : 2)
      }
      .shadow(color: completionFill.opacity(item.isDone ? 0 : 0.22), radius: 8, y: 3)
      .animation(.spring(response: 0.32, dampingFraction: 0.66), value: item.isDone)
   }

   private var rowBackground: Color {
      if item.isDone {
         return WatchAppColor.surfaceMuted.opacity(0.58)
      }
      if item.isOverdue {
         return WatchAppColor.destructive
      }
      return WatchAppColor.surfaceElevated
   }

   private var completionFill: Color {
      if item.isDone {
         return WatchAppColor.main
      }
      return Color.clear
   }

   private var completionStroke: Color {
      item.isDone ? Color.clear : WatchAppColor.main
   }

   private var completionSymbolColor: Color {
      WatchAppColor.onAction
   }

   private var rowBorderColor: Color {
      guard !item.isDone else { return WatchAppColor.border }
      if item.isTimeSensitive {
         return WatchAppColor.destructive
      }
      return WatchAppColor.border
   }

   private var rowBorderWidth: CGFloat {
      item.isTimeSensitive && !item.isDone ? 1.5 : 1
   }

   private var taskTextColor: Color {
      if item.isDone {
         return WatchAppColor.textSecondary
      }
      return item.isOverdue ? WatchAppColor.white : WatchAppColor.textPrimary
   }

   private var metadataColor: Color {
      if item.isOverdue {
         return WatchAppColor.white.opacity(0.84)
      }
      return item.isTimeSensitive ? WatchAppColor.destructive : WatchAppColor.textSecondary
   }

   private func formattedDueText(_ date: Date) -> String {
      let cal = Calendar.current
      if cal.isDateInToday(date) {
         return String(localized: "Today") + " " + WatchLocalization.timeString(date)
      } else if cal.isDateInTomorrow(date) {
         return String(localized: "Tomorrow") + " " + WatchLocalization.timeString(date)
      } else {
         return WatchLocalization.dateTimeString(date)
      }
   }
}

struct WatchScreenHeader: View {
   let title: String
   let subtitle: String?
   let systemImage: String
   let accent: Color

   init(title: String, subtitle: String? = nil, systemImage: String, accent: Color) {
      self.title = title
      self.subtitle = subtitle
      self.systemImage = systemImage
      self.accent = accent
   }

   var body: some View {
      HStack(alignment: .center, spacing: 9) {
         Image(systemName: systemImage)
            .font(.watchSymbol(16, weight: .black))
            .foregroundStyle(accent)
            .frame(width: 30, height: 30)
            .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: WatchAppColor.surfaceMuted.opacity(0.28), radius: 7, y: 3)

         VStack(alignment: .leading, spacing: 1) {
            Text(LocalizedStringKey(title))
               .font(.watchViewTitle(24, relativeTo: .title2))
               .foregroundStyle(WatchAppColor.textPrimary)

            if let subtitle, !subtitle.isEmpty {
               Text(LocalizedStringKey(subtitle))
                  .font(.watchBody(11, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
                  .lineLimit(2)
            }
         }
      }
      .padding(.top, 3)
      .accessibilityElement(children: .combine)
   }
}

struct WatchCard<Content: View>: View {
   private let spacing: CGFloat
   @ViewBuilder private let content: Content

   init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
      self.spacing = spacing
      self.content = content()
   }

   var body: some View {
      VStack(alignment: .leading, spacing: spacing) {
         content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
   }
}

struct WatchMetadataRow: View {
   let systemImage: String
   let title: String
   let value: String
   let accent: Color

   var body: some View {
      HStack(spacing: 8) {
         Image(systemName: systemImage)
            .font(.watchBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(accent)
            .frame(width: 20, height: 20)
            .background(accent.opacity(0.14), in: Circle())

         VStack(alignment: .leading, spacing: 1) {
            Text(LocalizedStringKey(title))
               .font(.watchBodyStrong(10, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)

            Text(value)
               .font(.watchBodyStrong(12, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.textPrimary)
               .lineLimit(2)
         }
      }
   }
}

struct WatchPickerBlock<Content: View>: View {
   let title: String
   let systemImage: String
   let height: CGFloat
   @ViewBuilder let content: Content

   var body: some View {
      VStack(alignment: .leading, spacing: 6) {
         Label(LocalizedStringKey(title), systemImage: systemImage)
            .font(.watchBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)

         content
            .frame(maxWidth: .infinity)
            .frame(height: height)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }
}

struct WatchScheduleSummary: View {
   let dueDate: Date?

   var body: some View {
      HStack(spacing: 10) {
         Image(systemName: dueDate == nil ? "calendar" : "calendar")
            .font(.watchSymbol(14, weight: .black))
            .foregroundStyle(accent)
            .frame(width: 28, height: 28)

         VStack(alignment: .leading, spacing: 2) {
            Text("Schedule")
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondaryStrong)

            Text(summaryText)
               .font(.watchDisplay(17, relativeTo: .headline))
               .foregroundStyle(WatchAppColor.textPrimary)
               .lineLimit(2)
         }

         Spacer(minLength: 0)
      }
      .padding(.horizontal, 2)
      .padding(.vertical, 3)
   }

   private var accent: Color {
      dueDate == nil ? WatchAppColor.textSecondary : WatchAppColor.actionPrimary
   }

   private var summaryText: String {
      guard let dueDate else { return String(localized: "No Due Date") }
      return WatchLocalization.dateTimeString(dueDate)
   }
}

struct WatchScheduleTile: View {
   let title: String
   let value: String
   let systemImage: String
   let accent: Color

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         Image(systemName: systemImage)
            .font(.watchSymbol(15, weight: .black))
            .foregroundStyle(WatchAppColor.onAction)
            .frame(width: 30, height: 24, alignment: .leading)

         Text(LocalizedStringKey(title))
            .font(.watchBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.onAction.opacity(0.72))

            Text(value)
            .font(.watchBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.onAction)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(9)
      .background(
         RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(accent)
      )
      .shadow(color: accent.opacity(0.18), radius: 8, y: 4)
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
   }
}

struct WatchSchedulePill: View {
   let title: String
   let value: String
   let accent: Color

   var body: some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(LocalizedStringKey(title))
            .font(.watchBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.onAction)
            .lineLimit(1)

         Text(value)
            .font(.watchBodyStrong(9, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.onAction.opacity(0.72))
            .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
      .padding(.horizontal, 9)
      .background(
         Capsule(style: .continuous)
            .fill(accent)
      )
      .shadow(color: accent.opacity(0.16), radius: 6, y: 3)
      .contentShape(Capsule(style: .continuous))
   }
}

struct WatchScheduleWideAction: View {
   let title: String
   let systemImage: String
   let accent: Color

   var body: some View {
      HStack(spacing: 9) {
         Image(systemName: systemImage)
            .font(.watchSymbol(15, weight: .black))
            .foregroundStyle(WatchAppColor.onAction)
            .frame(width: 30, height: 30)

         VStack(alignment: .leading, spacing: 1) {
           Text(LocalizedStringKey(title))
               .font(.watchButton(18, relativeTo: .headline))
               .foregroundStyle(WatchAppColor.onAction)
         }

         Spacer(minLength: 0)
      }
      .padding(10)
      .background(
         RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(accent)
      )
      .shadow(color: accent.opacity(0.18), radius: 8, y: 4)
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
   }
}

struct WatchScheduleToggleRow: View {
   @Binding var isOn: Bool
   @Binding var dueDate: Date?
   let defaultDueDate: () -> Date

   var body: some View {
      Button {
         if dueDate == nil {
            dueDate = defaultDueDate()
         }
         isOn.toggle()
      } label: {
         HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
               .font(.watchSymbol(15, weight: .black))
               .foregroundStyle(foreground)
               .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
               Text("Time-Sensitive")
                  .font(.watchBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(foreground)
            }

            Spacer(minLength: 0)

            Text(isOn ? String(localized: "On") : String(localized: "Off"))
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(stateTextColor)
               .padding(.horizontal, 8)
               .padding(.vertical, 5)
               .background(stateBackground, in: Capsule(style: .continuous))
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(10)
         .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
               .fill(background)
         )
         .overlay {
            if !isOn {
               RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .stroke(WatchAppColor.destructive, lineWidth: 2)
            }
         }
         .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
      .shadow(color: isOn ? WatchAppColor.destructive.opacity(0.18) : .clear, radius: 8, y: 4)
   }

   private var foreground: Color {
      isOn ? WatchAppColor.onAction : WatchAppColor.destructive
   }

   private var background: some ShapeStyle {
      isOn ? AnyShapeStyle(WatchAppColor.destructive) : AnyShapeStyle(Color.clear)
   }

   private var stateTextColor: Color {
      isOn ? WatchAppColor.destructive : WatchAppColor.destructive
   }

   private var stateBackground: Color {
      isOn ? WatchAppColor.onAction.opacity(0.95) : WatchAppColor.destructive.opacity(0.12)
   }
}

struct WatchActionGroup<Content: View>: View {
   let title: String
   let systemImage: String
   let accent: Color
   var cardSpacing: CGFloat = 7
   @ViewBuilder let content: Content

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         Label(LocalizedStringKey(title), systemImage: systemImage)
            .font(.watchDisplay(18, relativeTo: .headline))
            .foregroundStyle(accent)
            .padding(.horizontal, 4)

         WatchCard(spacing: cardSpacing) {
            content
         }
      }
   }
}

struct WatchProminentButtonStyle: ButtonStyle {
   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(20, relativeTo: .title3))
         .foregroundStyle(WatchAppColor.onAction)
         .frame(minWidth: 122, minHeight: 48)
         .padding(.horizontal, 16)
         .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
               .fill(configuration.isPressed ? WatchAppColor.secondary : WatchAppColor.actionPrimary)
         )
         .shadow(
            color: (configuration.isPressed ? WatchAppColor.secondary : WatchAppColor.actionPrimary).opacity(0.2),
            radius: 8,
            y: 4
         )
         .scaleEffect(configuration.isPressed ? 0.96 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchHomeActionButtonStyle: ButtonStyle {
   let foreground: Color
   let fill: Color
   let pressedFill: Color
   let height: CGFloat

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(19, relativeTo: .headline))
         .foregroundStyle(foreground)
         .padding(.horizontal, 12)
         .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .center)
         .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
               .fill(configuration.isPressed ? pressedFill : fill)
         )
         .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
         .scaleEffect(configuration.isPressed ? 0.97 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchFilledButtonStyle: ButtonStyle {
   let fill: Color

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(18, relativeTo: .headline))
         .foregroundStyle(WatchAppColor.onAction)
         .padding(.vertical, 9)
         .padding(.horizontal, 12)
         .background(
            Capsule(style: .continuous)
               .fill(configuration.isPressed ? fill.opacity(0.74) : fill)
         )
         .scaleEffect(configuration.isPressed ? 0.96 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchIconButtonStyle: ButtonStyle {
   let fill: Color
   var foreground: Color = WatchAppColor.onAction
   var size: CGFloat = 38
   var symbolSize: CGFloat = 15
   var symbolWeight: Font.Weight = .semibold
   var stroke: Color?
   var strokeWidth: CGFloat = 0

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchSymbol(symbolSize, weight: symbolWeight))
         .foregroundStyle(foreground)
         .frame(width: size, height: size)
         .background {
            Circle()
               .fill(.regularMaterial)
               .overlay {
                  Circle()
                     .fill(configuration.isPressed ? fill.opacity(0.58) : fill.opacity(0.82))
               }
         }
         .overlay {
            if let stroke, strokeWidth > 0 {
               Circle().stroke(stroke, lineWidth: strokeWidth)
            }
         }
         .scaleEffect(configuration.isPressed ? 0.93 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchCompactIconButtonStyle: ButtonStyle {
   let fill: Color
   var foreground: Color = WatchAppColor.onAction
   var size: CGFloat = 34
   var minHeight: CGFloat = 34
   var symbolSize: CGFloat = 15
   var cornerRadius: CGFloat = 13

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchSymbol(symbolSize, weight: .black))
         .foregroundStyle(foreground)
         .frame(
            minWidth: size,
            idealWidth: size,
            maxWidth: size,
            minHeight: minHeight
         )
         .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
               .fill(configuration.isPressed ? fill.opacity(0.72) : fill)
         )
         .shadow(color: fill.opacity(0.18), radius: 7, y: 3)
         .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
         .scaleEffect(configuration.isPressed ? 0.94 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchCloseIconButton: View {
   var size: CGFloat = 34
   var symbolSize: CGFloat = 15

   var body: some View {
      Image(systemName: "xmark")
         .font(.watchSymbol(symbolSize, weight: .black))
         .foregroundStyle(WatchAppColor.onAction)
         .frame(width: size, height: size, alignment: .center)
         .background(WatchAppColor.destructive, in: Circle())
         .contentShape(Circle())
   }
}

struct WatchSoftButtonStyle: ButtonStyle {
   let accent: Color

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(18, relativeTo: .headline))
         .foregroundStyle(accent)
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.vertical, 8)
         .padding(.horizontal, 10)
         .background(
         RoundedRectangle(cornerRadius: 14, style: .continuous)
               .fill(configuration.isPressed ? accent.opacity(0.24) : accent.opacity(0.13))
         )
         .scaleEffect(configuration.isPressed ? 0.97 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchCircleButtonStyle: ButtonStyle {
   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .foregroundStyle(WatchAppColor.onAction)
         .background(
            Circle()
               .fill(configuration.isPressed ? WatchAppColor.secondary : WatchAppColor.actionPrimary)
         )
         .scaleEffect(configuration.isPressed ? 0.94 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

#Preview {
   ToDosView()
}
