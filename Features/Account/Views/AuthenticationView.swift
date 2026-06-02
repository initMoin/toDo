import AuthenticationServices
import CryptoKit
import SwiftUI
import SwiftData

struct AuthenticationView: View {
    @EnvironmentObject private var authStore: SupabaseAuthStore

    @State private var currentAppleNonce = ""
    private var isGoogleAuthenticating: Bool { authStore.isGoogleAuthenticating }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("toDō Sync")
                .font(.appSubtitle(15, relativeTo: .subheadline))
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

                SignInWithAppleButton(.signIn) { request in
                    currentAppleNonce = NonceGenerator.random()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = NonceGenerator.sha256(currentAppleNonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: 375)
                .frame(height: 52)
                .clipShape(.rect(cornerRadius: 18))
                .disabled(authStore.isAuthenticating)

                Button {
                    Task {
                        await authStore.signInWithGoogle()
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

                if let lastErrorMessage = authStore.lastErrorMessage, !lastErrorMessage.isEmpty {
                    authErrorCard(message: lastErrorMessage)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "externaldrive")
                        .font(.appDisplay(14, relativeTo: .caption))
                        .foregroundStyle(AppColor.actionPrimary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("You can stay on this device.")
                            .font(.appBodyStrong(14, relativeTo: .caption))
                            .foregroundStyle(AppColor.textPrimary)

                        Text("No account required. toDō will stay on this device.")
                            .font(.appBody(12, relativeTo: .caption))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
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
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                authStore.lastErrorMessage = "Sign In with Apple could not finish. Try again."
                return
            }

            Task {
                await authStore.signInWithApple(
                    idToken: idToken,
                    rawNonce: currentAppleNonce,
                    fullName: credential.fullName
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
    @EnvironmentObject private var authStore: SupabaseAuthStore
    let title: String
    let onClose: (() -> Void)?

    init(
        title: String = "toDō Sync",
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if authStore.isAuthenticated {
                AccountView()
            } else {
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            AuthenticationView()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 86)
                        .padding(.bottom, 24)
                    }

                    VStack(spacing: 0) {
                        Text(title)
                            .font(.appTitle(34, relativeTo: .largeTitle))
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
}

private enum NonceGenerator {
    static func random(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
                }
                return random
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
