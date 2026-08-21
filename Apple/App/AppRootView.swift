import SwiftUI
import SwiftData
import Combine

struct AppRootView: View {
   fileprivate enum AppDestination: Hashable {
      case toDos
      case settings
      case stats
   }

   private enum AppSheet: Identifiable {
      case toDo(ToDoPresentationService.Route)

      var id: String {
         switch self {
         case .toDo(let route):
            return "todo-\(route.id)"
         }
      }
   }

	   @EnvironmentObject private var toDoPresentationService: ToDoPresentationService
	   @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
	   @EnvironmentObject private var collaborationService: ToDoCollaborationService
	   @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
	   @Environment(\.modelContext) private var modelContext
	   @Environment(\.appReduceMotion) private var reduceMotion
	   @Query private var screenshotToDos: [ToDo]
	   @State private var navigationCoordinator = NavigationCoordinator.shared
	   @State private var navigationPath = NavigationPath()
	   @State private var activeSheet: AppSheet?
	   @State private var pendingToDoRouteResolutionTask: Task<Void, Never>?

	   var body: some View {
	      rootContent
	      .sheet(item: $activeSheet, onDismiss: handleSheetDismissal) { sheet in
	         appSheetContent(for: sheet)
	      }
      .sheet(isPresented: Binding(
         get: { collaborationService.pendingInvitationID != nil },
         set: { isPresented in
            if !isPresented {
               collaborationService.clearPendingInvitation()
            }
         }
      )) {
         if let invitationID = collaborationService.pendingInvitationID {
            CollabInvitationReviewView(invitationID: invitationID) {
               collaborationService.clearPendingInvitation()
            }
         }
      }
      .onReceive(toDoPresentationService.$activeRoute.compactMap { $0 }) { route in
         AppLog.info("AppRoot presenting toDō route: \(route.id)")
         activeSheet = .toDo(route)
      }
      .onChange(of: navigationCoordinator.notificationRoute) { _, route in
         handleNavigationRoute(route)
      }
      .onChange(of: supabaseAuthStore.currentUserID) { oldUserID, newUserID in
         guard oldUserID != newUserID else { return }
         dismissToDoPresentation()
      }
      .onDisappear {
         pendingToDoRouteResolutionTask?.cancel()
      }
	      .accessibilityIdentifier("home.view")
	   }

	   @ViewBuilder
	   private var rootContent: some View {
	      if isRunningForScreenshots, let screen = requestedScreenshotScreen {
	         screenshotRootContent(for: screen)
	      } else {
	         NavigationStack(path: $navigationPath) {
	            HomeView(
	               onCreateToDo: {
	                  toDoPresentationService.create(preselectedTagID: nil)
	               },
	               onShowToDos: { navigate(to: .toDos) },
	               onShowSettings: { navigate(to: .settings) },
	               onShowStats: { navigate(to: .stats) }
	            )
	            .navigationDestination(for: AppDestination.self) { destination in
	               switch destination {
	               case .toDos:
	                  ToDosView(
	                     onCreateToDo: { preselectedTagID in
	                        toDoPresentationService.create(preselectedTagID: preselectedTagID)
	                     },
	                     onViewToDo: { toDo in
	                        toDoPresentationService.view(toDo)
	                     },
	                     onEditToDo: { toDo in
	                        toDoPresentationService.edit(toDo)
	                     }
	                  )
	               case .settings:
	                  SettingsView()
	               case .stats:
	                  StatsView(ownerUserID: visibleOwnerUserID)
	               }
	            }
	         }
	         .transaction { transaction in
	            if reduceMotion {
	               transaction.animation = nil
	               transaction.disablesAnimations = true
	            }
	         }
	      }
	   }

	   @ViewBuilder
	   private func screenshotRootContent(for screen: String) -> some View {
	      switch screen {
	      case "todos", "all":
	         ToDosView(
	            onCreateToDo: { preselectedTagID in
	               toDoPresentationService.create(preselectedTagID: preselectedTagID)
	            },
	            onViewToDo: { toDo in
	               toDoPresentationService.view(toDo)
	            },
	            onEditToDo: { toDo in
	               toDoPresentationService.edit(toDo)
	            }
	         )
	      case "create", "new":
	         ToDoView(
	            mode: .create(preselectedTagID: nil),
	            onFinish: { _ in },
	            onboardingManager: GuidedOnboardingManager.shared
	         )
	      case "todo", "detail", "view":
	         if let toDo = screenshotShowcaseToDo {
	            ToDoView(
	               mode: .view(toDo, context: .sheet),
	               onFinish: { _ in },
	               onEdit: {}
	            )
	         } else {
	            HomeView(onCreateToDo: {})
	         }
	      case "stats":
         StatsView(ownerUserID: supabaseAuthStore.resolvedAccountID)
	      default:
	         HomeView(onCreateToDo: {})
	      }
	   }

	   private var isRunningForScreenshots: Bool {
	      ProcessInfo.processInfo.arguments.contains("-UITestScreenshotMode")
	   }

	   private var requestedScreenshotScreen: String? {
	      let arguments = ProcessInfo.processInfo.arguments
	      guard let index = arguments.firstIndex(of: "-ScreenshotScreen"),
	            arguments.indices.contains(arguments.index(after: index)) else {
	         return nil
	      }
	      return arguments[arguments.index(after: index)]
	   }

	   private var screenshotShowcaseToDo: ToDo? {
	      screenshotToDos.first { $0.task == "Ship toDō 3.0 TestFlight" } ?? screenshotToDos.first
	   }

   @ViewBuilder
   private func appSheetContent(for sheet: AppSheet) -> some View {
      switch sheet {
      case .toDo(let route):
         toDoSheetContent(for: route)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
      }
   }

   @ViewBuilder
   private func toDoSheetContent(for route: ToDoPresentationService.Route) -> some View {
      switch route {
      case .create(_, let preselectedTagID):
         ToDoView(
            mode: .create(preselectedTagID: preselectedTagID),
            onFinish: completeToDoPresentation,
            onboardingManager: GuidedOnboardingManager.shared
         )
      case .view(let toDo):
         ToDoView(
            mode: .view(toDo, context: .sheet),
            onFinish: { _ in
               dismissToDoPresentation()
            },
            onEdit: {
               toDoPresentationService.edit(toDo)
            }
         )
      case .edit(let toDo):
         ToDoView(
            mode: .edit(toDo, context: .sheet),
            onFinish: completeToDoPresentation
         )
      }
   }

   private func completeToDoPresentation(savedToDo: ToDo?) {
      activeSheet = nil
      toDoPresentationService.finish(savedToDo: savedToDo)

      if let savedToDo, GuidedOnboardingManager.shared.isActive {
         GuidedOnboardingManager.shared.recordCreatedToDo(savedToDo)
      }
   }

   private func dismissToDoPresentation() {
      activeSheet = nil
      toDoPresentationService.dismiss()
   }

   private func handleSheetDismissal() {
      guard toDoPresentationService.activeRoute != nil else { return }
      AppLog.info("AppRoot sheet dismissed by user")
      toDoPresentationService.dismiss()
   }

   private func handleNavigationRoute(_ route: NotificationRoute) {
      switch route {
      case .toDo(let localIdentifier, let cloudID):
         openRoutedToDo(localIdentifier: localIdentifier, cloudID: cloudID)
      case .sync:
         navigate(to: .settings)
         navigationCoordinator.notificationRoute = .none
      case .collab, .none:
         break
      }
   }

   private func openRoutedToDo(localIdentifier: String?, cloudID: UUID?) {
      if let toDo = routedToDo(localIdentifier: localIdentifier, cloudID: cloudID) {
         pendingToDoRouteResolutionTask?.cancel()
         pendingToDoRouteResolutionTask = nil
         navigationCoordinator.notificationRoute = .none
         toDoPresentationService.view(toDo)
         return
      }

      pendingToDoRouteResolutionTask?.cancel()
      pendingToDoRouteResolutionTask = Task { @MainActor in
         await SyncCoordinator.shared.refreshFromRemote(userID: supabaseAuthStore.resolvedAccountID)

         for _ in 0..<8 {
            guard !Task.isCancelled else { return }
            if let toDo = routedToDo(localIdentifier: localIdentifier, cloudID: cloudID) {
               navigationCoordinator.notificationRoute = .none
               toDoPresentationService.view(toDo)
               return
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
         }

         navigationCoordinator.notificationRoute = .none
      }
   }

   private func routedToDo(localIdentifier: String?, cloudID: UUID?) -> ToDo? {
      let descriptor = FetchDescriptor<ToDo>()
      guard let toDos = try? modelContext.fetch(descriptor) else { return nil }
      let accessibleCollabIDs = Set(collaborationService.collabs.map(\.id))
      let scopedToDos = toDos.filter {
         $0.ownerUserID == visibleOwnerUserID
            || $0.collabID.map(accessibleCollabIDs.contains) == true
      }

      if let cloudID,
         let toDo = scopedToDos.first(where: { $0.cloudID == cloudID && $0.lifecycleState != .trashed }) {
         return toDo
      }

      if let localIdentifier {
         return scopedToDos.first {
            String(describing: $0.id) == localIdentifier && $0.lifecycleState != .trashed
         }
      }

      return nil
   }

   private var visibleOwnerUserID: UUID? {
      AppPreferences.preferredSyncMode() == .syncEverywhere ? supabaseAuthStore.scopedOwnerUserID : nil
   }

   private func navigate(to destination: AppDestination) {
      // NavigationStack owns the platform transition. Supplying a separate
      // fade transaction here caused the destination and source surfaces to
      // animate together, especially when a detail sheet was already active.
      if reduceMotion {
         var transaction = Transaction()
         transaction.animation = nil
         transaction.disablesAnimations = true
         withTransaction(transaction) {
            navigationPath.append(destination)
         }
      } else {
         navigationPath.append(destination)
      }
   }
}

private struct HomeView: View {
   private enum PreviewFilter: String, CaseIterable, Identifiable {
      case recent
      case dueSoon
      case timeSensitive

      var id: String { rawValue }

      var title: LocalizedStringKey {
         switch self {
         case .dueSoon:
            return "Due soon"
         case .timeSensitive:
            return "Time-sensitive"
         case .recent:
            return "Recent"
         }
      }
   }

   @Query private var toDos: [ToDo]
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var collaborationService: ToDoCollaborationService
   @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.dynamicTypeSize) private var dynamicTypeSize
   @AppStorage("todo.homePreviewFilter") private var previewFilterRawValue = PreviewFilter.recent.rawValue
   @State private var viewportWidth: CGFloat = 0
   @State private var isShowingProfile = false

   let onCreateToDo: () -> Void
   let onShowToDos: () -> Void
   let onShowSettings: () -> Void
   let onShowStats: () -> Void

   init(
      onCreateToDo: @escaping () -> Void,
      onShowToDos: @escaping () -> Void = {},
      onShowSettings: @escaping () -> Void = {},
      onShowStats: @escaping () -> Void = {}
   ) {
      self.onCreateToDo = onCreateToDo
      self.onShowToDos = onShowToDos
      self.onShowSettings = onShowSettings
      self.onShowStats = onShowStats
   }

   var body: some View {
      ZStack {
         AppColor.surface
            .ignoresSafeArea()

         ScrollView {
            VStack(alignment: .leading, spacing: 22) {
               header
               primaryActionCard
               homeToDoPreview
               statsSection
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .center)
         }
      }
      .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { viewportWidth = $0 }
      .fullScreenCover(isPresented: $isShowingProfile, onDismiss: {
         Task { await authStore.refreshProfile() }
      }) {
         MyProfileView()
      }
   }

   private var header: some View {
      HStack(alignment: .top, spacing: 16) {
         VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.dateString(Date.now))
               .font(.appDisplay(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: true, vertical: false)
               // Align the date's visual center with the profile avatar.
               .padding(.top, 12)

            homeBrandWordmark
         }
         Spacer(minLength: 16)

         VStack(spacing: 8) {
            if authStore.isAuthenticated {
               Button {
                  isShowingProfile = true
               } label: {
                  ProfileAvatarView(
                     profile: authStore.profile,
                     email: authStore.signedInEmail,
                     size: 42,
                     localUserID: authStore.currentUserID,
                     localImageRevision: authStore.profileImageRevision
                  )
               }
               .buttonStyle(.plain)
               .accessibilityLabel("Open My Profile")
               .accessibilityHint("Shows your profile and account details.")
            }

            Button(action: onShowSettings) {
               Image(systemName: "gearshape.fill")
                  .font(.appDisplay(18, relativeTo: .headline))
            }
            .buttonStyle(AppCircleActionButtonStyle(intent: .neutral, size: 46, tint: AppColor.main, foreground: AppColor.brandYellowForeground(for: colorScheme)))
            .accessibilityLabel("Settings")
            .accessibilityInputLabels([
               Text("Settings"),
               Text("Open Settings"),
               Text("toDō Settings")
            ])
         }
      }
   }

   private var primaryActionCard: some View {
      let buttonForeground = homeActionForeground

      return VStack(alignment: .leading, spacing: 16) {
         Text("What matters now?")
            .font(.appBodyStrong(25, relativeTo: .title2))
            .fontWeight(.black)
            .foregroundStyle(AppColor.textPrimary)

         if let bannerText = connectivityMonitor.bannerText {
            Text(bannerText)
               .font(.appBodyStrong(13, relativeTo: .footnote))
               .foregroundStyle(.white)
               .frame(maxWidth: .infinity, alignment: .leading)
               .padding(.horizontal, 12)
               .padding(.vertical, 10)
               .background(AppColor.destructive, in: .rect(cornerRadius: 16))
               .accessibilityAddTraits(.isStaticText)
         }

         Group {
            if usesStackedHomeActions {
               VStack(spacing: 10) {
                  newToDoButton(foreground: buttonForeground)
                  seeAllToDosButton(foreground: buttonForeground)
               }
            } else {
               HStack(spacing: 12) {
                  newToDoButton(foreground: buttonForeground)
                  seeAllToDosButton(foreground: buttonForeground)
               }
            }
         }
         .buttonStyle(.plain)
      }
      .padding(22)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 30))
      .shadow(color: AppColor.shadow, radius: 24, x: 0, y: 12)
   }

   private var usesStackedHomeActions: Bool {
      (viewportWidth > 0 && viewportWidth < AppAdaptiveLayout.narrowPhoneUpperBound)
         || dynamicTypeSize.isAccessibilitySize
   }

   private func newToDoButton(foreground: Color) -> some View {
      Button(action: onCreateToDo) {
         HStack(spacing: 0) {
            HomePlusMark(size: 18, thickness: 4)
               .frame(width: 24, height: 24)
            Text("New toDō")
               .font(.appButton(18, relativeTo: .headline))
               .lineLimit(1)
               .minimumScaleFactor(0.78)
               .allowsTightening(true)

               .frame(maxWidth: .infinity)

            Color.clear
               .frame(width: 24, height: 24)
               .accessibilityHidden(true)
         }
         .frame(maxWidth: .infinity, alignment: .center)
         .foregroundStyle(foreground)
         .padding(.horizontal, 16)
         .frame(maxWidth: .infinity, minHeight: 58)
         .background(AppColor.main, in: .rect(cornerRadius: 20))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("home.newToDo")
      .accessibilityLabel("New toDō")
      .accessibilityInputLabels([
         Text("New toDō"),
         Text("Create toDō"),
         Text("Add toDō")
      ])
   }

   private func seeAllToDosButton(foreground: Color) -> some View {
      Button(action: onShowToDos) {
         HStack(spacing: 0) {
            Color.clear
               .frame(width: 24, height: 24)
               .accessibilityHidden(true)
            Text("See all toDōs")
               .font(.appButton(18, relativeTo: .headline))
               .lineLimit(1)
               .minimumScaleFactor(0.68)
               .allowsTightening(true)

               .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
               .font(.system(size: 19, weight: .black, design: .rounded))
               .frame(width: 24, height: 24)
         }
         .frame(maxWidth: .infinity, alignment: .center)
         .foregroundStyle(foreground)
         .padding(.horizontal, 12)
         .frame(maxWidth: .infinity, minHeight: 58)
         .background(AppColor.secondary, in: .rect(cornerRadius: 20))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("home.seeAllToDos")
      .accessibilityLabel("See all toDōs")
      .accessibilityInputLabels([
         Text("See all toDōs"),
         Text("All toDōs"),
         Text("Open toDōs")
      ])
   }

   private var statsSection: some View {
      let buttonForeground = homeActionForeground

      return VStack(alignment: .leading, spacing: 12) {
         HStack(alignment: .center, spacing: 12) {
            Text("Momentum")
               .font(.appDisplay(22, relativeTo: .title3))
               .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)

            Button(action: onShowStats) {
               HStack(spacing: 7) {
                  Text("Stats")
                     .font(.appButton(15, relativeTo: .subheadline))
                  Image(systemName: "chart.bar.xaxis")
                     .font(.appDisplay(13, relativeTo: .caption))
               }
               .foregroundStyle(buttonForeground)
               .padding(.horizontal, 12)
               .padding(.vertical, 8)
               .background(AppColor.actionSuccess, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.stats")
            .accessibilityLabel("Stats")
            .accessibilityInputLabels([
               Text("Stats"),
               Text("Open Stats"),
               Text("Show Stats")
            ])
         }

         LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            HomeMetricCard(title: "Active", value: activeToDos.count, tint: AppColor.secondary, systemName: "bolt.fill")
            HomeMetricCard(title: "Due soon", value: dueSoonCount, tint: AppColor.main, systemName: "clock.fill")
            HomeMetricCard(title: "Overdue", value: overdueCount, tint: AppColor.actionDestructive, systemName: "exclamationmark")
            HomeMetricCard(title: "Time-sensitive", value: timeSensitiveCount, tint: AppColor.actionPrimary, systemName: "flame.fill")
         }

         HomeCompletedSummary(value: doneCount)
      }
   }

   private var homeActionForeground: Color {
      AppColor.brandYellowForeground(for: colorScheme)
   }

   private var homeBrandWordmark: some View {
      HStack(alignment: .center, spacing: 3) {
         Text("toD")
            .font(.appBrand(58, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.textPrimary)

         Text("ō")
            .font(.appBrand(58, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.main)

         ToDoBrandPlusMark(
            font: .appBrand(58, relativeTo: .largeTitle),
            width: 44,
            height: 60
         )
      }
      .accessibilityLabel("toDō+")
   }

   private var homeToDoPreview: some View {
      VStack(alignment: .leading, spacing: 14) {
         HStack(alignment: .center, spacing: 12) {
            Text("Up next")
               .font(.appDisplay(22, relativeTo: .title3))
               .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)
         }

         HStack(spacing: 8) {
            ForEach(PreviewFilter.allCases) { filter in
               Button {
                  withAnimation(AppAnimation.easeStandard) {
                     previewFilterRawValue = filter.rawValue
                  }
               } label: {
                  Text(filter.title)
                     .font(.appBodyStrong(12, relativeTo: .caption))
                     .foregroundStyle(filter == previewFilter ? AppColor.brandYellowForeground(for: colorScheme) : AppColor.textPrimary)
                     .padding(.horizontal, 11)
                     .padding(.vertical, 7)
                     .background(filter == previewFilter ? AppColor.main : AppColor.surfaceMuted, in: Capsule())
               }
               .buttonStyle(.plain)
            }
         }

         if previewToDos.isEmpty {
            Text("Nothing needs the front row right now.")
               .font(.appBody(14, relativeTo: .body))
               .foregroundStyle(AppColor.textSecondary)
               .frame(maxWidth: .infinity, alignment: .leading)
               .padding(16)
               .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 20))
               .transition(.opacity.combined(with: .offset(y: 8)))
         } else if previewToDos.count > 3 {
            homePreviewScroller
         } else {
            homePreviewRows
         }
      }
      .animation(AppAnimation.easeStandard, value: previewFilterRawValue)
      .animation(AppAnimation.easeStandard, value: previewToDos.map(\.id))
   }

   @ViewBuilder
   private var homePreviewScroller: some View {
      if runsOnMac {
         ScrollView(.vertical) {
            homePreviewRows
         }
         .scrollIndicators(.visible)
         .scrollBounceBehavior(.basedOnSize)
         .frame(height: 214)
         .accessibilityLabel("Up next toDōs")
      } else {
         ScrollView(.vertical) {
            homePreviewRows
               .scrollTargetLayout()
         }
         .scrollIndicators(.hidden)
         .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
         .frame(height: 214)
         .accessibilityLabel("Up next toDōs")
      }
   }

   private var homePreviewRows: some View {
      LazyVStack(spacing: 10) {
         ForEach(previewToDos) { toDo in
            HomeToDoPreviewRow(toDo: toDo)
               .transition(.opacity.combined(with: .offset(y: 10)))
         }
      }
   }

   private var runsOnMac: Bool {
      #if targetEnvironment(macCatalyst)
      return true
      #else
      return ProcessInfo.processInfo.isiOSAppOnMac
      #endif
   }

   private var activeToDos: [ToDo] {
      visibleToDos.filter { $0.lifecycleState == .active }
   }

   private var doneCount: Int {
      visibleToDos.filter { $0.lifecycleState == .done }.count
   }

   private var visibleToDos: [ToDo] {
      let ownerUserID = authStore.effectiveSyncMode == .syncEverywhere
         ? authStore.scopedOwnerUserID
         : nil
      let accessibleCollabIDs = Set(collaborationService.collabs.map(\.id))
      let scoped = toDos.filter {
         $0.ownerUserID == ownerUserID
            || $0.collabID.map(accessibleCollabIDs.contains) == true
      }
      return ToDo.canonicalToDos(from: scoped)
   }

   private var dueSoonCount: Int {
      ToDo.dueSoon(from: activeToDos).count
   }

   private var overdueCount: Int {
      let now = Date()
      return activeToDos.filter {
         guard let dueDate = $0.dueDate else { return false }
         return dueDate < now
      }.count
   }

   private var timeSensitiveCount: Int {
      activeToDos.filter { $0.reminderIntent == .timeSensitive }.count
   }

   private var previewFilter: PreviewFilter {
      PreviewFilter(rawValue: previewFilterRawValue) ?? .dueSoon
   }

   private var previewToDos: [ToDo] {
      switch previewFilter {
      case .dueSoon:
         return ToDo.dueSoon(from: activeToDos)
      case .timeSensitive:
         return ToDo.timeSensitive(from: activeToDos)
      case .recent:
         return ToDo.recent(from: activeToDos)
      }
   }

}

private struct HomePlusMark: View {
   let size: CGFloat
   let thickness: CGFloat

   var body: some View {
      ZStack {
         RoundedRectangle(cornerRadius: thickness / 2, style: .continuous)
            .frame(width: size, height: thickness)
         RoundedRectangle(cornerRadius: thickness / 2, style: .continuous)
            .frame(width: thickness, height: size)
      }
   }
}

private struct HomeMetricCard: View {
   @Environment(\.appDifferentiatesWithoutColor) private var differentiatesWithoutColor

   let title: LocalizedStringKey
   let value: Int
   let tint: Color
   let systemName: String

   var body: some View {
      VStack(alignment: .leading, spacing: 9) {
         HStack(alignment: .center, spacing: 9) {
            Image(systemName: systemName)
               .font(.appDisplay(14, relativeTo: .subheadline))
               .foregroundStyle(tint)
               .frame(width: 28, height: 28)
               .background(tint.opacity(0.14), in: Circle())

            Text(AppLocalization.numberString(value))
               .font(.appDisplay(24, relativeTo: .title3))
               .foregroundStyle(AppColor.textPrimary)
         }

         Text(title)
            .font(.appBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 18))
      .overlay {
         if differentiatesWithoutColor {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
               .strokeBorder(
                  AppColor.textPrimary.opacity(0.72),
                  style: StrokeStyle(lineWidth: 2, dash: [5, 4])
               )
         }
      }
   }
}

private struct HomeCompletedSummary: View {
   @Environment(\.appDifferentiatesWithoutColor) private var differentiatesWithoutColor

   let value: Int

   var body: some View {
      HStack(alignment: .center, spacing: 12) {
         Image(systemName: "checkmark")
            .font(.appDisplay(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.actionSuccess)
            .frame(width: 30, height: 30)
            .background(AppColor.actionSuccess.opacity(0.14), in: Circle())

         Text("Completed")
            .font(.appBodyStrong(14, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textPrimary)

         Spacer(minLength: 12)

         Text(AppLocalization.numberString(value))
            .font(.appDisplay(20, relativeTo: .title3))
            .foregroundStyle(AppColor.textPrimary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .background(AppColor.surfaceElevated.opacity(0.72), in: .rect(cornerRadius: 18))
      .overlay {
         if differentiatesWithoutColor {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
               .strokeBorder(AppColor.textPrimary.opacity(0.72), lineWidth: 2)
         }
      }
   }
}

private struct HomeToDoPreviewRow: View {
   @Environment(\.appDifferentiatesWithoutColor) private var differentiatesWithoutColor

   let toDo: ToDo

   var body: some View {
      HStack(alignment: .center, spacing: 12) {
         VStack(alignment: .leading, spacing: 4) {
            Text(toDo.task)
               .font(.appUserEntry(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)
               .lineLimit(2)

            if let dueDate = toDo.dueDate {
               Text(AppLocalization.dateTimeString(dueDate))
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            } else {
               Text(toDo.reminderIntent.title)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
         }

         Spacer(minLength: 12)

         if toDo.reminderIntent == .timeSensitive {
            if differentiatesWithoutColor {
               Label("Time-sensitive", systemImage: "flame.fill")
                  .font(.appBodyStrong(11, relativeTo: .caption2))
                  .foregroundStyle(AppColor.textPrimary)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 5)
                  .background(AppColor.surfaceMuted, in: Capsule())
            } else {
               Image(systemName: "flame.fill")
                  .font(.appDisplay(13, relativeTo: .caption))
                  .foregroundStyle(AppColor.actionDestructive)
                  .frame(width: 28, height: 28)
                  .background(AppColor.actionDestructive.opacity(0.12), in: Circle())
            }
         }
      }
      .padding(.horizontal, 15)
      .padding(.vertical, 13)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 20))
   }
}
