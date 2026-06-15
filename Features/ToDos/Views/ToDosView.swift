import SwiftUI
import SwiftData

struct ToDosView: View {
   private enum SystemListFilter: Equatable {
      case today
      case overdue
      case due
      case timeSensitive
   }

   private enum ActiveSheet: Identifiable {
      case bulkTagPicker
      case syncReview
      case settings

      var id: String {
         switch self {
         case .bulkTagPicker:
            return "bulk-tag-picker"
         case .syncReview:
            return "sync-review"
         case .settings:
            return "settings"
         }
      }
   }

   @Environment(\.modelContext) private var context
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.dismiss) private var dismiss
   @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
   @ObservedObject private var syncCoordinator = SyncCoordinator.shared
   @Query private var toDos: [ToDo]
   @Query private var tags: [Tag]
   @Query private var syncConflicts: [SyncConflict]

   @AppStorage(AppPreferences.Keys.tagSortOption) private var tagSortOption = TagSortOption.name.rawValue
   @AppStorage(AppPreferences.Keys.toDoListSortOption) private var toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
   @AppStorage(AppPreferences.Keys.toDoListSortReversed) private var isToDoListSortReversed = false
   @AppStorage(AppPreferences.Keys.doneSwipePrimaryAction) private var doneSwipePrimaryActionRaw = AppPreferences.DoneSwipePrimaryAction.delete.rawValue
   @AppStorage(AppPreferences.Keys.snoozeOptions) private var snoozeOptionsStorage = SnoozePreferences.defaultEncodedString
   @AppStorage(AppPreferences.Keys.appTimeSource) private var appTimeSourceRaw = AppTimeSource.location.rawValue
   @AppStorage(AppPreferences.Keys.locationTimeZoneIdentifier) private var locationTimeZoneIdentifier = AppTimePreferences.appleParkTimeZoneIdentifier
   @AppStorage("todo.defaultTagSeedVersion") private var defaultTagSeedVersion = 0

   @State private var selectedTagID: PersistentIdentifier?
   @State private var searchText = ""
   @State private var isSearchVisible = false
   @State private var activeSheet: ActiveSheet?
   @State private var isSelectionMode = false
   @State private var selectedCircleID: UUID?
   @State private var showingSyncView = false
   @State private var pendingNotificationToDoRoute: PendingNotificationToDoRoute?
   @State private var pendingNotificationResolutionTask: Task<Void, Never>?
   @State private var isShowingMissingNotificationToDoAlert = false
   @State private var selectedToDoIDs = Set<PersistentIdentifier>()
   @State private var isFilterVisible = false
   @State private var isUtilityTrayPresented = false
   @State private var expandedToDoID: PersistentIdentifier?
   @State private var inlineEditingToDoID: PersistentIdentifier?
   @State private var composerDetent = PresentationDetent.large//.fraction(0.92)
   @State private var systemListFilter: SystemListFilter?
   @State private var didApplyScreenshotPresentation = false
   @State private var completionAnimationPhases: [PersistentIdentifier: ToDoCompletionAnimationPhase] = [:]
   @FocusState private var isSearchFieldFocused: Bool

   @State private var navigationCoordinator = NavigationCoordinator.shared
   @StateObject private var onboardingManager = GuidedOnboardingManager.shared

   let onCreateToDo: (PersistentIdentifier?) -> Void
   let onViewToDo: (ToDo) -> Void
   let onEditToDo: (ToDo) -> Void

   init(
      onCreateToDo: @escaping (PersistentIdentifier?) -> Void = { _ in },
      onViewToDo: @escaping (ToDo) -> Void = { _ in },
      onEditToDo: @escaping (ToDo) -> Void = { _ in }
   ) {
      self.onCreateToDo = onCreateToDo
      self.onViewToDo = onViewToDo
      self.onEditToDo = onEditToDo
   }

   var body: some View {
      ZStack(alignment: .bottomTrailing) {
         AppColor.surface
            .ignoresSafeArea()

         listContent
            .blur(radius: isInlineEditingDetail ? 5 : 0)
            .animation(AppAnimation.snappySection, value: isInlineEditingDetail)

         if filteredWorkingToDos.isEmpty && !usesRegularWidthLayout {
            emptyStateOverlay
         }

         inlineDetailEditorOverlay

         if let feedback = syncCoordinator.syncFeedback {
            SyncFeedbackOverlay(feedback: feedback)
               .transition(.move(edge: .top).combined(with: .opacity))
               .zIndex(1000)
         }
      }
      .overlayPreferenceValue(OnboardingSpotlightPreferenceKey.self) { anchors in
         if onboardingManager.blocksToDosChrome {
            GuidedOnboardingOverlay(manager: onboardingManager, anchors: anchors) { step in
               handleOnboardingPrimaryAction(step)
            }
            .zIndex(1200)
         }
      }
      .sheet(item: $activeSheet) { sheet in
         activeSheetContent(for: sheet)
      }
      .onAppear {
         onboardingManager.startIfNeeded()
         resumeGuidedOnboardingIfNeeded()
         if defaultTagSeedVersion < 1 {
            seedIfNeeded()
         }
         if NavigationCoordinator.shared.shouldOpenSettings {
            NavigationCoordinator.shared.shouldOpenSettings = false
            Task { @MainActor in
               openSettingsPanel()
            }
         }
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context)
         applyScreenshotPresentationIfNeeded()
      }
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .navigationBarBackButtonHidden(true)
      .navigationBarHidden(true)
      .onChange(of: navigationCoordinator.notificationRoute
      ) { _, route in
         handleNotificationRoute(route)
      }
      .onChange(of: navigationCoordinator.shouldOpenSettings) { _, shouldOpen in
         guard shouldOpen else { return }
         navigationCoordinator.shouldOpenSettings = false
         openSettingsPanel()
      }
      .onChange(of: navigationCoordinator.listRoute) { _, route in
         handleListRoute(route)
      }
      .overlay(alignment: .leading) {
         Rectangle()
            .foregroundStyle(.clear)
            .frame(maxHeight: .infinity)
            .frame(width: usesRegularWidthLayout ? 44 : 20)
            .contentShape(Rectangle())
            .highPriorityGesture(homeSwipeGesture)
      }
      .alert("Couldn’t Find toDō", isPresented: $isShowingMissingNotificationToDoAlert) {
         Button("OK", role: .cancel) {}
      } message: {
         Text("That toDō may have been deleted or has not synced to this device yet.")
      }
      .accessibilityIdentifier("todos.view")
   }

   private var listContent: some View {
      Group {
         if usesRegularWidthLayout {
            regularWidthListContent
         } else if isRunningInPreview {
            previewListContent
         } else {
            primaryListContent
         }
      }
   }

   private var regularWidthListContent: some View {
      VStack(spacing: 0) {
         headerSurface

         HStack(alignment: .top, spacing: regularPanelSpacing) {
            regularWorkingPanel
               .frame(maxWidth: regularWorkingPanelMaxWidth)

            if isRegularDetailPanelVisible {
               regularDetailPanel
                  .frame(width: regularDetailPanelWidth)
                  .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
         }
         .frame(maxWidth: regularDashboardCurrentMaxWidth, alignment: .top)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .padding(.horizontal, regularDashboardHorizontalPadding)
         .padding(.top, 14)
         .padding(.bottom, regularDashboardBottomPadding)
         .animation(AppAnimation.snappySection, value: isRegularDetailPanelVisible)

         bottomOverlayBar
      }
      .background(AppColor.surface)
   }

   private var regularWorkingPanel: some View {
      VStack(alignment: .leading, spacing: 0) {
         HStack {
            Spacer(minLength: 0)
            regularNewToDoButton
         }
         .padding(.horizontal, 20)
         .padding(.top, 18)
         .padding(.bottom, 14)

         Divider()
            .padding(.horizontal, 20)

         ZStack {
            regularPanelList {
               toDoSections(workingSections, allowsOpen: !isSelectionMode, allowsStateActions: !isSelectionMode)
            }

            if filteredWorkingToDos.isEmpty {
               emptyStateOverlay
            }
         }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 30))
      .shadow(color: AppColor.shadow, radius: 18, x: 0, y: 8)
   }

   private var regularDetailPanel: some View {
      VStack(alignment: .leading, spacing: 0) {
         regularDetailHeader

         Divider()
            .padding(.horizontal, 18)

         if let selectedDetailToDo {
            ScrollView {
               toDoDetailPanelContent(for: selectedDetailToDo)
                  .padding(18)
            }
            .scrollIndicators(.hidden)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
         } else {
            regularEmptyDetailPanel
         }
      }
      .frame(maxHeight: .infinity, alignment: .top)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 30))
      .shadow(color: AppColor.shadow, radius: 18, x: 0, y: 8)
      .animation(AppAnimation.snappySection, value: expandedToDoID)
   }

   private var regularDetailHeader: some View {
      HStack(alignment: .center, spacing: 12) {
         if selectedDetailToDo != nil {
            Button {
               dismissSelectedDetail()
            } label: {
               Image(systemName: "xmark")
//                  .font(.appDisplay(22, relativeTo: .title3))
                  .font(.system(size: 18, weight: .black, design: .rounded))
                  .frame(width: 34, height: 34, alignment: .center)
//                  .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.onAction)
            .contentShape(Circle())
            .background(AppColor.actionDestructive, in: Circle())
            .appInteractiveCircleGlass(tint: AppColor.actionDestructive)
            .accessibilityLabel("Close")
         }

         VStack(alignment: .leading, spacing: 2) {
            Text("\(Text("Your ").foregroundStyle(AppColor.textPrimary.opacity(0.45)))\(Text("toDō").foregroundStyle(AppColor.textPrimary))")
               .font(.appTitle(34, relativeTo: .largeTitle))
         }

         Spacer(minLength: 12)

         if let selectedDetailToDo {
            Button {
               HapticFeedbackService.play(.selection)
               beginInlineDetailEdit(selectedDetailToDo)
            } label: {
               Image(systemName: "arrow.up.right.circle.fill")
                  .resizable()
                  .scaledToFit()
                  .frame(width: 34, height: 34, alignment: .center)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.secondary)
            .accessibilityLabel("Edit toDō")
         }
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 14)
   }

   @ViewBuilder
   private var inlineDetailEditorOverlay: some View {
      if usesRegularWidthLayout, let inlineEditingToDo {
         GeometryReader { proxy in
            let editorWidth = min(max(proxy.size.width * 0.56, 620), 760)
            let editorHeight = min(proxy.size.height * 0.82, 820)

            ZStack {
               Color.black.opacity(0.08)
                  .ignoresSafeArea()
                  .contentShape(Rectangle())

               ToDoView(
                  mode: .edit(inlineEditingToDo, context: .sheet),
                  onFinish: { savedToDo in
                     closeInlineDetailEdit(savedToDo: savedToDo)
                  },
                  isInlineOverlayEdit: true,
                  onDelete: {
                     deleteInlineEditingToDo(inlineEditingToDo)
                  }
               )
               .frame(width: editorWidth, height: editorHeight)
               .clipShape(.rect(cornerRadius: 30))
               .shadow(color: AppColor.shadow, radius: 34, x: 0, y: 18)
               .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
               .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
         }
         .zIndex(20)
         .transition(.opacity)
      }
   }

   private var regularEmptyDetailPanel: some View {
      VStack(alignment: .leading, spacing: 14) {
         Image(systemName: "rectangle.and.text.magnifyingglass")
            .font(.appDisplay(28, relativeTo: .title2))
            .foregroundStyle(AppColor.actionNeutral)
            .frame(width: 48, height: 48)
            .background(AppColor.surfaceMuted, in: .circle)

         Text("Select a toDō")
            .font(.appHeadline(20, relativeTo: .title3))
            .foregroundStyle(AppColor.textPrimary)

         Text("Details, notes, tags, reminders, and NanoDos appear here when a toDō has more to show.")
            .font(.appBodyStrong(15, relativeTo: .body))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(28)
   }

   private func toDoDetailPanelContent(for toDo: ToDo) -> some View {
      VStack(alignment: .leading, spacing: 18) {
         VStack(alignment: .leading, spacing: 10) {
            Text(toDo.task)
               .font(.appHeadline(24, relativeTo: .title2))
               .foregroundStyle(AppColor.textPrimary)
               .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
               toDoDetailStatusBadge(for: toDo)

               if toDo.isLate {
                  Text("Late")
                     .font(.appBodyStrong(11, relativeTo: .caption))
                     .foregroundStyle(AppColor.onAction)
                     .padding(.horizontal, 9)
                     .padding(.vertical, 5)
                     .background(AppColor.actionDestructive, in: Capsule())
               }
            }
         }

         LazyVGrid(
            columns: [
               GridItem(.flexible(), spacing: 10),
               GridItem(.flexible(), spacing: 10)
            ],
            alignment: .leading,
            spacing: 10
         ) {
            if let dueDate = toDo.dueDate {
               toDoDetailInfoRow(
                  systemName: "calendar",
                  title: "Due",
                  value: AppLocalization.dateTimeString(dueDate)
               )
            }

            toDoDetailInfoRow(
               systemName: reminderIntentSystemName(for: toDo.reminderIntent),
               title: "Reminder",
               value: toDo.reminderIntent.title
            )

            if let recurrenceSummary = toDo.recurrenceSummary {
               toDoDetailInfoRow(
                  systemName: "arrow.clockwise",
                  title: "Repeat",
                  value: recurrenceSummary
               )
            }

            toDoDetailInfoRow(
               systemName: "clock",
               title: "Updated",
               value: AppLocalization.dateTimeString(toDo.syncUpdatedAt)
            )
         }

         if !toDo.effectiveTags.isEmpty {
            toDoDetailSection(title: "Tags", systemName: "tag") {
               LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 8) {
                  ForEach(toDo.effectiveTags) { tag in
                     Text(tag.displayName)
                        .font(.appBodyStrong(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColor.surfaceMuted, in: Capsule())
                  }
               }
            }
         }

         if !toDo.nanoDos.isEmpty {
            toDoDetailSection(title: "NanoDos", systemName: "smallcircle.filled.circle") {
               VStack(alignment: .leading, spacing: 9) {
                  ForEach(toDo.nanoDos) { nanoDo in
                     HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: nanoDo.isDone ? "checkmark.circle.fill" : "circle")
                           .font(.appBodyStrong(12, relativeTo: .caption))
                           .foregroundStyle(nanoDo.isDone ? AppColor.actionPrimary : AppColor.textSecondary)

                        Text(nanoDo.task)
                           .font(.appBodyStrong(14, relativeTo: .footnote))
                           .foregroundStyle(AppColor.textPrimary)
                           .strikethrough(nanoDo.isDone, color: AppColor.textPrimary.opacity(0.35))
                           .fixedSize(horizontal: false, vertical: true)
                     }
                  }
               }
            }
         }

         let trimmedNotes = toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines)
         if !trimmedNotes.isEmpty {
            toDoDetailSection(title: "Notes", systemName: "note.text") {
               Text(trimmedNotes)
                  .font(.appBodyStrong(14, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         if !toDoHasExtendedDetails(toDo) {
            Text("No extra detail yet. Add a due date, notes, tags, or NanoDos to make this panel useful.")
               .font(.appBody(14, relativeTo: .body))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
               .padding(14)
               .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))
         }

         ToDoLifecycleActionBar(
            isDone: toDo.isDoneState,
            removalAction: doneSwipePrimaryAction,
            includesRemovalAction: true,
            includesSnooze: toDo.dueDate != nil,
            onRemoval: {
               switch doneSwipePrimaryAction {
               case .archive:
                  archiveToDo(toDo)
               case .delete:
                  deleteToDo(toDo)
               }
               dismissSelectedDetail()
            },
            onSnooze: {
               snoozeToDo(toDo, unit: .minutes, value: 15)
            },
            onToggleDone: {
               updateCompletionState(for: toDo, isDone: !toDo.isDoneState)
            }
         )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func toDoDetailStatusBadge(for toDo: ToDo) -> some View {
      Text(toDoStateTitle(toDo.lifecycleState))
         .font(.appBodyStrong(11, relativeTo: .caption))
         .foregroundStyle(AppColor.textPrimary)
         .padding(.horizontal, 9)
         .padding(.vertical, 5)
         .background(AppColor.surfaceMuted, in: Capsule())
   }

   private func toDoDetailInfoRow(systemName: String, title: String, value: String) -> some View {
      HStack(alignment: .top, spacing: 10) {
         Image(systemName: systemName)
            .font(.appBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(AppColor.actionNeutral)
            .frame(width: 18)

         VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
               .font(.appDisplay(17, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)
               .lineLimit(1)
               .minimumScaleFactor(0.86)

            Text(value)
               .font(.appBodyStrong(16, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)
               .fixedSize(horizontal: false, vertical: true)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .frame(minHeight: 76, alignment: .topLeading)
      .background(AppColor.surfaceMuted.opacity(0.7), in: .rect(cornerRadius: 18))
   }

   private func toDoDetailSection<Content: View>(
      title: String,
      systemName: String,
      @ViewBuilder content: () -> Content
   ) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Label(LocalizedStringKey(title), systemImage: systemName)
            .font(.appBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)

         content()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(AppColor.surfaceMuted.opacity(0.55), in: .rect(cornerRadius: 20))
   }

   private func toDoHasExtendedDetails(_ toDo: ToDo) -> Bool {
      toDo.dueDate != nil
      || toDo.recurrenceSummary != nil
      || !toDo.effectiveTags.isEmpty
      || !toDo.nanoDos.isEmpty
      || !toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
   }

   private func reminderIntentSystemName(for intent: ToDoReminderIntent) -> String {
      switch intent {
      case .soft:
         return "bell.badge"
      case .due:
         return "bell"
      case .timeSensitive:
         return "exclamationmark.circle"
      }
   }

   private func toDoStateTitle(_ state: ToDoState) -> String {
      switch state {
      case .active:
         return "Active"
      case .done:
         return "Done"
      case .archived:
         return "Archived"
      case .trashed:
         return "Trashed"
      }
   }

   private func handleNotificationRoute(
      _ route: NotificationRoute
   ) {
      switch route {

      case .toDo(let localIdentifier, let cloudID):

         openNotificationToDo(
            localIdentifier: localIdentifier,
            cloudID: cloudID
         )

      case .circle(let id):

         selectedCircleID = id

      case .sync:

         showingSyncView = true

      case .none:

         break

      }

      navigationCoordinator.notificationRoute = .none
   }

   private func handleListRoute(_ route: NavigationCoordinator.ListRoute?) {
      guard let route else { return }

      withAnimation(AppAnimation.snappySection) {
         selectedTagID = nil
         searchText = ""
         isSearchVisible = false
         isFilterVisible = false
         isSearchFieldFocused = false
         toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
         isToDoListSortReversed = false

         switch route {
         case .all:
            systemListFilter = nil
         case .today:
            systemListFilter = .today
         case .overdue:
            systemListFilter = .overdue
         case .due:
            systemListFilter = .due
         case .timeSensitive:
            systemListFilter = .timeSensitive
         }
      }

      navigationCoordinator.listRoute = nil
   }

   private func regularPanelHeader<Accessory: View>(
      title: String,
      count: Int,
      @ViewBuilder accessory: () -> Accessory
   ) -> some View {
      HStack(alignment: .center, spacing: 14) {
         VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
               Text(title)
                  .font(.appHeadline(22, relativeTo: .title3))
                  .foregroundStyle(AppColor.textPrimary)

               Text(AppLocalization.numberString(count))
                  .font(.appBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textPrimary)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(AppColor.surfaceMuted, in: Capsule())
            }
         }

         Spacer(minLength: 12)

         accessory()
      }
      .padding(.horizontal, 20)
      .padding(.top, 18)
      .padding(.bottom, 14)
   }

   private func regularPanelHeader(
      title: String,
      count: Int
   ) -> some View {
      regularPanelHeader(title: title, count: count) {
         EmptyView()
      }
   }

   private func regularPanelList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
      List {
         content()

         Color.clear
            .frame(height: 16)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
      }
      .animation(AppAnimation.snappySection, value: filteredWorkingToDos.map(\.id))
      .animation(AppAnimation.snappySection, value: expandedToDoID)
      .animation(AppAnimation.snappySection, value: workingListAnimationKey)
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color.clear)
      .refreshable {
         await refreshToDos()
      }
   }

   private var regularNewToDoButton: some View {
      Button {
         AppLog.info("Regular create button action fired")
         handleCreateToDoTap()
      } label: {
         AddToDoPlusMark(size: 24, thickness: 5)
            .frame(width: 42, height: 42)
            .background {
               if #unavailable(iOS 26.0) {
                  Circle()
                     .fill(AppColor.main)
               }
            }
            .appInteractiveCircleGlass(tint: AppColor.main)
      }
      .buttonStyle(.plain)
      .contentShape(Circle())
      .disabled(isComposeButtonSuppressed)
      .opacity(isComposeButtonSuppressed ? 0.42 : 1)
      .zIndex(50)
      .onboardingSpotlightAnchor(.addButton)
   }

   private var primaryListContent: some View {
      List {
         toDoSections(workingSections, allowsOpen: !isSelectionMode, allowsStateActions: !isSelectionMode)

         Color.clear
            .frame(height: listBottomSpacerHeight)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
      }
      .animation(AppAnimation.snappySection, value: filteredWorkingToDos.map(\.id))
      .animation(AppAnimation.snappySection, value: expandedToDoID)
      .animation(AppAnimation.snappySection, value: workingListAnimationKey)
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(AppColor.surface)
      .refreshable {
         await refreshToDos()
      }
      .safeAreaInset(edge: .top, spacing: 0) {
         headerSurface
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
         bottomOverlayBar
      }
   }

   private var previewListContent: some View {
      ScrollView {
         LazyVStack(alignment: .leading, spacing: 0) {
            previewToDoSections(workingSections, allowsOpen: !isSelectionMode, allowsStateActions: !isSelectionMode)

            Color.clear
               .frame(height: listBottomSpacerHeight)
         }
         .frame(maxWidth: contentMaxWidth, alignment: .center)
         .frame(maxWidth: .infinity, alignment: .center)
         .padding(.horizontal, listHorizontalInset)
         .padding(.top, 8)
      }
      .id(workingListIdentity)
      .animation(AppAnimation.snappySection, value: filteredWorkingToDos.map(\.id))
      .animation(AppAnimation.snappySection, value: expandedToDoID)
      .background(AppColor.surface)
      .refreshable {
         await refreshToDos()
      }
      .safeAreaInset(edge: .top, spacing: 0) {
         headerSurface
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
         bottomOverlayBar
      }
   }

   @ViewBuilder
   private var bottomOverlayBar: some View {
      if isBulkEditing {
         bulkActionBar
      } else if !usesRegularWidthLayout {
         HStack(spacing: 0) {
            Spacer(minLength: 0)
            composeButton(containerWidth: 0)
         }
         .frame(maxWidth: .infinity)
      }
   }

   @ViewBuilder
   private func toDoRows(_ toDos: [ToDo], allowsOpen: Bool, allowsStateActions: Bool, showsContextMenu: Bool = true) -> some View {
      ForEach(toDos) { toDo in
         interactiveToDoRow(
            toDo,
            allowsOpen: allowsOpen,
            allowsStateActions: allowsStateActions,
            showsContextMenu: showsContextMenu
         )
         .frame(maxWidth: contentMaxWidth, alignment: .center)
         .frame(maxWidth: .infinity, alignment: .center)
         .listRowInsets(EdgeInsets(top: 6, leading: listHorizontalInset, bottom: 6, trailing: listHorizontalInset))
         .listRowSeparator(.hidden)
         .listRowBackground(Color.clear)
      }
   }

   @ViewBuilder
   private func previewToDoRows(_ toDos: [ToDo], allowsOpen: Bool, allowsStateActions: Bool, showsContextMenu: Bool = true) -> some View {
      ForEach(toDos) { toDo in
         interactiveToDoRow(
            toDo,
            allowsOpen: allowsOpen,
            allowsStateActions: allowsStateActions,
            showsContextMenu: showsContextMenu
         )
         .frame(maxWidth: contentMaxWidth, alignment: .center)
         .frame(maxWidth: .infinity, alignment: .center)
         .padding(.vertical, 6)
      }
   }

   @ViewBuilder
   private func toDoSections(_ sections: [ToDoListSection], allowsOpen: Bool, allowsStateActions: Bool, showsContextMenu: Bool = true) -> some View {
      ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
         if sortOption.usesSections {
            Section {
               toDoRows(section.toDos, allowsOpen: allowsOpen, allowsStateActions: allowsStateActions, showsContextMenu: showsContextMenu)
            } header: {
               sectionHeader(section.title, isFirst: index == 0)
                  .frame(maxWidth: contentMaxWidth, alignment: .center)
                  .frame(maxWidth: .infinity, alignment: .center)
            }
         } else {
            toDoRows(section.toDos, allowsOpen: allowsOpen, allowsStateActions: allowsStateActions, showsContextMenu: showsContextMenu)
         }
      }
   }

   @ViewBuilder
   private func previewToDoSections(_ sections: [ToDoListSection], allowsOpen: Bool, allowsStateActions: Bool, showsContextMenu: Bool = true) -> some View {
      ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
         if sortOption.usesSections {
            sectionHeader(section.title, isFirst: index == 0)
               .frame(maxWidth: contentMaxWidth, alignment: .center)
               .frame(maxWidth: .infinity, alignment: .center)

            previewToDoRows(section.toDos, allowsOpen: allowsOpen, allowsStateActions: allowsStateActions, showsContextMenu: showsContextMenu)
         } else {
            previewToDoRows(section.toDos, allowsOpen: allowsOpen, allowsStateActions: allowsStateActions, showsContextMenu: showsContextMenu)
         }
      }
   }

   private func sectionHeader(_ title: String, isFirst: Bool) -> some View {
      let accent = sectionHeaderAccentColor
      let fill = sectionHeaderFillColor

      return HStack(alignment: .center, spacing: 10) {
         Text(LocalizedStringKey(title))
            .font(.appSubtitle(11, relativeTo: .caption))
            .foregroundStyle(accent)
            .textCase(nil)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
               Capsule(style: .continuous)
                  .fill(fill)
            )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, isFirst ? 2 : 8)
      .padding(.bottom, 4)
   }

   private var sectionHeaderAccentColor: Color {
      switch sortOption {
      case .dueMonthSections:
         return AppColor.tertiary
      case .tagSections:
         return AppColor.secondary
      case .nanoDoSections:
         return AppColor.textPrimary
      default:
         return AppColor.secondary
      }
   }

   private var sectionHeaderFillColor: Color {
      switch sortOption {
      case .dueMonthSections:
         return AppColor.tertiary.opacity(0.18)
      case .tagSections:
         return AppColor.secondary.opacity(0.12)
      case .nanoDoSections:
         return AppColor.surfaceMuted
      default:
         return AppColor.secondary.opacity(0.12)
      }
   }

   private func interactiveToDoRow(_ toDo: ToDo, allowsOpen: Bool, allowsStateActions: Bool, showsContextMenu: Bool = true) -> some View {
      ToDoRowView(
         toDo: toDo,
         allowsCompletionToggle: allowsStateActions,
         isSelectionMode: isSelectionMode,
         isSelected: selectedToDoIDs.contains(toDo.id),
         isDetailSelected: usesRegularWidthLayout && !isSelectionMode && selectedDetailToDo?.id == toDo.id,
         hasSyncConflict: hasSyncConflict(for: toDo),
         showsCompletedState: displayedCompletionState(for: toDo),
         completionAnimationPhase: completionAnimationPhase(for: toDo),
         onToggleDone: { isDone in
            updateCompletionState(for: toDo, isDone: isDone)
         },
         onToggleSelection: {
            toggleSelection(for: toDo.id)
         },
         isTransitioningCompletion: completionAnimationPhase(for: toDo).isAnimating
      )
      .contentShape(Rectangle())
      .onTapGesture {
         if isSelectionMode {
            toggleSelection(for: toDo.id)
            return
         }

         guard allowsOpen else { return }

         if usesRegularWidthLayout {
            selectToDoForDetail(toDo)
            return
         }

         viewToDo(toDo)
      }
      .swipeActions(edge: .leading, allowsFullSwipe: !isSelectionMode) {
         leadingSwipeActions(for: toDo, isEnabled: allowsStateActions)
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectionMode) {
         trailingSwipeActions(for: toDo, isEnabled: allowsStateActions)
      }
         .modifier(RowContextMenuModifier(isEnabled: showsContextMenu && allowsStateActions) {
            rowContextMenu(for: toDo, isEnabled: allowsStateActions)
         })
      .modifier(OnboardingCreatedRowAnchorModifier(isHighlighted: onboardingManager.highlightedToDoID == toDo.id))
      .onLongPressGesture {
         toDoListSortOption = AppPreferences.ToDoListSortOption.creationDate.rawValue
         setSelectionMode(active: true)
      }
   }

   private func hasSyncConflict(for toDo: ToDo) -> Bool {
      guard let cloudID = toDo.cloudID else { return false }
      return syncConflicts.contains {
         !$0.isResolved
         && $0.recordTable == .toDos
         && $0.recordID == cloudID
      }
   }

   private func composeButton(containerWidth: CGFloat) -> some View {
      Button {
         AppLog.info("Compact create button action fired")
         handleCreateToDoTap()
      } label: {
         AddToDoPlusMark(size: 31, thickness: 6)
            .frame(width: 56, height: 56)
            .background {
               if #unavailable(iOS 26.0) {
                  Circle()
                     .fill(AppColor.main)
               }
            }
            .appInteractiveCircleGlass(tint: AppColor.main)
      }
      .buttonStyle(.plain)
      .contentShape(Circle())
      .disabled(isComposeButtonSuppressed)
      .allowsHitTesting(!isComposeButtonSuppressed)
      .opacity(isComposeButtonSuppressed ? 0 : 1)
      .offset(y: isComposeButtonSuppressed ? 96 : 0)
      .animation(AppAnimation.snappySection, value: isComposeButtonSuppressed)
      .padding(.trailing, composeButtonTrailingPadding(containerWidth: containerWidth))
      .padding(.bottom, composeButtonBottomPadding)
      .onboardingSpotlightAnchor(.addButton)
   }

   @ViewBuilder
   private func activeSheetContent(for sheet: ActiveSheet) -> some View {
      switch sheet {
      case .bulkTagPicker:
         BulkTagPickerView(
            selectedTagID: selectedTagID,
            tags: tagList,
            onApply: applyBulkTag,
            onClear: clearBulkTags
         )
      case .syncReview:
         NavigationStack {
            SyncConflictReviewView(
               conflicts: unresolvedSyncConflicts,
               toDos: scopedToDos
            )
         }
      case .settings:
         NavigationStack {
            SettingsView(onClose: closeSettingsPanel)
         }
         .presentationCornerRadius(34)
         .presentationBackground(AppColor.surface)
         .presentationDragIndicator(.hidden)
      }
   }

   private var isBulkEditing: Bool {
      isSelectionMode
   }

   private var isSettingsPresented: Bool {
      guard case .settings = activeSheet else { return false }
      return true
   }

   private var isComposeButtonSuppressed: Bool {
      isSelectionMode
   }

   private var composeButtonBottomPadding: CGFloat {
      return 22
   }

   private var usesRegularWidthLayout: Bool {
      horizontalSizeClass == .regular
   }

   private var regularContentMaxWidth: CGFloat {
      680
   }

   private var contentMaxWidth: CGFloat {
      usesRegularWidthLayout ? regularContentMaxWidth : .infinity
   }

   private var regularDashboardMaxWidth: CGFloat {
      isBulkEditing ? 900 : 1320
   }

   private var regularDashboardCurrentMaxWidth: CGFloat {
      guard !isBulkEditing else { return regularDashboardMaxWidth }
      return isRegularDetailPanelVisible ? regularDashboardMaxWidth : regularContentMaxWidth
   }

   private var regularWorkingPanelMaxWidth: CGFloat {
      if isBulkEditing { return 900 }
      return isRegularDetailPanelVisible ? 620 : regularContentMaxWidth
   }

   private var regularDetailPanelWidth: CGFloat {
      480
   }

   private var regularDashboardBottomPadding: CGFloat {
      isBulkEditing ? 0 : 24
   }

   private var regularPanelSpacing: CGFloat {
      18
   }

   private var regularDashboardHorizontalPadding: CGFloat {
      32
   }

   private var headerMaxWidth: CGFloat {
      usesRegularWidthLayout ? 860 : .infinity
   }

   private var filterPanelMaxWidth: CGFloat {
      usesRegularWidthLayout ? 720 : .infinity
   }

   private var searchFieldMaxWidth: CGFloat {
      usesRegularWidthLayout ? 520 : 360
   }

   private var listHorizontalInset: CGFloat {
      usesRegularWidthLayout ? 20 : 16
   }

   private var headerHorizontalInset: CGFloat {
      usesRegularWidthLayout ? 32 : 16
   }

   private var headerTitleFontSize: CGFloat {
      usesRegularWidthLayout ? 70 : 64
   }

   private func composeButtonTrailingPadding(containerWidth: CGFloat) -> CGFloat {
      guard usesRegularWidthLayout else { return 18 }
      return max((containerWidth - regularContentMaxWidth) / 2 + 22, 22)
   }

   private var workingPanelTitle: String {
      isBulkEditing ? "Selecting" : "toDōs"
   }

   private var listBottomSpacerHeight: CGFloat {
      return 88
   }

   private var doneDrawerCollapsedHeaderHeight: CGFloat {
      usesRegularWidthLayout ? 58 : 44
   }

   private var doneDrawerFadeHeight: CGFloat {
      usesRegularWidthLayout ? 0 : 42
   }

   private var selectedTag: Tag? {
      tagList.first { $0.id == selectedTagID }
   }

   private var visibleOwnerUserID: UUID? {
      guard supabaseAuthStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return supabaseAuthStore.scopedOwnerUserID
   }

   private var unresolvedSyncConflicts: [SyncConflict] {
      syncConflicts
         .filter { !$0.isResolved && $0.userID == visibleOwnerUserID }
         .sorted { $0.createdAt > $1.createdAt }
   }

   private var scopedToDos: [ToDo] {
      toDos.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var selectedDetailToDo: ToDo? {
      if let expandedToDoID,
         let selected = scopedToDos.first(where: { $0.id == expandedToDoID }) {
         return selected
      }

      return nil
   }

   private var inlineEditingToDo: ToDo? {
      guard let inlineEditingToDoID else { return nil }
      return scopedToDos.first { $0.id == inlineEditingToDoID }
   }

   private var isRegularDetailPanelVisible: Bool {
      usesRegularWidthLayout && !isBulkEditing && selectedDetailToDo != nil
   }

   private var scopedTags: [Tag] {
      tags.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var isRunningInPreview: Bool {
      ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
   }

   private var isRunningInScreenshotMode: Bool {
      ProcessInfo.processInfo.arguments.contains("-UITestScreenshotMode")
   }

   private var requestedScreenshotScreen: String? {
      let arguments = ProcessInfo.processInfo.arguments
      guard let index = arguments.firstIndex(of: "-ScreenshotScreen"),
            arguments.indices.contains(arguments.index(after: index)) else {
         return nil
      }
      return arguments[arguments.index(after: index)].lowercased()
   }

   private var workingListIdentity: String {
      "working:\(sortOption.rawValue):\(isToDoListSortReversed):\(String(describing: selectedTagID))"
   }

   private var workingListAnimationKey: String {
      "working-animation:\(sortOption.rawValue):\(isToDoListSortReversed):\(String(describing: selectedTagID))"
   }

   private var isUtilityTrayVisible: Bool {
      isUtilityTrayPresented || isSearchVisible || isFilterVisible || isBulkEditing
   }

   private var homeSwipeGesture: some Gesture {
      DragGesture(minimumDistance: 24)
         .onEnded { value in
            let horizontalDistance = value.translation.width
            let verticalDistance = abs(value.translation.height)

            guard value.startLocation.x <= 44 else { return }
            guard horizontalDistance > 120 else { return }
            guard verticalDistance < 40 else { return }
            guard horizontalDistance > (verticalDistance * 2) else { return }

            goHome()
         }
   }

   private var headerPanelTransition: AnyTransition {
      .move(edge: .top).combined(with: .opacity)
   }

   private var headerSurface: some View {
      VStack(alignment: .center, spacing: 2) {
         Text(AppTimePreferences.dateString(
            now: .now,
            sourceRawValue: appTimeSourceRaw,
            locationTimeZoneIdentifier: locationTimeZoneIdentifier
         ))
         .font(.appAccent(15, relativeTo: .caption))
         .foregroundStyle(AppColor.textSecondary)
         .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)

         ZStack {
            Text("toD\(Text("ō").foregroundStyle(AppColor.main))")
               .font(.appBrand(headerTitleFontSize, relativeTo: .largeTitle))
               .foregroundStyle(AppColor.textPrimary)
               .lineLimit(1)
               .frame(maxWidth: .infinity, alignment: .center)

            HStack {
               HStack(spacing: 10) {
                  toolbarButton(
                     systemName: "house.fill",
                     label: "Back to Home",
                     tint: AppColor.main,
                     isToggled: false
                  ) {
                     goHome()
                  }
               }

               Spacer(minLength: 12)

               toolbarButton(
                  systemName: "slider.horizontal.3",
                  label: isUtilityTrayVisible ? "Hide utilities" : "Show utilities",
                  tint: AppColor.secondary,
                  isToggled: isUtilityTrayVisible
               ) {
                  toggleUtilityTray()
               }
            }
            .frame(maxWidth: .infinity)
         }

         if isUtilityTrayVisible {
            HStack(spacing: 10) {
               toolbarButton(
                  systemName: "magnifyingglass",
                  label: isSearchVisible ? "Hide search" : "Show search",
                  tint: AppColor.secondary,
                  isToggled: isSearchVisible,
                  usesUtilityPalette: true
               ) {
                  toggleSearchPanel()
               }
               toolbarButton(
                  systemName: "line.3.horizontal.decrease.circle",
                  label: isFilterVisible ? "Hide filters" : "Show filters",
                  tint: AppColor.secondary,
                  isToggled: isFilterVisible,
                  usesUtilityPalette: true
               ) {
                  toggleFilterPanel()
               }
               toolbarButton(
                  systemName: isBulkEditing ? "checkmark.circle.fill" : "checkmark.circle",
                  label: isBulkEditing ? "Done selecting" : "Select items",
                  tint: AppColor.secondary,
                  isToggled: isBulkEditing,
                  usesUtilityPalette: true
               ) {
                  setSelectionMode(active: !isBulkEditing)
               }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(headerPanelTransition)
         }

         if isSearchVisible {
            searchField
         }

         if isFilterVisible {
            filterPanel
               .transition(headerPanelTransition)
         }

         if !unresolvedSyncConflicts.isEmpty {
            syncNeedsReviewBanner
               .transition(headerPanelTransition)
         }
      }
      .frame(maxWidth: headerMaxWidth, alignment: .center)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, headerHorizontalInset)
      .padding(.top, 2)
      .padding(.bottom, 6)
      .background {
         if usesRegularWidthLayout {
            AppColor.surface
         } else {
            LiquidGlassPanelBackground(
               tint: AppColor.surface,
               cornerRadius: 0,
               fallbackMaterial: .ultraThin
            )
            .ignoresSafeArea(edges: .top)
         }
      }
   }

   private var syncNeedsReviewBanner: some View {
      Button {
         activeSheet = .syncReview
      } label: {
         HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
               .font(.system(size: 14, weight: .black, design: .rounded))
               .foregroundStyle(AppColor.secondary)

            Text(unresolvedSyncConflicts.count == 1
                 ? "Sync needs review: 1 toDō changed in two places."
                 : "Sync needs review: \(unresolvedSyncConflicts.count) toDōs changed in two places.")
            .font(.appBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(2)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
               .font(.appBodyStrong(10, relativeTo: .caption2))
               .foregroundStyle(AppColor.textSecondary)
         }
         .padding(.horizontal, 14)
         .padding(.vertical, 10)
         .frame(maxWidth: filterPanelMaxWidth, alignment: .leading)
         .background(AppColor.secondary.opacity(0.1), in: .rect(cornerRadius: 18))
      }
      .buttonStyle(.plain)
      .padding(.top, 6)
   }

   @ViewBuilder
   private var bulkActionBar: some View {
      if isBulkEditing {
         VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
               bulkActionButton(systemName: "checkmark.circle.fill", label: "Complete", tint: AppColor.actionSuccess, disabled: selectedToDoIDs.isEmpty) {
                  applyBulkCompletion(true)
               }
               bulkActionButton(systemName: "arrow.uturn.backward.circle", label: "Reopen", tint: AppColor.secondary, disabled: selectedToDoIDs.isEmpty) {
                  applyBulkCompletion(false)
               }
               bulkActionButton(systemName: "tag", label: "Tag", tint: AppColor.main, disabled: selectedToDoIDs.isEmpty) {
                  activeSheet = .bulkTagPicker
               }
               bulkActionButton(systemName: "trash", label: "Delete", tint: AppColor.actionDestructive, disabled: selectedToDoIDs.isEmpty) {
                  deleteSelected()
               }
               bulkActionButton(systemName: "xmark", label: "Cancel", tint: AppColor.textSecondary, disabled: false) {
                  setSelectionMode(active: false)
               }
            }
            .frame(maxWidth: contentMaxWidth, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, headerHorizontalInset)
            .padding(.vertical, 12)
            .background(AppColor.surface)
         }
         .transition(.move(edge: .bottom).combined(with: .opacity))
      }
   }

   private var emptyStateOverlay: some View {
      VStack(spacing: 10) {
         Text(emptyStateTitle)
            .font(.appHeadline(20, relativeTo: .title3))
            .foregroundStyle(AppColor.main)
            .multilineTextAlignment(.center)

         Text(emptyStateSubtitle)
            .font(.appBodyStrong(15, relativeTo: .body))
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)

         Button {
            handleCreateToDoTap()
         } label: {
            Text(emptyStateActionTitle)
         }
         .font(.appBodyStrong(15, relativeTo: .body))
         .foregroundStyle(AppColor.secondary)
         .buttonStyle(.plain)
      }
      .frame(maxWidth: usesRegularWidthLayout ? 420 : 340)
      .padding(.horizontal, 20)
      .padding(.vertical, 28)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .padding(.bottom, 0)
      .allowsHitTesting(true)
   }

   private var emptyStateTitle: LocalizedStringKey {
      hasActiveFilters ? "No toDōs match this view." : "What’s worth doing today?"
   }

   private var emptyStateSubtitle: LocalizedStringKey {
      hasActiveFilters ? "Shift the filters or begin a fresh one." : "Start with your first toDō."
   }

   private var emptyStateActionTitle: LocalizedStringKey {
      "Add toDō"
   }

   @ViewBuilder
   private func leadingSwipeActions(for toDo: ToDo, isEnabled: Bool) -> some View {
      if isEnabled {
         if toDo.isDoneState {
            Button {
               updateCompletionState(for: toDo, isDone: false)
            } label: {
               Image(systemName: "arrow.uturn.backward.circle")
            }
            .tint(AppColor.actionPrimary)
         } else {
            Button {
               updateCompletionState(for: toDo, isDone: true)
            } label: {
               Image(systemName: "checkmark.circle")
            }
            .tint(AppColor.actionSuccess)
         }
      }
   }

   @ViewBuilder
   private func trailingSwipeActions(for toDo: ToDo, isEnabled: Bool) -> some View {
      if isEnabled {
         switch doneSwipePrimaryAction {
         case .archive:
            Button {
               archiveToDo(toDo)
            } label: {
               Image(systemName: "archivebox")
            }
            .tint(AppColor.actionSecondary)
         case .delete:
            Button(role: .destructive) {
               deleteToDo(toDo)
            } label: {
               Image(systemName: "trash")
            }
            .tint(.red)
         }
      }
   }

   @ViewBuilder
   private func rowContextMenu(for toDo: ToDo, isEnabled: Bool) -> some View {
      if isEnabled {
         Button {
            openToDo(toDo)
         } label: {
            Label("Edit", systemImage: "pencil")
         }

         if toDo.isLate {
            snoozeMenu(for: toDo)
         }

         if toDo.isDoneState {
            Button {
               updateCompletionState(for: toDo, isDone: false)
            } label: {
               Label("Mark Active", systemImage: "arrow.uturn.backward.circle")
            }

            switch doneSwipePrimaryAction {
            case .archive:
               Button(role: .destructive) {
                  deleteToDo(toDo)
               } label: {
                  Label("Delete", systemImage: "trash")
               }
            case .delete:
               Button {
                  archiveToDo(toDo)
               } label: {
                  Label("Archive", systemImage: "archivebox")
               }
            }
         } else {
            Button {
               updateCompletionState(for: toDo, isDone: true)
            } label: {
               Label("Mark Done", systemImage: "checkmark.circle")
            }

            Button {
               archiveToDo(toDo)
            } label: {
               Label("Archive", systemImage: "archivebox")
            }

            Button(role: .destructive) {
               deleteToDo(toDo)
            } label: {
               Label("Delete", systemImage: "trash")
            }
         }
      }
   }

   private var searchField: some View {
      HStack {
         Spacer(minLength: 0)

         ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
               .fill(AppColor.surfaceElevated)

            TextField("Search toDōs, notes, tags, nanoDos", text: $searchText)
               .textInputAutocapitalization(.never)
               .autocorrectionDisabled()
               .focused($isSearchFieldFocused)
               .padding(.leading, 40)
               .padding(.trailing, searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 14 : 40)
               .padding(.vertical, 10)

            HStack(spacing: 0) {
               Image(systemName: "magnifyingglass")
                  .foregroundStyle(AppColor.textSecondary)
                  .padding(.leading, 14)

               Spacer(minLength: 0)

               if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                  Button {
                     searchText = ""
                  } label: {
                     Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textSecondary)
                  }
                  .buttonStyle(.plain)
                  .padding(.trailing, 12)
               }
            }
         }
         .frame(maxWidth: searchFieldMaxWidth)
         .frame(height: 44)

         Spacer(minLength: 0)
      }
      .padding(.horizontal, 4)
      .padding(.top, 6)
      .padding(.bottom, 2)
   }

   private func toolbarButton(
      systemName: String,
      label: String,
      tint: Color,
      isToggled: Bool,
      usesUtilityPalette: Bool = false,
      action: @escaping () -> Void
   ) -> some View {
      let foreground: Color
      let backgroundTint: Color

      if usesUtilityPalette {
         foreground = isToggled ? AppColor.black : AppColor.white
         backgroundTint = isToggled ? AppColor.white : AppColor.black
      } else {
         foreground = isToggled ? AppColor.black : AppColor.headerForeground(for: colorScheme)
         backgroundTint = isToggled ? AppColor.white : tint
      }

      return Button(action: action) {
         Image(systemName: systemName)
            .font(.system(size: 16, weight: .black, design: .rounded))
            .contentTransition(.symbolEffect(.replace))
            .animation(AppAnimation.easeStandard, value: systemName)
      }
      .buttonStyle(.plain)
      .foregroundStyle(foreground)
      .frame(width: 34, height: 34)
      .background {
         if #available(iOS 26.0, *) {
            Color.clear
         } else if usesRegularWidthLayout {
            Circle()
               .fill(backgroundTint)
         } else {
            LiquidGlassPanelBackground(
               tint: backgroundTint,
               cornerRadius: 17,
               fallbackMaterial: .ultraThin
            )
            .overlay {
               Circle()
                  .fill(backgroundTint.opacity(usesUtilityPalette ? (isToggled ? 0.86 : 0.72) : (isToggled ? 0.74 : 0.62)))
            }
            .overlay {
               Circle()
                  .stroke(.white.opacity(0.28), lineWidth: 1)
            }
         }
      }
      .appInteractiveCircleGlass(tint: backgroundTint)
      .clipShape(Circle())
      .scaleEffect(isToggled ? 1.02 : 1)
      .animation(AppAnimation.easeFast, value: isToggled)
      .accessibilityLabel(label)
   }

   private func bulkActionButton(
      systemName: String,
      label: String,
      tint: Color,
      disabled: Bool,
      action: @escaping () -> Void
   ) -> some View {
      VStack(spacing: 5) {
         Button(action: action) {
            Image(systemName: systemName)
               .font(.system(size: 14, weight: .black, design: .rounded))
         }
         .buttonStyle(AppCircleActionButtonStyle(intent: .neutral, size: 34, tint: tint))
         .interactionDisabled(disabled)

         Text(LocalizedStringKey(label))
            .font(.appBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .frame(width: 54)
      .opacity(disabled ? 0.45 : 1)
   }

   private var filterPanel: some View {
      VStack(alignment: .leading, spacing: 8) {
         compactFilterPanelRow(
            title: "Order",
            options: AppPreferences.ToDoListSortOption.orderingOptions
         )

         compactFilterPanelRow(
            title: "Group",
            options: AppPreferences.ToDoListSortOption.groupingOptions
         )

         HStack(alignment: .center, spacing: 10) {
            Text("Tags")
               .font(.appBodyStrong(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
               .frame(width: 42, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
               HStack(spacing: 8) {
                  filterChip(title: "All Tags", isSelected: selectedTagID == nil) {
                     withAnimation(AppAnimation.snappySection) {
                        selectedTagID = nil
                     }
                  }

                  ForEach(tagList) { tag in
                     filterChip(title: tag.displayName, isSelected: selectedTagID == tag.id) {
                        withAnimation(AppAnimation.snappySection) {
                           selectedTagID = tag.id
                        }
                     }
                  }
               }
               .padding(.vertical, 1)
            }
         }

         if hasActiveFilters {
            Button("Reset Filters") {
               clearFilters()
            }
            .font(.appBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
         }
      }
      .padding(.top, 2)
      .frame(maxWidth: filterPanelMaxWidth, alignment: .center)
      .frame(maxWidth: .infinity, alignment: .center)
   }

   private func compactFilterPanelRow(
      title: String,
      options: [AppPreferences.ToDoListSortOption]
   ) -> some View {
      HStack(alignment: .center, spacing: 10) {
         Text(LocalizedStringKey(title))
            .font(.appBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
            .frame(width: 42, alignment: .leading)

         ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
               ForEach(options) { option in
                  filterChip(
                     title: option.compactTitle,
                     isSelected: option == sortOption,
                     direction: option == sortOption ? currentSortDirectionSymbol : nil
                  ) {
                     handleSortSelection(option)
                  }
               }
            }
            .padding(.vertical, 1)
         }
      }
   }

   private func filterChip(title: String, isSelected: Bool, direction: String? = nil, action: @escaping () -> Void) -> some View {
      Button(action: action) {
         HStack(spacing: 6) {
            Text(LocalizedStringKey(title))
               .font(.appBodyStrong(13, relativeTo: .subheadline))

            if let direction {
               Image(systemName: direction)
                  .font(.appBodyStrong(10, relativeTo: .caption))
            }
         }
         .foregroundStyle(isSelected ? AppColor.onAction : AppColor.textPrimary)
         .padding(.horizontal, 10)
         .padding(.vertical, 6)
      }
      .buttonStyle(.plain)
      .background {
         if #unavailable(iOS 26.0) {
            Capsule()
               .fill(isSelected ? AppColor.actionSecondary : AppColor.surfaceMuted)
         }
      }
      .appInteractiveCapsuleGlass(tint: isSelected ? AppColor.actionSecondary : AppColor.surfaceMuted)
      .overlay {
         if #unavailable(iOS 26.0) {
            Capsule()
               .stroke(isSelected ? AppColor.actionSecondary : AppColor.border.opacity(0.4), lineWidth: 1)
         }
      }
      .animation(AppAnimation.easeStandard, value: isSelected)
   }

   private var currentSortDirectionSymbol: String {
      isToDoListSortReversed ? "arrow.up" : "arrow.down"
   }

   private func handleSortSelection(_ option: AppPreferences.ToDoListSortOption) {
      withAnimation(AppAnimation.snappySection) {
         if sortOption == option {
            isToDoListSortReversed.toggle()
         } else {
            toDoListSortOption = option.rawValue
            isToDoListSortReversed = false
         }
      }
   }

   private var sortOption: AppPreferences.ToDoListSortOption {
      AppPreferences.ToDoListSortOption(rawValue: toDoListSortOption) ?? .dueDate
   }

   private var snoozeOptions: SnoozeOptionsStore {
      SnoozePreferences.decode(snoozeOptionsStorage)
   }

   private var tagList: [Tag] {
      let option = TagSortOption.resolvedOption(from: tagSortOption)
      let isAscending = TagSortOption.resolvedDirection(
         from: tagSortOption,
         storedDirection: UserDefaults.standard.object(forKey: AppPreferences.Keys.tagSortAscending) as? Bool
      )
      return TagSortOption.sortedTags(scopedTags, option: option, isAscending: isAscending)
   }

   private var filteredWorkingToDos: [ToDo] {
      visibleToDos(in: [.active])
   }

   private var workingSections: [ToDoListSection] {
      groupedVisibleToDos(in: [.active])
   }

   private func visibleToDos(in states: Set<ToDoState>) -> [ToDo] {
      groupedVisibleToDos(in: states).flatMap(\.toDos)
   }

   private func groupedVisibleToDos(in states: Set<ToDoState>) -> [ToDoListSection] {
      let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      let searchFiltered = scopedToDos.filter { toDo in
         guard !toDo.isArchived, states.contains(toDo.lifecycleState) else { return false }
         if let systemListFilter {
            switch systemListFilter {
            case .today:
               guard let dueDate = toDo.dueDate,
                     Calendar.current.isDateInToday(dueDate) else { return false }
            case .overdue:
               guard toDo.isLate else { return false }
            case .due:
               guard toDo.dueDate != nil else { return false }
            case .timeSensitive:
               guard toDo.reminderIntent == .timeSensitive else { return false }
            }
         }
         guard !searchTerm.isEmpty else { return true }
         return toDo.task.lowercased().contains(searchTerm)
         || toDo.notes.lowercased().contains(searchTerm)
         || toDo.effectiveTags.contains(where: { $0.name.lowercased().contains(searchTerm) })
         || toDo.nanoDos.contains(where: { $0.task.lowercased().contains(searchTerm) })
      }

      let tagFiltered: [ToDo]
      if let selectedTag {
         tagFiltered = searchFiltered.filter { toDo in
            toDo.effectiveTags.contains(where: { $0.id == selectedTag.id })
         }
      } else {
         tagFiltered = searchFiltered
      }

      switch sortOption {
      case .dueDate:
         return [
            ToDoListSection(
               key: "flat:\(AppPreferences.ToDoListSortOption.dueDate.rawValue)",
               title: "",
               toDos: applySortDirection(to: tagFiltered.sorted { lhs, rhs in
                  let left = lhs.dueDate ?? .distantFuture
                  let right = rhs.dueDate ?? .distantFuture
                  if left == right {
                     if lhs.isLate != rhs.isLate {
                        return lhs.isLate && !rhs.isLate
                     }
                     return lhs.createdAt > rhs.createdAt
                  }
                  return left < right
               })
            )
         ]
      case .creationDate:
         return [
            ToDoListSection(
               key: "flat:\(AppPreferences.ToDoListSortOption.creationDate.rawValue)",
               title: "",
               toDos: applySortDirection(to: tagFiltered.sorted {
                  if $0.isLate != $1.isLate {
                     return $0.isLate && !$1.isLate
                  }
                  return $0.createdAt > $1.createdAt
               })
            )
         ]
      case .tag:
         if selectedTag != nil {
            return [
               ToDoListSection(
                  key: "flat:\(AppPreferences.ToDoListSortOption.tag.rawValue):selected",
                  title: "",
                  toDos: applySortDirection(to: tagFiltered.sorted { lhs, rhs in
                     let leftDate = lhs.dueDate ?? .distantFuture
                     let rightDate = rhs.dueDate ?? .distantFuture
                     return leftDate < rightDate
                  })
               )
            ]
         } else {
            return [
               ToDoListSection(
                  key: "flat:\(AppPreferences.ToDoListSortOption.tag.rawValue)",
                  title: "",
                  toDos: applySortDirection(to: tagFiltered.sorted { lhs, rhs in
                     let leftTag = lhs.effectiveTags.first?.name ?? ""
                     let rightTag = rhs.effectiveTags.first?.name ?? ""
                     if leftTag == rightTag {
                        if lhs.isLate != rhs.isLate {
                           return lhs.isLate && !rhs.isLate
                        }
                        return lhs.createdAt > rhs.createdAt
                     }
                     return leftTag < rightTag
                  })
               )
            ]
         }
      case .dueMonthSections:
         return dueMonthSections(for: tagFiltered)
      case .tagSections:
         return tagSections(for: tagFiltered)
      case .nanoDoSections:
         return nanoDoSections(for: tagFiltered)
      }
   }

   private func dueMonthSections(for toDos: [ToDo]) -> [ToDoListSection] {
      let calendar = AppLocalization.displayCalendar
      let grouped = Dictionary(grouping: toDos) { toDo -> Date? in
         guard let dueDate = toDo.dueDate else { return nil }
         return calendar.date(from: calendar.dateComponents([.year, .month], from: dueDate))
      }

      var sections = grouped.compactMap { key, value -> ToDoListSection? in
         let title: String
         if let key {
            title = AppLocalization.monthYearString(key)
         } else {
            title = String(localized: "No Due Date")
         }

         return ToDoListSection(
            key: key.map { "month:\($0.timeIntervalSinceReferenceDate)" } ?? "month:none",
            title: title,
            sortDate: key ?? .distantFuture,
            toDos: value.sorted(by: dueDateSort)
         )
      }

      sections.sort { lhs, rhs in
         lhs.sortDate < rhs.sortDate
      }

      return applySectionDirection(to: sections)
   }

   private func tagSections(for toDos: [ToDo]) -> [ToDoListSection] {
      let grouped = Dictionary(grouping: toDos) { toDo in
         let firstTag = toDo.effectiveTags.first
         let key = firstTag.map { "tag:\(String(describing: $0.id))" } ?? "tag:untagged"
         let title = firstTag?.displayName ?? "Untagged"
         return TagSectionKey(key: key, title: title)
      }

      let sections = grouped
         .map { key, value in
            ToDoListSection(
               key: key.key,
               title: key.title,
               toDos: value.sorted(by: dueDateSort)
            )
         }
         .sorted { lhs, rhs in
            if lhs.title == "Untagged" { return false }
            if rhs.title == "Untagged" { return true }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
         }

      return applySectionDirection(to: sections)
   }

   private func nanoDoSections(for toDos: [ToDo]) -> [ToDoListSection] {
      let grouped = Dictionary(grouping: toDos) { $0.nanoDos.count }

      let sections = grouped
         .map { count, value in
            ToDoListSection(
               key: "count:\(count)",
               title: count == 0 ? "No nanoDos" : count == 1 ? "1 nanoDo" : "\(count) nanoDos",
               sortCount: count,
               toDos: value.sorted(by: dueDateSort)
            )
         }
         .sorted { lhs, rhs in
            if lhs.sortCount == rhs.sortCount {
               return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.sortCount > rhs.sortCount
         }

      return applySectionDirection(to: sections)
   }

   private func dueDateSort(_ lhs: ToDo, _ rhs: ToDo) -> Bool {
      let left = lhs.dueDate ?? .distantFuture
      let right = rhs.dueDate ?? .distantFuture
      if left == right {
         if lhs.isLate != rhs.isLate {
            return lhs.isLate && !rhs.isLate
         }
         return lhs.createdAt > rhs.createdAt
      }
      return left < right
   }

   private func applySortDirection(to toDos: [ToDo]) -> [ToDo] {
      guard isToDoListSortReversed else { return toDos }
      return Array(toDos.reversed())
   }

   private func applySectionDirection(to sections: [ToDoListSection]) -> [ToDoListSection] {
      let normalized = sections.map { section in
         ToDoListSection(
            key: section.key,
            title: section.title,
            sortDate: section.sortDate,
            sortCount: section.sortCount,
            toDos: applySortDirection(to: section.toDos)
         )
      }

      guard isToDoListSortReversed else { return normalized }
      return Array(normalized.reversed())
   }

   private func applyBulkCompletion(_ isDone: Bool) {
      guard !selectedToDoIDs.isEmpty else { return }
      HapticFeedbackService.play(isDone ? .taskCompleted : .taskReopened)
      for toDo in selectedToDos() {
         updateCompletionState(for: toDo, isDone: isDone, emitHaptic: false)
      }
      selectedToDoIDs.removeAll()
   }

   private func updateCompletionState(for toDo: ToDo, isDone: Bool, emitHaptic: Bool = true) {
      guard completionAnimationPhases[toDo.id] == nil else { return }

      if emitHaptic {
         HapticFeedbackService.play(isDone ? .taskCompleted : .taskReopened)
      }

      if isDone {
         animateCompletionThenCommit(for: toDo)
         return
      } else {
         withAnimation(AppAnimation.snappyStandard) {
            expandedToDoID = nil
            toDo.transition(to: .active)
         }
      }

      persistChanges("Failed to update toDō completion state")

      if !isDone {
         syncCalendarMirrorIfNeeded(for: toDo)
      }
   }

   private func displayedCompletionState(for toDo: ToDo) -> Bool {
      toDo.isDoneState || completionAnimationPhase(for: toDo).isAnimating
   }

   private func completionAnimationPhase(for toDo: ToDo) -> ToDoCompletionAnimationPhase {
      completionAnimationPhases[toDo.id] ?? .none
   }

   private func animateCompletionThenCommit(for toDo: ToDo) {
      let id = toDo.id
      let holdDuration = completionHoldDuration(for: toDo)

      withAnimation(.linear(duration: 0.52)) {
         expandedToDoID = nil
         completionAnimationPhases[id] = .striking
      }

      Task { @MainActor in
         try? await Task.sleep(for: .milliseconds(560))
         guard completionAnimationPhases[id] == .striking else { return }

         withAnimation(.easeInOut(duration: 0.34)) {
            completionAnimationPhases[id] = .grayscale
         }

         try? await Task.sleep(for: .milliseconds(Int(holdDuration * 1_000)))
         guard completionAnimationPhases[id] == .grayscale else { return }

         withAnimation(.easeInOut(duration: 0.38)) {
            completionAnimationPhases[id] = .dissolving
         }

         try? await Task.sleep(for: .milliseconds(420))
         guard completionAnimationPhases[id] == .dissolving else { return }

         withAnimation(AppAnimation.snappySection) {
            toDo.transition(to: .done)
            completionAnimationPhases[id] = nil
         }

         removeCalendarMirrorIfPresent(for: toDo)
         LiveActivityService.shared.endActivity(for: toDo)
         persistChanges("Failed to update toDō completion state")
      }
   }

   private func completionHoldDuration(for toDo: ToDo) -> Double {
      let textWeight = min(Double(toDo.task.count) / 120.0, 1.0)
      let contentWeight = min(Double(toDo.nanoDos.count) / 8.0, 1.0)
      return 3.0 + ((textWeight * 0.75) + (contentWeight * 0.45))
   }

   private func deleteSelected() {
      guard !selectedToDoIDs.isEmpty else { return }
      HapticFeedbackService.play(.destructive)
      for toDo in selectedToDos() {
         deleteToDo(toDo, emitHaptic: false)
      }
      selectedToDoIDs.removeAll()
   }

   private var doneSwipePrimaryAction: AppPreferences.DoneSwipePrimaryAction {
      AppPreferences.DoneSwipePrimaryAction(rawValue: doneSwipePrimaryActionRaw) ?? .archive
   }

   private func archiveToDo(_ toDo: ToDo) {
      HapticFeedbackService.play(.warning)
      withAnimation(AppAnimation.easeStandard) {
         if expandedToDoID == toDo.id {
            expandedToDoID = nil
         }
         toDo.transition(to: .archived)
      }
      removeCalendarMirrorIfPresent(for: toDo)
      LiveActivityService.shared.endActivity(for: toDo)
      persistChanges("Failed to archive toDō")
   }

   private func deleteToDo(_ toDo: ToDo, emitHaptic: Bool = true) {
      if emitHaptic {
         HapticFeedbackService.play(.destructive)
      }
      withAnimation(AppAnimation.easeFast) {
         if expandedToDoID == toDo.id {
            expandedToDoID = nil
         }

         toDo.trashedAt = Date()
         toDo.transition(to: .trashed)

         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
      }
      removeCalendarMirrorIfPresent(for: toDo)
      LiveActivityService.shared.endActivity(for: toDo)
      persistChanges("Failed to move toDō to trash")
   }

   private func snoozeMenu(for toDo: ToDo) -> some View {
      Menu {
         ForEach(SnoozeUnit.allCases) { unit in
            let values = snoozeOptions.values(for: unit)
            if !values.isEmpty {
               Menu(unit.title) {
                  ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                     Button(unit.displayLabel(for: value)) {
                        snoozeToDo(toDo, unit: unit, value: value)
                     }
                  }
               }
            }
         }
      } label: {
         Label("Snooze", systemImage: "moon.zzz")
      }
   }

   private func snoozeToDo(_ toDo: ToDo, unit: SnoozeUnit, value: Int) {
      withAnimation(AppAnimation.easeStandard) {
         let now = Date()
         let baseDate = max(toDo.dueDate ?? now, now)
         toDo.dueDate = Calendar.current.date(byAdding: unit.calendarComponent, value: value, to: baseDate)
         toDo.markUpdated()
      }
      persistChanges("Failed to snooze toDō")
      syncCalendarMirrorIfNeeded(for: toDo)
   }

   private func applyBulkTag(_ tag: Tag) {
      for toDo in selectedToDos() {
         if toDo.effectiveTags.contains(where: { $0.id == tag.id }) { continue }
         var updatedTags = toDo.effectiveTags
         guard updatedTags.count < ToDo.maxTagSelection else { continue }
         updatedTags.append(tag)
         toDo.setSelectedTags(updatedTags)
      }
      selectedToDoIDs.removeAll()
      persistChanges("Failed to apply bulk tag changes")
   }

   private func clearBulkTags() {
      for toDo in selectedToDos() {
         toDo.setSelectedTags([])
      }
      selectedToDoIDs.removeAll()
      persistChanges("Failed to clear bulk tag changes")
   }

   private func selectedToDos() -> [ToDo] {
      let toDosByID = Dictionary(scopedToDos.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
      return selectedToDoIDs.compactMap { toDosByID[$0] }
   }

   private var hasActiveFilters: Bool {
      let hasSearch = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      return selectedTagID != nil || hasSearch || sortOption != .dueDate || systemListFilter != nil
   }

   private func clearFilters() {
      withAnimation(AppAnimation.snappySection) {
         selectedTagID = nil
         searchText = ""
         systemListFilter = nil
         toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
         isToDoListSortReversed = false
      }
   }

   private func handleOnboardingPrimaryAction(_ step: GuidedOnboardingStep) {
      switch step {
      case .welcome:
         onboardingManager.advance(to: .highlightAddButton)
      case .creationSuccess:
         onboardingManager.advance(to: .highlightSettings)
      case .highlightAddButton:
         onboardingManager.advance(to: .openAddView)
         openNewToDoComposer()
      case .highlightSettings:
         onboardingManager.advance(to: .signInAndSync)
         openSettingsPanel()
      default:
         break
      }
   }

   private func resumeGuidedOnboardingIfNeeded() {
      guard onboardingManager.isActive else { return }

      switch onboardingManager.currentStep {
      case .openAddView, .enterToDoText, .saveToDo:
         Task { @MainActor in
            openNewToDoComposer()
         }
      case .signInAndSync, .notificationPermission, .archiveVsDelete, .completion:
         if !isSettingsPresented {
            Task { @MainActor in
               openSettingsPanel()
            }
         }
      default:
         break
      }
   }

   private func openToDo(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeFast) {
         expandedToDoID = usesRegularWidthLayout ? toDo.id : nil
         inlineEditingToDoID = nil
      }
      onEditToDo(toDo)
   }

   private func viewToDo(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeFast) {
         expandedToDoID = usesRegularWidthLayout ? toDo.id : nil
         inlineEditingToDoID = nil
      }
      onViewToDo(toDo)
   }

   private func openNotificationToDo(
      localIdentifier: String?,
      cloudID: UUID?
   ) {
      let route = PendingNotificationToDoRoute(
         localIdentifier: localIdentifier,
         cloudID: cloudID
      )

      guard let toDo = toDoForNotificationRoute(route) else {
         pendingNotificationToDoRoute = route
         schedulePendingNotificationRouteResolution()
         return
      }

      pendingNotificationResolutionTask?.cancel()
      pendingNotificationResolutionTask = nil
      pendingNotificationToDoRoute = nil
      isSelectionMode = false
      selectedToDoIDs.removeAll()
      activeSheet = nil
      viewToDo(toDo)
   }

   private func schedulePendingNotificationRouteResolution() {
      pendingNotificationResolutionTask?.cancel()
      pendingNotificationResolutionTask = Task { @MainActor in
         await SyncCoordinator.shared.refreshFromRemote(userID: supabaseAuthStore.currentUserID)

         for _ in 0..<8 {
            guard !Task.isCancelled,
                  let pendingNotificationToDoRoute else {
               return
            }

            if toDoForNotificationRoute(pendingNotificationToDoRoute) != nil {
               openNotificationToDo(
                  localIdentifier: pendingNotificationToDoRoute.localIdentifier,
                  cloudID: pendingNotificationToDoRoute.cloudID
               )
               return
            }

            try? await Task.sleep(nanoseconds: 350_000_000)
         }

         guard !Task.isCancelled,
               pendingNotificationToDoRoute != nil else {
            return
         }

         pendingNotificationToDoRoute = nil
         pendingNotificationResolutionTask = nil
         isShowingMissingNotificationToDoAlert = true
      }
   }

   private func toDoForNotificationRoute(
      _ route: PendingNotificationToDoRoute
   ) -> ToDo? {
      if let cloudID = route.cloudID,
         let toDo = scopedToDos.first(where: { $0.cloudID == cloudID }) {
         return toDo
      }

      if let localIdentifier = route.localIdentifier {
         return scopedToDos.first {
            String(describing: $0.id) == localIdentifier
         }
      }

      return nil
   }

   private func openNewToDoComposer() {
      onCreateToDo(selectedTagID)
   }

   private func handleCreateToDoTap() {
      AppLog.info(
         "Create toDō button tapped: suppressed=\(isComposeButtonSuppressed), selection=\(isSelectionMode), activeSheet=\(activeSheet?.id ?? "nil"), inlineEditing=\(inlineEditingToDoID != nil)"
      )

      if onboardingManager.currentStep == .highlightAddButton {
         onboardingManager.advance(to: .openAddView)
      }

      openNewToDoComposer()
   }

   private func selectToDoForDetail(_ toDo: ToDo) {
      withAnimation(AppAnimation.snappySection) {
         expandedToDoID = toDo.id
         inlineEditingToDoID = nil
      }
   }

   private func dismissSelectedDetail() {
      withAnimation(AppAnimation.snappySection) {
         expandedToDoID = nil
         inlineEditingToDoID = nil
      }
   }

   private var isInlineEditingDetail: Bool {
      guard let inlineEditingToDoID, let selectedDetailToDo else { return false }
      return inlineEditingToDoID == selectedDetailToDo.id
   }

   private func beginInlineDetailEdit(_ toDo: ToDo) {
      withAnimation(AppAnimation.snappySection) {
         expandedToDoID = toDo.id
         inlineEditingToDoID = toDo.id
      }
   }

   private func closeInlineDetailEdit(savedToDo: ToDo?) {
      withAnimation(AppAnimation.snappySection) {
         if let savedToDo {
            expandedToDoID = savedToDo.id
         }
         inlineEditingToDoID = nil
      }
   }

   private func deleteInlineEditingToDo(_ toDo: ToDo) {
      withAnimation(AppAnimation.snappySection) {
         if expandedToDoID == toDo.id {
            expandedToDoID = nil
         }
         inlineEditingToDoID = nil
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
         context.delete(toDo)
      }
      persistChanges("Failed to delete toDō")
   }

   private func setSelectionMode(active: Bool) {
      if !active {
         selectedToDoIDs.removeAll()
      } else {
         isSearchVisible = false
         isFilterVisible = false
         isSearchFieldFocused = false
         expandedToDoID = nil
         inlineEditingToDoID = nil
      }

      withAnimation(AppAnimation.snappyFast) {
         isSelectionMode = active
      }
   }

   private func toggleSelection(for id: PersistentIdentifier) {
      HapticFeedbackService.play(.selection)
      if selectedToDoIDs.contains(id) {
         selectedToDoIDs.remove(id)
      } else {
         selectedToDoIDs.insert(id)
      }
   }

   private func openSettingsPanel() {
      activeSheet = .settings
      isUtilityTrayPresented = false
      isSearchVisible = false
      isFilterVisible = false
      isSearchFieldFocused = false
   }

   private func closeSettingsPanel() {
      if isSettingsPresented {
         activeSheet = nil
      }
   }

   private func goHome() {
      dismiss()

      // Future:
      // navigationCoordinator.destination = .home
   }

   private func applyScreenshotPresentationIfNeeded() {
      guard isRunningInScreenshotMode, !didApplyScreenshotPresentation else { return }
      didApplyScreenshotPresentation = true

      let screen = requestedScreenshotScreen ?? "todos"
      switch screen {
      case "settings":
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            openSettingsPanel()
         }
      case "todo", "todoview", "detail":
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard let target = scopedToDos.first(where: { $0.task == "Ship toDō 3.0 TestFlight" }) ?? scopedToDos.first else {
               return
            }
            activeSheet = nil
            inlineEditingToDoID = nil
            onViewToDo(target)
            expandedToDoID = target.id
         }
      default:
         break
      }
   }

   private func toggleSearchPanel() {
      HapticFeedbackService.play(.reveal)
      let shouldShow = !isSearchVisible
      isSearchFieldFocused = false
      isUtilityTrayPresented = true
      isSearchVisible = shouldShow
      if shouldShow {
         isFilterVisible = false
      }
      if shouldShow {
         Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard isSearchVisible else { return }
            isSearchFieldFocused = true
         }
      } else {
         isSearchFieldFocused = false
      }
   }

   private func toggleFilterPanel() {
      HapticFeedbackService.play(.reveal)
      let shouldShow = !isFilterVisible
      withAnimation(AppAnimation.snappyStandard) {
         isUtilityTrayPresented = true
         isFilterVisible = shouldShow
         if shouldShow {
            isSearchVisible = false
         }
      }
      if shouldShow {
         isSearchFieldFocused = false
      }
   }

   private func toggleUtilityTray() {
      HapticFeedbackService.play(.selection)
      if isUtilityTrayVisible {
         isSearchFieldFocused = false
         withAnimation(AppAnimation.snappyStandard) {
            isUtilityTrayPresented = false
            isSearchVisible = false
            isFilterVisible = false
         }

         if isBulkEditing {
            setSelectionMode(active: false)
         }
      } else {
         withAnimation(AppAnimation.snappyStandard) {
            isUtilityTrayPresented = true
         }
      }
   }

   private func seedIfNeeded() {
      guard scopedTags.isEmpty else {
         defaultTagSeedVersion = 1
         return
      }

      let work = Tag(name: "work", ownerUserID: visibleOwnerUserID)
      let personal = Tag(name: "personal", ownerUserID: visibleOwnerUserID)
      let shopping = Tag(name: "shopping", ownerUserID: visibleOwnerUserID)
      context.insert(work)
      context.insert(personal)
      context.insert(shopping)

      do {
         try context.save()
         defaultTagSeedVersion = 1
         SyncCoordinator.shared.scheduleLocalSync()
      } catch {
         AppLog.error("Failed to seed default tags: \(error)", logger: AppLog.app)
      }
   }

   private func persistChanges(_ message: String) {
      do {
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         SyncCoordinator.shared.scheduleLocalSync()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context)
         LocationReminderService.shared.syncMonitoring(for: scopedToDos)

         WatchConnectivityService.shared.refreshSnapshot()
      } catch {
         AppLog.error("\(message): \(error)", logger: AppLog.app)
      }
   }

   private func removeCalendarMirrorIfPresent(for toDo: ToDo) {
      guard toDo.calendarEventIdentifier != nil else { return }

      do {
         try CalendarIntegrationService.shared.removeCalendarEvent(for: toDo)
      } catch {
         AppLog.error("Failed to remove mirrored Calendar event: \(error)", logger: AppLog.calendar)
      }
   }

   private func syncCalendarMirrorIfNeeded(for toDo: ToDo) {
      Task { @MainActor in
         do {
            if UserDefaults.standard.bool(forKey: AppPreferences.Keys.mirrorDueDatesToCalendar),
               toDo.isActive {
               try await CalendarIntegrationService.shared.syncCalendarEvent(for: toDo)
            } else if toDo.calendarEventIdentifier != nil {
               try CalendarIntegrationService.shared.removeCalendarEvent(for: toDo)
            }

            try context.save()
         } catch {
            AppLog.error("Calendar mirror failed: \(error.localizedDescription)", logger: AppLog.calendar)
         }
      }
   }

   private func refreshToDos() async {
      await SyncCoordinator.shared.refreshFromRemote(userID: supabaseAuthStore.currentUserID)
      await NotificationManager.shared.syncScheduledNotifications()
      #if canImport(WatchConnectivity) && os(iOS)
      await MainActor.run {
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context)
         WatchConnectivityService.shared.refreshSnapshot()
      }
      #endif
   }
}

private struct AddToDoPlusMark: View {
   let size: CGFloat
   let thickness: CGFloat
   @Environment(\.colorScheme) private var colorScheme

   var body: some View {
      ZStack {
         Rectangle()
            .fill(AppColor.brandYellowForeground(for: colorScheme))
            .frame(width: size, height: thickness)

         Rectangle()
            .fill(AppColor.brandYellowForeground(for: colorScheme))
            .frame(width: thickness, height: size)
      }
      .frame(width: size, height: size)
   }
}
