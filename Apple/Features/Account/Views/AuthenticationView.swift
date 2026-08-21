import AuthenticationServices
import CryptoKit
import SwiftUI
import SwiftData

struct AuthenticationView: View {
   @Environment(\.dismiss) private var dismiss
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.appReduceMotion) private var reduceMotion
   
   @State private var currentAppleNonce = ""
   @State private var authenticationIntent: ToDoAccountAuthenticationIntent = .signIn
   @State private var expectedUsername = ""
   @State private var submittedUsername: String?
   @State private var isContinuingWithoutAccount = false
   @FocusState private var isUsernameFocused: Bool
   let onSkip: (() -> Void)?

   init(onSkip: (() -> Void)? = nil) {
      self.onSkip = onSkip
   }

   private var isGoogleAuthenticating: Bool { authStore.isGoogleAuthenticating }
   private var normalizedUsername: String? {
      try? ToDoProfilePolicy.validatedUsername(expectedUsername)
   }
   
   var body: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("toDō Sync")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)
         
            VStack(alignment: .leading, spacing: 14) {
               VStack(alignment: .leading, spacing: 4) {
                  Text("Sign in to keep toDō in sync.")
                     .font(.appBodyStrong(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)
               
               Text("Keep what matters available across iPhone, Android, and web.")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

               Picker("Account action", selection: $authenticationIntent) {
                  Text("Sign In").tag(ToDoAccountAuthenticationIntent.signIn)
                  Text("Create Account").tag(ToDoAccountAuthenticationIntent.createAccount)
               }
               .pickerStyle(.segmented)

               Text("1. Choose your username. 2. Verify ownership with Apple or Google.")
                  .font(.appBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.actionPrimary)
                  .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
               HStack(spacing: 10) {
                  TextField("Username", text: $expectedUsername)
                     .textInputAutocapitalization(.never)
                     .autocorrectionDisabled()
                     .submitLabel(.continue)
                     .focused($isUsernameFocused)
                     .onSubmit(showProviderChoices)
                     .font(.appBodyStrong(15, relativeTo: .body))
                     .padding(.horizontal, 14)
                     .padding(.vertical, 12)
                     .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))

                  Button(action: showProviderChoices) {
                     Image(systemName: "arrow.right")
                        .font(.appDisplay(17, relativeTo: .body))
                        .foregroundStyle(AppColor.brandYellowForeground(for: colorScheme))
                        .frame(width: 46, height: 46)
                        .background(AppColor.actionPrimary, in: Circle())
                        .contentShape(Circle())
                  }
                  .buttonStyle(.plain)
                  .disabled(normalizedUsername == nil || authStore.isAuthenticating)
                  .opacity(normalizedUsername == nil ? 0.42 : 1)
                  .accessibilityLabel("Continue")
               }

               Text("Your username is your public account locator. Sign in with Apple or Google to verify ownership.")
                  .font(.appBody(11, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)

               if normalizedUsername == nil {
                  Label(
                     expectedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Enter your username above to enable sign-in."
                        : "Use 3–30 letters, numbers, periods, or underscores.",
                     systemImage: "info.circle"
                  )
                  .font(.appBodyStrong(11, relativeTo: .caption))
                  .foregroundStyle(AppColor.actionPrimary)
                  .fixedSize(horizontal: false, vertical: true)
               }
            }
            
            if let submittedUsername {
               VStack(alignment: .leading, spacing: 14) {
                  SignInWithAppleButton(.signIn) { request in
                     request.requestedScopes = [.fullName, .email]
                     if let nonce = NonceGenerator.random() {
                        currentAppleNonce = nonce
                        request.nonce = NonceGenerator.sha256(nonce)
                     } else {
                        currentAppleNonce = ""
                     }
                  } onCompletion: { result in
                     handleAppleSignIn(result)
                  }
                  .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                  .frame(maxWidth: 375)
                  .frame(height: 52)
                  .clipShape(.rect(cornerRadius: 18))
                  .disabled(authStore.isAuthenticating)

                  Button {
                     Task {
                        await authStore.signInWithGoogle(
                           intent: authenticationIntent,
                           expectedUsername: submittedUsername
                        )
                     }
                  } label: {
                     HStack(spacing: 12) {
                        if isGoogleAuthenticating {
                           ProgressView()
                              .controlSize(.small)
                              .tint(AppColor.actionPrimary)
                        } else {
                           Image(systemName: "globe")
                              .font(.appDisplay(15, relativeTo: .subheadline))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                           Text(isGoogleAuthenticating ? "Opening Google..." : "Sign In with Google")
                              .font(.appBodyStrong(15, relativeTo: .subheadline))
                           Text("Continue with your Google account.")
                              .font(.appBody(12, relativeTo: .caption))
                              .foregroundStyle(AppColor.textSecondary)
                        }

                        Spacer(minLength: 0)
                     }
                     .foregroundStyle(AppColor.textPrimary)
                     .padding(.horizontal, 14)
                     .padding(.vertical, 12)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .containerShape(.rect(cornerRadius: 18))
                     .background(
                        AppColor.surfaceMuted,
                        in: .rect(corners: .concentric, isUniform: true)
                     )
                  }
                  .buttonStyle(.plain)
                  .disabled(authStore.isAuthenticating)
               }
               .transition(providerChoicesTransition)
            }

            if let lastErrorMessage = authStore.lastErrorMessage, !lastErrorMessage.isEmpty {
               authErrorCard(message: lastErrorMessage)
            }

            Button(action: skipAuthentication) {
               HStack(alignment: .center, spacing: 12) {
                  if isContinuingWithoutAccount {
                     ProgressView()
                        .controlSize(.small)
                        .tint(AppColor.actionPrimary)
                  } else {
                     Image(systemName: "externaldrive")
                        .font(.appDisplay(14, relativeTo: .caption))
                        .foregroundStyle(AppColor.actionPrimary)
                  }

                  VStack(alignment: .leading, spacing: 3) {
                     Text("You can stay on this device.")
                        .font(.appBodyStrong(14, relativeTo: .caption))
                        .foregroundStyle(AppColor.textPrimary)

                     Text("Local toDōs stay on this device. Account toDōs stay private until you sign in again.")
                        .font(.appBody(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.textSecondary)
                  }

                  Spacer(minLength: 8)

                  Image(systemName: "arrow.right.circle.fill")
                     .font(.appDisplay(20, relativeTo: .body))
                     .foregroundStyle(AppColor.actionPrimary)
                     .accessibilityHidden(true)
               }
               .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isContinuingWithoutAccount || authStore.isAuthenticating)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerShape(.rect(cornerRadius: 18))
            .background(
               AppColor.surfaceMuted,
               in: .rect(corners: .concentric, isUniform: true)
            )
         }
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
      .onChange(of: expectedUsername) { _, _ in
         collapseProviderChoicesWhenUsernameChanges()
      }
      .onChange(of: authenticationIntent) { _, _ in
         collapseProviderChoices()
      }
   }

   private var providerChoicesTransition: AnyTransition {
      reduceMotion
         ? .opacity
         : .move(edge: .trailing).combined(with: .opacity)
   }

   private func showProviderChoices() {
      guard let normalizedUsername else {
         isUsernameFocused = true
         return
      }

      isUsernameFocused = false
      withAnimation(reduceMotion ? nil : AppAnimation.snappySection) {
         submittedUsername = normalizedUsername
      }
   }

   private func collapseProviderChoicesWhenUsernameChanges() {
      guard let submittedUsername,
            submittedUsername != normalizedUsername else { return }
      collapseProviderChoices()
   }

   private func collapseProviderChoices() {
      guard submittedUsername != nil else { return }
      withAnimation(reduceMotion ? nil : AppAnimation.snappySection) {
         submittedUsername = nil
      }
   }

   private func skipAuthentication() {
      guard !isContinuingWithoutAccount else { return }
      isContinuingWithoutAccount = true
      Task {
         let didContinue = await authStore.continueWithoutSigningIn()
         isContinuingWithoutAccount = false
         guard didContinue else { return }

         expectedUsername = ""
         submittedUsername = nil
         if let onSkip {
            onSkip()
         } else {
            dismiss()
         }
      }
   }
   
   private func authErrorCard(message: String) -> some View {
      HStack(alignment: .top, spacing: 10) {
         Image(systemName: "exclamationmark.triangle.fill")
            .font(.appDisplay(13, relativeTo: .caption))
            .foregroundStyle(AppColor.actionDestructive)
            .padding(.top, 1)
         
         Text(message)
            .font(.appBody(12, relativeTo: .caption))
            .foregroundStyle(AppColor.actionDestructive)
            .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .containerShape(.rect(cornerRadius: 18))
      .background(
         AppColor.actionDestructive.opacity(0.08),
         in: .rect(corners: .concentric, isUniform: true)
      )
   }
   
   private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
      switch result {
      case .success(let authorization):
         guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let tokenData = credential.identityToken,
               let idToken = String(data: tokenData, encoding: .utf8),
               let submittedUsername
         else {
            authStore.lastErrorMessage = "Sign In with Apple could not finish. Try again."
            return
         }
         guard !currentAppleNonce.isEmpty else {
            authStore.lastErrorMessage = "Sign In with Apple could not prepare securely. Try again."
            return
         }
         
         Task {
            await authStore.signInWithApple(
               idToken: idToken,
               rawNonce: currentAppleNonce,
               fullName: credential.fullName,
               intent: authenticationIntent,
               expectedUsername: submittedUsername
            )
         }
      case .failure(let error):
         if let authorizationError = error as? ASAuthorizationError {
            switch authorizationError.code {
            case .canceled:
               return
            case .notInteractive, .matchedExcludedCredential, .credentialImport, .credentialExport,
                  .preferSignInWithApple, .deviceNotConfiguredForPasskeyCreation:
               authStore.lastErrorMessage = "Sign In with Apple did not finish. Try again when you are ready."
            case .failed, .invalidResponse, .notHandled, .unknown:
               authStore.lastErrorMessage = "Sign In with Apple could not finish. Make sure this device is signed in to your Apple Account, then try again."
            @unknown default:
               authStore.lastErrorMessage = "Sign In with Apple could not finish. Try again in a moment."
            }
         } else {
            authStore.lastErrorMessage = error.localizedDescription
         }
      }
   }
}

struct AccountSetupView: View {
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @State private var username = ""

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         Image(systemName: "person.badge.key.fill")
            .font(.appDisplay(24, relativeTo: .title2))
            .foregroundStyle(AppColor.actionPrimary)

         VStack(alignment: .leading, spacing: 5) {
            Text("Finish your toDō account")
               .font(.appDisplay(22, relativeTo: .title2))
               .foregroundStyle(AppColor.textPrimary)
            Text(description)
               .font(.appBody(13, relativeTo: .body))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
         }

         switch authStore.accountResolution {
         case .authenticating, .resolving:
            HStack(spacing: 10) {
               ProgressView()
               Text("Checking your account…")
                  .font(.appBodyStrong(13, relativeTo: .body))
            }
            .foregroundStyle(AppColor.textSecondary)
         case .migrationRequired(let existingUsername):
            if let existingUsername, !existingUsername.isEmpty {
               migrationConfirmationView(username: existingUsername)
            } else {
               usernameEntryView(intent: .signIn)
            }
         case .accountMismatch(let expected, let actual):
            mismatchView(expected: expected, actual: actual)
         case .needsUsername(let intent):
            usernameEntryView(intent: intent)
         default:
            usernameEntryView(intent: .createAccount)
         }

         if let message = authStore.profileErrorMessage, !message.isEmpty {
            Text(message)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.actionDestructive)
               .fixedSize(horizontal: false, vertical: true)
         }

         Button("Sign Out") {
            Task { await authStore.signOut() }
         }
         .font(.appBodyStrong(13, relativeTo: .body))
         .foregroundStyle(AppColor.textSecondary)
         .disabled(authStore.isAuthenticating)
      }
      .padding(18)
      .frame(maxWidth: 520, alignment: .leading)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      .onAppear {
         if case .migrationRequired(let existingUsername) = authStore.accountResolution {
            username = existingUsername ?? ""
         }
      }
   }

   @ViewBuilder
   private func migrationConfirmationView(username: String) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Label("Your account is @\(username)", systemImage: "checkmark.seal.fill")
            .font(.appBodyStrong(15, relativeTo: .body))
            .foregroundStyle(AppColor.actionSuccess)

         Text("Confirm it once to finish the account update. Your toDōs, purchases, and entitlements stay with this account.")
            .font(.appBody(13, relativeTo: .body))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

         Button {
            Task { _ = await authStore.completeAccountSetup(username: username) }
         } label: {
            Label("Confirm and continue", systemImage: "arrow.up.right")
               .font(.appButton(15, relativeTo: .body))
               .frame(maxWidth: .infinity)
         }
         .buttonStyle(.borderedProminent)
         .tint(AppColor.actionPrimary)
         .disabled(authStore.isLoadingProfile)
      }
   }

   @ViewBuilder
   private func usernameEntryView(intent: ToDoAccountAuthenticationIntent) -> some View {
      VStack(alignment: .leading, spacing: 8) {
         if intent == .signIn {
            Text("This provider account does not have a completed toDō username yet. Choose Create Account to finish setting it up, or sign out and use the provider connected to your existing account.")
               .font(.appBody(13, relativeTo: .body))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
         }

         TextField("Username", text: $username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.appBodyStrong(15, relativeTo: .body))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))

         Button {
            Task { _ = await authStore.completeAccountSetup(username: username) }
         } label: {
            Label(intent == .signIn ? "Create this account" : "Continue", systemImage: "arrow.up.right")
               .font(.appButton(15, relativeTo: .body))
               .frame(maxWidth: .infinity)
         }
         .buttonStyle(.borderedProminent)
         .tint(AppColor.actionPrimary)
         .disabled((try? ToDoProfilePolicy.validatedUsername(username)) == nil || authStore.isLoadingProfile)
      }
   }

   private var description: String {
      switch authStore.accountResolution {
      case .migrationRequired(let existingUsername):
         if let existingUsername, !existingUsername.isEmpty {
            return "Confirm your existing @\(existingUsername) once to finish moving this account to the current account system."
         }
         return "Finish the one-time account update before toDō starts syncing."
      case .accountMismatch:
         return "The provider account is authenticated, but it does not match the username you entered. Nothing has been linked or moved."
      case .needsUsername(let intent) where intent == .signIn:
         return "This provider account is not connected to a completed toDō account yet."
      default:
         return "Choose a unique username for your account. Apple or Google remains the proof that the account belongs to you."
      }
   }

   @ViewBuilder
   private func mismatchView(expected: String, actual: String) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("You entered @\(expected), but this provider account is @\(actual).")
            .font(.appBodyStrong(13, relativeTo: .body))
            .foregroundStyle(AppColor.actionDestructive)
         Button("Continue as @\(actual)") {
            Task { _ = await authStore.continueWithAuthenticatedAccount() }
         }
         .buttonStyle(.borderedProminent)
         .tint(AppColor.actionPrimary)
      }
   }
}

struct ToDoSignInMethodsSection: View {
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @Environment(\.colorScheme) private var colorScheme
   @State private var appleNonce = ""

   var body: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Sign-in Methods")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 12) {
            providerRow(title: "Apple", systemName: "apple.logo") {
               if authStore.isProviderLinked("apple") {
                  connectedLabel
               } else {
                  SignInWithAppleButton(.continue) { request in
                     request.requestedScopes = [.email]
                     guard let nonce = NonceGenerator.random() else {
                        appleNonce = ""
                        return
                     }
                     appleNonce = nonce
                     request.nonce = NonceGenerator.sha256(nonce)
                  } onCompletion: { result in
                     handleAppleLink(result)
                  }
                  .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                  .frame(width: 118, height: 38)
                  .clipShape(.rect(cornerRadius: 12))
               }
            }

            providerRow(title: "Google", systemName: "globe") {
               if authStore.isProviderLinked("google") {
                  connectedLabel
               } else {
                  Button("Connect") {
                     Task { _ = await authStore.linkGoogleIdentity() }
                  }
                  .font(.appButton(14, relativeTo: .subheadline))
                  .buttonStyle(.borderedProminent)
                  .tint(AppColor.actionPrimary)
               }
            }

            if authStore.isAuthenticating {
               ProgressView()
                  .controlSize(.small)
                  .tint(AppColor.actionPrimary)
            }
         }
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
      .task(id: authStore.resolvedAccountID) {
         await authStore.refreshLinkedProviders()
      }
   }

   private var connectedLabel: some View {
      Label("Connected", systemImage: "checkmark.circle.fill")
         .font(.appBodyStrong(13, relativeTo: .caption))
         .foregroundStyle(AppColor.actionSuccess)
   }

   private func providerRow<Content: View>(
      title: String,
      systemName: String,
      @ViewBuilder trailing: () -> Content
   ) -> some View {
      HStack(spacing: 12) {
         Image(systemName: systemName)
            .font(.appDisplay(16, relativeTo: .body))
            .frame(width: 24)
            .foregroundStyle(AppColor.actionPrimary)

         Text(title)
            .font(.appBodyStrong(15, relativeTo: .body))
            .foregroundStyle(AppColor.textPrimary)

         Spacer(minLength: 8)
         trailing()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func handleAppleLink(_ result: Result<ASAuthorization, Error>) {
      switch result {
      case .success(let authorization):
         guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let tokenData = credential.identityToken,
               let idToken = String(data: tokenData, encoding: .utf8),
               !appleNonce.isEmpty else {
            authStore.lastErrorMessage = "Sign In with Apple could not finish. Try again."
            return
         }

         Task {
            _ = await authStore.linkAppleIdentity(idToken: idToken, rawNonce: appleNonce)
            appleNonce = ""
         }
      case .failure(let error):
         let nsError = error as NSError
         guard nsError.domain != ASAuthorizationError.errorDomain ||
               nsError.code != ASAuthorizationError.canceled.rawValue else { return }
         authStore.lastErrorMessage = "Sign In with Apple could not finish. Try again."
      }
   }
}

#Preview {
   AuthenticationView()
      .padding()
      .background(AppColor.surface)
      .environmentObject(SupabaseAuthStore.preview)
}

#Preview("Authentication Screen") {
   AuthenticationScreenView()
      .modelContainer(PreviewSupport.makeModelContainer())
      .environmentObject(SupabaseAuthStore.preview)
}

struct AuthenticationScreenView: View {
   @Environment(\.dismiss) private var dismiss
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @Environment(\.settingsDetailPresentation) private var settingsDetailPresentation
   let title: String
   let onClose: (() -> Void)?
   let onSkip: (() -> Void)?
   
   init(
      title: String = "toDō Sync",
      onClose: (() -> Void)? = nil,
      onSkip: (() -> Void)? = nil
   ) {
      self.title = title
      self.onClose = onClose
      self.onSkip = onSkip
   }
   
   var body: some View {
      Group {
         if authStore.hasResolvedAccount {
            AccountView()
         } else if authStore.isAuthenticated {
            AccountSetupView()
         } else if settingsDetailPresentation == .sidePanel {
            AuthenticationView(onSkip: skipAuthentication)
               .padding(16)
         } else {
            ZStack(alignment: .top) {
               ScrollView {
                  VStack(alignment: .leading, spacing: 24) {
                     AuthenticationView(onSkip: skipAuthentication)
                  }
                  .padding(.horizontal, 16)
                  .padding(.top, 86)
                  .padding(.bottom, 24)
               }
               
               VStack(spacing: 0) {
                  Text(title)
                     .font(.appViewTitle(34, relativeTo: .largeTitle))
                     .foregroundStyle(AppColor.white)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .accessibilityAddTraits(.isHeader)
                     .padding(.horizontal, 16)
                     .padding(.top, 8)
                     .padding(.bottom, 14)
                     .background(AppColor.secondary)
               }
               .frame(maxWidth: .infinity, alignment: .leading)
            }
         }
      }
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .appNavigationChrome()
      .toolbar {
         if let onClose {
            ToolbarItem(placement: .topBarTrailing) {
               Button("Done") {
                  onClose()
               }
            }
         }
      }
   }

   private func skipAuthentication() {
      if let onSkip {
         onSkip()
      } else if let onClose {
         onClose()
      } else {
         dismiss()
      }
   }
}

private enum NonceGenerator {
   static func random(length: Int = 32) -> String? {
      let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
      var result = ""
      var remainingLength = length
      
      while remainingLength > 0 {
         var randoms: [UInt8] = []
         for _ in 0..<16 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
               return nil
            }
            randoms.append(random)
         }
         
         randoms.forEach { random in
            if remainingLength == 0 {
               return
            }
            
            if random < charset.count {
               result.append(charset[Int(random)])
               remainingLength -= 1
            }
         }
      }
      
      return result
   }
   
   static func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      return hashedData.compactMap { String(format: "%02x", $0) }.joined()
   }
}
