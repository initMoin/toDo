import Combine
import Foundation
import StoreKit

struct ToDoCommerceAccount: Equatable, Sendable {
   let id: UUID
   let accessToken: String
}

struct ToDoAccountEntitlement: Codable, Equatable, Sendable {
   enum EntitlementKey: String, Codable, Sendable {
      case plus = "todo_plus"
      case foundingSupporter = "founding_supporter"
      case legacy31 = "legacy_3_1"
   }
   
   enum Status: String, Codable, Sendable {
      case active
      case grace
      case expired
      case revoked
   }
   
   enum AccessMode: String, Codable, Sendable {
      case full
      case readOnly = "read_only"
   }
   
   let accountID: UUID
   let entitlementKey: EntitlementKey
   let status: Status
   let accessMode: AccessMode
   let ownershipType: String?
   let expiresAt: String?
   let webReadOnlyUntil: String?
   let sourceKind: String
   let sourceProductID: String?
   let updatedAt: String
   
   private enum CodingKeys: String, CodingKey {
      case accountID = "account_id"
      case entitlementKey = "entitlement_key"
      case status
      case accessMode = "access_mode"
      case ownershipType = "ownership_type"
      case expiresAt = "expires_at"
      case webReadOnlyUntil = "web_read_only_until"
      case sourceKind = "source_kind"
      case sourceProductID = "source_product_id"
      case updatedAt = "updated_at"
   }
}

struct ToDoEntitlementSnapshot: Codable, Equatable, Sendable {
   static let empty = ToDoEntitlementSnapshot(records: [])
   
   let records: [ToDoAccountEntitlement]
   
   var hasFullPlus: Bool {
      records.contains {
         [.plus, .legacy31].contains($0.entitlementKey) &&
         [.active, .grace].contains($0.status) &&
         $0.accessMode == .full
      }
   }
   
   var hasReadOnlyWebAccess: Bool {
      records.contains {
         [.plus, .legacy31].contains($0.entitlementKey) &&
         [.expired, .revoked].contains($0.status) &&
         $0.accessMode == .readOnly
      }
   }
   
   var isFoundingSupporter: Bool {
      records.contains {
         [.foundingSupporter, .legacy31].contains($0.entitlementKey) &&
         [.active, .grace].contains($0.status) &&
         $0.accessMode == .full
      }
   }
   
   var isInGracePeriod: Bool {
      records.contains {
         [.plus, .legacy31].contains($0.entitlementKey) && $0.status == .grace && $0.accessMode == .full
      }
   }
   
   var hasLifetimePlus: Bool {
      records.contains {
         $0.entitlementKey == .plus &&
         [.active, .grace].contains($0.status) &&
         $0.accessMode == .full &&
         $0.sourceProductID == ToDoProductCatalog.ProductID.plusLifetime.rawValue
      }
   }
   
   var isGrandfatheredFor31: Bool {
      records.contains {
         $0.entitlementKey == .legacy31 &&
         [.active, .grace].contains($0.status) &&
         $0.accessMode == .full &&
         $0.sourceKind == "grandfathering"
      }
   }
}

/// Display-only membership state restored before the server check completes.
/// It never participates in capability or purchase authorization decisions.
struct ToDoMembershipDisplayState: Codable, Equatable, Sendable {
   static let free = ToDoMembershipDisplayState(
      hasPlus: false,
      isFoundingSupporter: false,
      isPioneer: false,
      hasLifetimePlus: false,
      isInGracePeriod: false,
      hasReadOnlyWebAccess: false
   )

   let hasPlus: Bool
   let isFoundingSupporter: Bool
   let isPioneer: Bool
   let hasLifetimePlus: Bool
   let isInGracePeriod: Bool
   let hasReadOnlyWebAccess: Bool

   init(snapshot: ToDoEntitlementSnapshot) {
      hasPlus = snapshot.hasFullPlus
      isFoundingSupporter = snapshot.isFoundingSupporter
      isPioneer = snapshot.isGrandfatheredFor31
      hasLifetimePlus = snapshot.hasLifetimePlus
      isInGracePeriod = snapshot.isInGracePeriod
      hasReadOnlyWebAccess = snapshot.hasReadOnlyWebAccess
   }

   private init(
      hasPlus: Bool,
      isFoundingSupporter: Bool,
      isPioneer: Bool,
      hasLifetimePlus: Bool,
      isInGracePeriod: Bool,
      hasReadOnlyWebAccess: Bool
   ) {
      self.hasPlus = hasPlus
      self.isFoundingSupporter = isFoundingSupporter
      self.isPioneer = isPioneer
      self.hasLifetimePlus = hasLifetimePlus
      self.isInGracePeriod = isInGracePeriod
      self.hasReadOnlyWebAccess = hasReadOnlyWebAccess
   }
}

@MainActor
protocol ToDoEntitlementBackendClient {
   func link(signedTransactionInfo: String, account: ToDoCommerceAccount) async throws
   func loadEntitlements(account: ToDoCommerceAccount) async throws -> [ToDoAccountEntitlement]
}

struct LiveToDoEntitlementBackendClient: ToDoEntitlementBackendClient {
   private struct LinkBody: Encodable {
      let signedTransactionInfo: String
   }
   
   private struct ErrorBody: Decodable {
      let error: String?
   }
   
   func link(signedTransactionInfo: String, account: ToDoCommerceAccount) async throws {
      let url = SupabaseConfig.supabaseURL
         .appending(path: "functions/v1/apple-iap-link")
      var request = authorizedRequest(url: url, account: account)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(LinkBody(signedTransactionInfo: signedTransactionInfo))
      
      let (data, response) = try await URLSession.shared.data(for: request)
      try validate(response: response, data: data)
   }
   
   func loadEntitlements(account: ToDoCommerceAccount) async throws -> [ToDoAccountEntitlement] {
      let baseURL = SupabaseConfig.supabaseURL
         .appending(path: "rest/v1/current_account_entitlements")
      var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
      components?.queryItems = [
         URLQueryItem(
            name: "select",
            value: "account_id,entitlement_key,status,access_mode,ownership_type,expires_at,web_read_only_until,source_kind,source_product_id,updated_at"
         ),
         URLQueryItem(name: "order", value: "updated_at.desc"),
      ]
      guard let url = components?.url else {
         throw URLError(.badURL)
      }
      
      let (data, response) = try await URLSession.shared.data(
         for: authorizedRequest(url: url, account: account)
      )
      try validate(response: response, data: data)
      return try JSONDecoder().decode([ToDoAccountEntitlement].self, from: data)
   }
   
   private func authorizedRequest(url: URL, account: ToDoCommerceAccount) -> URLRequest {
      var request = URLRequest(url: url)
      request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
      return request
   }
   
   private func validate(response: URLResponse, data: Data) throws {
      guard let httpResponse = response as? HTTPURLResponse else {
         throw URLError(.badServerResponse)
      }
      guard (200..<300).contains(httpResponse.statusCode) else {
         let serverMessage = (try? JSONDecoder().decode(ErrorBody.self, from: data).error)
         ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
         throw ToDoCommerceBackendError.requestFailed(statusCode: httpResponse.statusCode, message: serverMessage)
      }
   }
}

enum ToDoCommerceBackendError: LocalizedError, Equatable {
   case requestFailed(statusCode: Int, message: String)
   
   var errorDescription: String? {
      switch self {
      case .requestFailed(_, let message):
         return message
      }
   }
}

@MainActor
final class ToDoPurchaseManager: ObservableObject {
   static let shared = ToDoPurchaseManager()
   static let preview = ToDoPurchaseManager(loadsStoreProducts: false)
   
   @Published private(set) var products: [String: Product] = [:]
   @Published private(set) var missingProductIDs: Set<String> = []
   @Published private(set) var introductoryOfferEligibleProductIDs: Set<String> = []
   @Published private(set) var activeProductIDs: Set<String> = []
   @Published private(set) var accountEntitlements: [ToDoAccountEntitlement] = []
   @Published private(set) var displayMembershipState = ToDoMembershipDisplayState.free
   @Published private(set) var isLoading = false
   @Published private(set) var isLoadingAccountEntitlements = false
   @Published private(set) var activePurchaseProductID: String?
   @Published private(set) var accountID: UUID?
   @Published var statusMessage: String?
   @Published var errorMessage: String?
   
   private let loadsStoreProducts: Bool
   private let backendClient: any ToDoEntitlementBackendClient
   private var account: ToDoCommerceAccount?
   private var updatesTask: Task<Void, Never>?
   private var hasStarted = false
   private var accountRevision = 0

   private static let cachedDisplayStateKeyPrefix = "todo.commerce.membership-display."
   
   init(
      loadsStoreProducts: Bool = true,
      backendClient: any ToDoEntitlementBackendClient = LiveToDoEntitlementBackendClient()
   ) {
      self.loadsStoreProducts = loadsStoreProducts
      self.backendClient = backendClient
   }
   
   deinit {
      updatesTask?.cancel()
   }
   
   private var localHasPlus: Bool {
      !activeProductIDs.isDisjoint(with: ToDoProductCatalog.plusProductIDs)
   }
   
   private var serverSnapshot: ToDoEntitlementSnapshot {
      ToDoEntitlementSnapshot(records: accountEntitlements)
   }
   
   var hasPlus: Bool {
      account == nil ? localHasPlus : serverSnapshot.hasFullPlus
   }

   /// Legacy users receive every paid capability, including paid capabilities
   /// introduced after this release. Keep this separate from `hasPlus`, which
   /// describes the current toDō+ surface used by existing UI.
   var includesFuturePaidFeatures: Bool {
      account != nil && serverSnapshot.isGrandfatheredFor31
   }
   
   var hasWebReadOnlyAccess: Bool {
      account != nil && serverSnapshot.hasReadOnlyWebAccess
   }
   
   var isFoundingSupporter: Bool {
      if account != nil {
         return serverSnapshot.isFoundingSupporter
      }
      return activeProductIDs.contains(ToDoProductCatalog.ProductID.appreciationFounding.rawValue)
   }
   
   var isGrandfatheredFor31: Bool {
      account != nil && serverSnapshot.isGrandfatheredFor31
   }

   /// These values may come from a per-account display cache while the server
   /// check is in flight. They are intentionally separate from the capability
   /// properties above, which remain server-authoritative for signed-in users.
   var displayedHasPlus: Bool {
      account == nil ? localHasPlus : displayMembershipState.hasPlus
   }

   var displayedIsFoundingSupporter: Bool {
      if account == nil {
         return activeProductIDs.contains(ToDoProductCatalog.ProductID.appreciationFounding.rawValue)
      }
      return displayMembershipState.isFoundingSupporter
   }

   var displayedIsPioneer: Bool {
      account != nil && displayMembershipState.isPioneer
   }

   var displayedMembershipLabel: String {
      guard account != nil else { return membershipLabel }
      if displayMembershipState.isPioneer { return String(localized: "toDō Pioneer") }
      if displayMembershipState.isFoundingSupporter { return String(localized: "Founding Supporter") }
      if displayMembershipState.hasLifetimePlus { return String(localized: "Lifetime") }
      if displayMembershipState.isInGracePeriod { return String(localized: "Grace Period") }
      if displayMembershipState.hasPlus { return String(localized: "Active") }
      if displayMembershipState.hasReadOnlyWebAccess { return String(localized: "Limited Access") }
      return String(localized: "Free")
   }

   /// Presentation-only purchase visibility. These values may use the matching
   /// account cache while a fresh server entitlement check is in flight.
   /// Purchase authorization still uses the live properties below.
   var displayedShouldShowPlusPurchaseOptions: Bool {
      !displayedHasPlus && !displayedIsPioneer
   }

   var displayedShouldShowFoundingSupporterPurchase: Bool {
      !displayedIsFoundingSupporter && !displayedIsPioneer
   }

   /// StoreKit merchandising should not offer a capability the account already
   /// owns. Recognition is separate from Plus, but Pioneer accounts already
   /// include the same recognition and all future paid benefits.
   var shouldShowPlusPurchaseOptions: Bool {
      !hasPlus && !includesFuturePaidFeatures
   }

   var shouldShowFoundingSupporterPurchase: Bool {
      !isFoundingSupporter && !isGrandfatheredFor31
   }
   
   var capabilities: ToDoCapabilities {
      if includesFuturePaidFeatures { return .legacy }
      return hasPlus ? .plus : .free
   }
   
   /// This is merchandising state only. Entitlements and offer application remain
   /// StoreKit/server-authoritative and never depend on this value.
   func isEligibleForIntroductoryOffer(_ productID: ToDoProductCatalog.ProductID) -> Bool {
      introductoryOfferEligibleProductIDs.contains(productID.rawValue)
   }
   
   var membershipLabel: String {
      if account != nil {
         if serverSnapshot.isGrandfatheredFor31 { return String(localized: "toDō Pioneer") }
         if serverSnapshot.hasLifetimePlus { return String(localized: "Lifetime") }
         if serverSnapshot.isInGracePeriod { return String(localized: "Grace Period") }
         if serverSnapshot.hasFullPlus { return String(localized: "Active") }
         if serverSnapshot.hasReadOnlyWebAccess { return String(localized: "Limited Access") }
         return String(localized: "Free")
      }
      
      if activeProductIDs.contains(ToDoProductCatalog.ProductID.plusLifetime.rawValue) {
         return String(localized: "Lifetime")
      }
      return localHasPlus ? String(localized: "Active") : String(localized: "Free")
   }
   
   func start(account: ToDoCommerceAccount?) async {
      if !hasStarted {
         hasStarted = true
         observeTransactions()
      }
      
      await updateAccount(account)

      if loadsStoreProducts {
         await loadProducts()
      }
   }
   
   func updateAccount(_ account: ToDoCommerceAccount?) async {
      accountRevision += 1
      let revision = accountRevision
      self.account = account
      accountID = account?.id
      // Account-backed capabilities must never survive sign-out or an account switch.
      accountEntitlements = []
      displayMembershipState = .free
      errorMessage = nil
      if let account {
         restoreCachedDisplayState(for: account, revision: revision)
      }
      await refreshEntitlements(revision: revision, linksCurrentTransactions: account != nil)
   }
   
   func loadProducts() async {
      guard !isLoading else { return }
      isLoading = true
      defer { isLoading = false }
      
      do {
         let loadedProducts = try await Product.products(for: ToDoProductCatalog.allProductIDs)
         var loadedByID = Dictionary(uniqueKeysWithValues: loadedProducts.map { ($0.id, $0) })
         
         // StoreKit can return a partial catalog without throwing. Retry omitted
         // identifiers independently so one stale product does not remain hidden.
         let initiallyMissing = ToDoProductCatalog.allProductIDs.subtracting(loadedByID.keys)
         for productID in initiallyMissing.sorted() {
            do {
               let retriedProducts = try await Product.products(for: [productID])
               for product in retriedProducts {
                  loadedByID[product.id] = product
               }
            } catch {
               AppLog.error("StoreKit product retry failed for \(productID): \(error)", logger: AppLog.app)
            }
         }
         
         products = loadedByID
         missingProductIDs = ToDoProductCatalog.allProductIDs.subtracting(loadedByID.keys)
         introductoryOfferEligibleProductIDs = await introductoryOfferEligibility(for: loadedByID)
         errorMessage = nil
         
         if !missingProductIDs.isEmpty {
            AppLog.error(
               "StoreKit omitted configured product IDs: \(missingProductIDs.sorted().joined(separator: ", "))",
               logger: AppLog.app
            )
         }
      } catch {
         introductoryOfferEligibleProductIDs = []
         missingProductIDs = ToDoProductCatalog.allProductIDs
         errorMessage = String(localized: "Purchases are temporarily unavailable. Please try again.")
         AppLog.error("StoreKit product loading failed: \(error)", logger: AppLog.app)
      }
   }
   
   private func introductoryOfferEligibility(for products: [String: Product]) async -> Set<String> {
      var eligibleProductIDs: Set<String> = []
      
      for productID in [ToDoProductCatalog.ProductID.plusMonthly, .plusYearly] {
         guard let subscription = products[productID.rawValue]?.subscription,
               subscription.introductoryOffer != nil,
               await subscription.isEligibleForIntroOffer else {
            continue
         }
         eligibleProductIDs.insert(productID.rawValue)
      }
      
      return eligibleProductIDs
   }
   
   func purchase(productID: String) async {
      guard let product = products[productID] else {
         errorMessage = String(localized: "This purchase is not available in the current storefront.")
         return
      }
      
      activePurchaseProductID = productID
      errorMessage = nil
      statusMessage = nil
      defer { activePurchaseProductID = nil }
      
      do {
         let result: Product.PurchaseResult
         if let accountID {
            result = try await product.purchase(options: [.appAccountToken(accountID)])
         } else {
            result = try await product.purchase()
         }
         
         switch result {
         case .success(let verification):
            let transaction = try verified(verification)
            let linked = await connectVerifiedTransaction(verification.jwsRepresentation)
            await transaction.finish()
            await refreshEntitlements(
               revision: accountRevision,
               linksCurrentTransactions: !linked
            )
            if account != nil && !linked && ToDoProductCatalog.restorableProductIDs.contains(productID) {
               statusMessage = String(localized: "Purchase complete. Account access will retry automatically.")
            } else {
               statusMessage = purchaseConfirmation(for: productID)
            }
         case .pending:
            statusMessage = String(localized: "This purchase is awaiting approval.")
         case .userCancelled:
            break
         @unknown default:
            errorMessage = String(localized: "The App Store returned an unknown purchase result.")
         }
      } catch {
         errorMessage = String(localized: "The purchase could not be completed. Please try again.")
         AppLog.error("StoreKit purchase failed for \(productID): \(error)", logger: AppLog.app)
      }
   }
   
   func restorePurchases() async {
      isLoading = true
      errorMessage = nil
      statusMessage = nil
      defer { isLoading = false }
      
      do {
         try await AppStore.sync()
         await refreshEntitlements(revision: accountRevision, linksCurrentTransactions: account != nil)
         statusMessage = activeProductIDs.isEmpty
         ? String(localized: "No restorable purchases were found.")
         : String(localized: "Your purchases have been restored.")
      } catch {
         errorMessage = String(localized: "Purchases could not be restored. Please try again.")
         AppLog.error("StoreKit restore failed: \(error)", logger: AppLog.app)
      }
   }
   
   func refreshAfterOfferCodeRedemption() async {
      isLoading = true
      errorMessage = nil
      statusMessage = nil
      defer { isLoading = false }
      
      do {
         try await AppStore.sync()
         await refreshEntitlements(revision: accountRevision, linksCurrentTransactions: account != nil)
         statusMessage = String(localized: "Offer code checked. Membership status refreshed.")
      } catch {
         errorMessage = String(localized: "The offer code could not be checked. Please try again.")
         AppLog.error("StoreKit offer-code refresh failed: \(error)", logger: AppLog.app)
      }
   }
   
   func refreshEntitlements() async {
      await refreshEntitlements(revision: accountRevision, linksCurrentTransactions: account != nil)
   }
   
   @discardableResult
   func connectVerifiedTransaction(_ signedTransactionInfo: String) async -> Bool {
      let revision = accountRevision
      let linked = await link(
         signedTransactionInfo: signedTransactionInfo,
         account: account,
         revision: revision
      )
      if linked, let account {
         await loadServerEntitlements(account: account, revision: revision)
      }
      return linked
   }
   
   private func refreshEntitlements(revision: Int, linksCurrentTransactions: Bool) async {
      var refreshedProductIDs: Set<String> = []
      var signedTransactions: [String] = []
      
      for await result in Transaction.currentEntitlements {
         do {
            let transaction = try verified(result)
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
               continue
            }
            guard ToDoProductCatalog.restorableProductIDs.contains(transaction.productID) else {
               continue
            }
            refreshedProductIDs.insert(transaction.productID)
            signedTransactions.append(result.jwsRepresentation)
         } catch {
            AppLog.error("Ignored an unverified StoreKit entitlement: \(error)", logger: AppLog.app)
         }
      }
      
      guard revision == accountRevision else { return }
      activeProductIDs = refreshedProductIDs
      
      guard let account else {
         accountEntitlements = []
         return
      }
      
      if linksCurrentTransactions {
         for signedTransaction in signedTransactions {
            guard revision == accountRevision else { return }
            _ = await link(
               signedTransactionInfo: signedTransaction,
               account: account,
               revision: revision
            )
         }
      }
      
      await loadServerEntitlements(account: account, revision: revision)
   }
   
   private func loadServerEntitlements(account: ToDoCommerceAccount, revision: Int) async {
      isLoadingAccountEntitlements = true
      defer {
         if revision == accountRevision {
            isLoadingAccountEntitlements = false
         }
      }
      
      do {
         let loadedEntitlements = try await backendClient.loadEntitlements(account: account)
         guard revision == accountRevision, self.account?.id == account.id else { return }
         let filteredEntitlements = loadedEntitlements.filter { $0.accountID == account.id }
         accountEntitlements = filteredEntitlements
         let snapshot = ToDoEntitlementSnapshot(records: filteredEntitlements)
         displayMembershipState = ToDoMembershipDisplayState(snapshot: snapshot)
         cacheDisplayState(displayMembershipState, for: account)
      } catch {
         guard revision == accountRevision else { return }
         errorMessage = String(localized: "Your App Store access could not be checked. Pull to refresh or try again shortly.")
         AppLog.error("Server entitlement loading failed: \(error)", logger: AppLog.app)
      }
   }

   private func cachedDisplayStateKey(for account: ToDoCommerceAccount) -> String {
      Self.cachedDisplayStateKeyPrefix + account.id.uuidString.lowercased()
   }

   private func restoreCachedDisplayState(for account: ToDoCommerceAccount, revision: Int) {
      guard revision == accountRevision,
            let data = UserDefaults.standard.data(forKey: cachedDisplayStateKey(for: account)),
            let state = try? JSONDecoder().decode(ToDoMembershipDisplayState.self, from: data)
      else { return }

      displayMembershipState = state
   }

   private func cacheDisplayState(_ state: ToDoMembershipDisplayState, for account: ToDoCommerceAccount) {
      guard let data = try? JSONEncoder().encode(state) else { return }
      UserDefaults.standard.set(data, forKey: cachedDisplayStateKey(for: account))
   }
   
   private func link(
      signedTransactionInfo: String,
      account: ToDoCommerceAccount?,
      revision: Int
   ) async -> Bool {
      guard let account else { return false }
      
      do {
         try await backendClient.link(signedTransactionInfo: signedTransactionInfo, account: account)
         return revision == accountRevision && self.account?.id == account.id
      } catch {
         guard revision == accountRevision else { return false }
         if let backendError = error as? ToDoCommerceBackendError,
            case .requestFailed(let statusCode, _) = backendError,
            statusCode == 409 {
            errorMessage = String(localized: "This App Store purchase is linked to another toDō account.")
         } else {
            errorMessage = String(localized: "Your purchase is safe, but toDō could not connect it to this account yet.")
         }
         AppLog.error("Apple purchase account linking failed: \(error)", logger: AppLog.app)
         return false
      }
   }
   
   private func observeTransactions() {
      updatesTask = Task { [weak self] in
         for await result in Transaction.updates {
            guard let self else { return }
            do {
               let transaction = try self.verified(result)
               _ = await self.connectVerifiedTransaction(result.jwsRepresentation)
               await transaction.finish()
               await self.refreshEntitlements()
            } catch {
               AppLog.error("Ignored an unverified StoreKit update: \(error)", logger: AppLog.app)
            }
         }
      }
   }
   
   private func verified<T>(_ result: VerificationResult<T>) throws -> T {
      switch result {
      case .verified(let value):
         return value
      case .unverified(_, let error):
         throw error
      }
   }
   
   private func purchaseConfirmation(for productID: String) -> String {
      guard let catalogID = ToDoProductCatalog.ProductID(rawValue: productID) else {
         return String(localized: "Purchase complete.")
      }
      
      switch catalogID {
      case .plusMonthly, .plusYearly, .plusLifetime:
         return String(localized: "toDō+ is ready.")
      case .appreciationFounding:
         return String(localized: "Thank you for becoming a Founding Supporter.")
      case .appreciationCoffee, .appreciationLunch, .appreciationPatron:
         return String(localized: "Thank you for supporting toDō.")
      }
   }
}
