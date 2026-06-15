import SwiftUI
import SwiftData
import Combine

struct AppRootView: View {
   fileprivate enum AppDestination: Hashable {
      case settings
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
	   @Environment(\.modelContext) private var modelContext
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
      .onReceive(toDoPresentationService.$activeRoute.compactMap { $0 }) { route in
         AppLog.info("AppRoot presenting toDō route: \(route.id)")
         activeSheet = .toDo(route)
      }
      .onChange(of: navigationCoordinator.notificationRoute) { _, route in
         handleNavigationRoute(route)
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
	               }
	            )
	            .navigationDestination(for: AppDestination.self) { destination in
	               switch destination {
	               case .settings:
	                  SettingsView()
	               }
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
	         StatsView(ownerUserID: supabaseAuthStore.currentUserID)
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
         navigationPath.append(AppDestination.settings)
         navigationCoordinator.notificationRoute = .none
      case .circle, .none:
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
         await SyncCoordinator.shared.refreshFromRemote(userID: supabaseAuthStore.currentUserID)

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

      if let cloudID,
         let toDo = toDos.first(where: { $0.cloudID == cloudID && $0.lifecycleState != .trashed }) {
         return toDo
      }

      if let localIdentifier {
         return toDos.first {
            String(describing: $0.id) == localIdentifier && $0.lifecycleState != .trashed
         }
      }

      return nil
   }
}

private struct HomeView: View {
   private enum PreviewFilter: String, CaseIterable, Identifiable {
      case dueSoon
      case timeSensitive
      case recent

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
   @Environment(\.colorScheme) private var colorScheme
   @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
   @EnvironmentObject private var toDoPresentationService: ToDoPresentationService
   @AppStorage("todo.homePreviewFilter") private var previewFilterRawValue = PreviewFilter.dueSoon.rawValue

   let onCreateToDo: () -> Void
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
   }

   private var header: some View {
      HStack(alignment: .center, spacing: 16) {
         VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalization.dateString(Date.now))
               .font(.appDisplay(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)

            Text("toDō")
               .font(.appBrand(58, relativeTo: .largeTitle))
               .foregroundStyle(AppColor.textPrimary)
         }

         Spacer(minLength: 16)

         NavigationLink(value: AppRootView.AppDestination.settings) {
            Image(systemName: "gearshape.fill")
               .font(.appDisplay(18, relativeTo: .headline))
         }
         .buttonStyle(AppCircleActionButtonStyle(intent: .neutral, size: 46, tint: AppColor.main, foreground: AppColor.brandYellowForeground(for: colorScheme)))
         .accessibilityLabel("Settings")
      }
   }

   private var primaryActionCard: some View {
      let buttonForeground = homeActionForeground

      return VStack(alignment: .leading, spacing: 16) {
         Text("What matters now?")
            .font(.appBodyStrong(25, relativeTo: .title2))
            .fontWeight(.black)
            .foregroundStyle(AppColor.textPrimary)

         HStack(spacing: 12) {
            Button(action: onCreateToDo) {
               HStack(spacing: 10) {
                  HomePlusMark(size: 18, thickness: 4)
                     .frame(width: 24, height: 24)

                  Text("New toDō")
                     .font(.appButton(18, relativeTo: .headline))
               }
               .foregroundStyle(buttonForeground)
               .padding(.horizontal, 18)
               .frame(minWidth: 120, minHeight: 58)
               .background(AppColor.main, in: .rect(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.newToDo")

            NavigationLink {
               ToDosView(
                  onCreateToDo: { preselectedTagID in
                     AppLog.info("Home routed ToDosView create request")
                     toDoPresentationService.create(preselectedTagID: preselectedTagID)
                  },
                  onViewToDo: { toDo in
                     AppLog.info("Home routed ToDosView view request")
                     toDoPresentationService.view(toDo)
                  },
                  onEditToDo: { toDo in
                     AppLog.info("Home routed ToDosView edit request")
                     toDoPresentationService.edit(toDo)
                  }
               )
            } label: {
               HStack(spacing: 7) {
                  Image("checkit")
                     .renderingMode(.template)
                     .resizable()
                     .scaledToFit()
                     .foregroundStyle(buttonForeground)
                     .frame(width: 16, height: 16)

                  Text("See all toDōs")
                     .font(.appButton(18, relativeTo: .headline))
                     .foregroundStyle(buttonForeground)
                     .lineLimit(1)
                     .minimumScaleFactor(0.82)

                  Spacer(minLength: 2)

                  if activeToDos.count > 0 {
                     Text(AppLocalization.numberString(activeToDos.count))
                        .font(.appBodyStrong(14, relativeTo: .caption))
                        .fontWeight(.black)
                        .foregroundStyle(buttonForeground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(buttonForeground.opacity(0.13), in: Capsule())
                  }

                  Image(systemName: "arrow.right.circle.fill")
                     .font(.appDisplay(18, relativeTo: .headline))
                     .foregroundStyle(buttonForeground)
               }
               .padding(.horizontal, 12)
               .frame(minHeight: 58)
               .background(AppColor.secondary, in: .rect(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.seeAllToDos")
         }
         .buttonStyle(.plain)
      }
      .padding(22)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 30))
      .shadow(color: AppColor.shadow, radius: 24, x: 0, y: 12)
   }

   private var statsSection: some View {
      let buttonForeground = homeActionForeground

      return VStack(alignment: .leading, spacing: 12) {
         HStack(alignment: .center, spacing: 12) {
            Text("Momentum")
               .font(.appDisplay(22, relativeTo: .title3))
               .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)

            NavigationLink {
               StatsView(ownerUserID: visibleOwnerUserID)
            } label: {
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
         }

         LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            HomeMetricCard(title: "Active", value: activeToDos.count, tint: AppColor.secondary, systemName: "bolt.fill")
            HomeMetricCard(title: "Due soon", value: dueSoonCount, tint: AppColor.main, systemName: "clock.fill")
            HomeMetricCard(title: "Overdue", value: overdueCount, tint: AppColor.actionDestructive, systemName: "exclamationmark.circle.fill")
            HomeMetricCard(title: "Time-sensitive", value: timeSensitiveCount, tint: AppColor.actionPrimary, systemName: "flame.fill")
         }

         HomeCompletedSummary(value: doneCount)
      }
   }

   private var homeActionForeground: Color {
      AppColor.brandYellowForeground(for: colorScheme)
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
         } else {
            VStack(spacing: 10) {
               ForEach(previewToDos) { toDo in
                  HomeToDoPreviewRow(toDo: toDo)
               }
            }
         }
      }
   }

   private var activeToDos: [ToDo] {
      toDos.filter { $0.lifecycleState == .active }
   }

   private var doneCount: Int {
      toDos.filter { $0.lifecycleState == .done }.count
   }

   private var dueSoonCount: Int {
      let now = Date()
      let soon = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now
      return activeToDos.filter {
         guard let dueDate = $0.dueDate else { return false }
         return dueDate >= now && dueDate <= soon
      }.count
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
      let candidates: [ToDo]
      switch previewFilter {
      case .dueSoon:
         candidates = activeToDos
            .filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
      case .timeSensitive:
         candidates = activeToDos
            .filter { $0.reminderIntent == .timeSensitive }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
      case .recent:
         candidates = activeToDos
            .sorted { $0.syncUpdatedAt > $1.syncUpdatedAt }
      }

      return Array(candidates.prefix(3))
   }

   private var visibleOwnerUserID: UUID? {
      AppPreferences.preferredSyncMode() == .syncEverywhere ? supabaseAuthStore.scopedOwnerUserID : nil
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
   }
}

private struct HomeCompletedSummary: View {
   let value: Int

   var body: some View {
      HStack(alignment: .center, spacing: 12) {
         Image(systemName: "checkmark.circle.fill")
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
   }
}

private struct HomeToDoPreviewRow: View {
   let toDo: ToDo

   var body: some View {
      HStack(alignment: .center, spacing: 12) {
         VStack(alignment: .leading, spacing: 4) {
            Text(toDo.task)
               .font(.appBodyStrong(15, relativeTo: .subheadline))
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
            Image(systemName: "flame.fill")
               .font(.appDisplay(13, relativeTo: .caption))
               .foregroundStyle(AppColor.actionDestructive)
               .frame(width: 28, height: 28)
               .background(AppColor.actionDestructive.opacity(0.12), in: Circle())
         }
      }
      .padding(.horizontal, 15)
      .padding(.vertical, 13)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 20))
   }
}
