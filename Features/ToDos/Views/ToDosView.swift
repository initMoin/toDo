import SwiftUI
import SwiftData

struct ToDosView: View {
   @Environment(\.modelContext) private var context
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass
   @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
   @Query private var toDos: [ToDo]
   @Query private var tags: [Tag]
   @Query private var syncConflicts: [SyncConflict]

   @AppStorage(AppPreferences.Keys.tagSortOption) private var tagSortOption = TagSortOption.name.rawValue
   @AppStorage(AppPreferences.Keys.toDoListSortOption) private var toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
   @AppStorage(AppPreferences.Keys.toDoListSortReversed) private var isToDoListSortReversed = false
   @AppStorage(AppPreferences.Keys.doneSwipePrimaryAction) private var doneSwipePrimaryActionRaw = AppPreferences.DoneSwipePrimaryAction.archive.rawValue
   @AppStorage(AppPreferences.Keys.snoozeOptions) private var snoozeOptionsStorage = SnoozePreferences.defaultEncodedString
   @AppStorage(AppPreferences.Keys.appTimeSource) private var appTimeSourceRaw = AppTimeSource.location.rawValue
   @AppStorage(AppPreferences.Keys.locationTimeZoneIdentifier) private var locationTimeZoneIdentifier = AppTimePreferences.appleParkTimeZoneIdentifier
   @AppStorage("todo.defaultTagSeedVersion") private var defaultTagSeedVersion = 0

   @State private var selectedTagID: PersistentIdentifier?
   @State private var searchText = ""
   @State private var isSearchVisible = false
   @State private var isShowingNewToDo = false
   @State private var isShowingAccount = false
   @State private var isShowingSettings = false
   @State private var isShowingSyncReview = false
   @State private var isSelectionMode = false
   @State private var isShowingBulkTagPicker = false
   @State private var selectedToDoIDs = Set<PersistentIdentifier>()
   @State private var editingToDo: ToDo?
   @State private var isFilterVisible = false
   @State private var isUtilityTrayPresented = false
   @State private var isDoneDrawerExpanded = false
   @State private var expandedToDoID: PersistentIdentifier?
   @State private var inlineEditingToDoID: PersistentIdentifier?
   @State private var composerDetent = PresentationDetent.large//.fraction(0.92)
   @FocusState private var isSearchFieldFocused: Bool

   var body: some View {
      NavigationStack {
         ZStack(alignment: .bottomTrailing) {
            AppColor.surface
               .ignoresSafeArea()

            listContent
               .blur(radius: isInlineEditingDetail ? 5 : 0)
               .animation(AppAnimation.snappySection, value: isInlineEditingDetail)

            if filteredWorkingToDos.isEmpty && filteredDoneToDos.isEmpty {
               emptyStateOverlay
            }

            if !isBulkEditing && !filteredDoneToDos.isEmpty {
               doneDrawer
            }

            if !usesRegularWidthLayout {
               GeometryReader { proxy in
                  VStack(spacing: 0) {
                     Spacer(minLength: 0)

                     HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        composeButton(containerWidth: proxy.size.width)
                     }
                  }
               }
               .allowsHitTesting(!isComposeButtonSuppressed)
            }

            inlineDetailEditorOverlay
         }
         .navigationBarHidden(true)
         .sheet(isPresented: $isShowingBulkTagPicker) {
            BulkTagPickerView(
               selectedTagID: selectedTagID,
               tags: tagList,
               onApply: applyBulkTag,
               onClear: clearBulkTags
            )
         }
         .sheet(isPresented: composerSheetIsPresented) {
            composerSheetContent
               .presentationDetents([.large], selection: $composerDetent)
               .presentationDragIndicator(.visible)
               .presentationContentInteraction(.scrolls)
               .onAppear {
                  composerDetent = .large
               }
         }
         .sheet(isPresented: $isShowingAccount) {
            accountSheetContent
         }
         .sheet(isPresented: $isShowingSyncReview) {
            NavigationStack {
               SyncConflictReviewView(
                  conflicts: unresolvedSyncConflicts,
                  toDos: scopedToDos
               )
            }
         }
         .overlay {
            settingsOverlay
         }
         .task {
            guard defaultTagSeedVersion < 1 else { return }
            try? await Task.sleep(nanoseconds: 600_000_000)
            seedIfNeeded()
         }
      }
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
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
         regularPanelHeader(
            title: workingPanelTitle,
            count: filteredWorkingToDos.count,
            subtitle: activePanelSubtitle
         ) {
            regularNewToDoButton
         }

         Divider()
            .padding(.horizontal, 20)

         regularPanelList {
            toDoSections(workingSections, allowsOpen: !isSelectionMode, allowsStateActions: !isSelectionMode)
         }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(Color.white, in: .rect(cornerRadius: 30))
      .shadow(color: AppColor.black.opacity(0.05), radius: 18, x: 0, y: 8)
   }

   private var regularDetailPanel: some View {
      VStack(alignment: .leading, spacing: 0) {
         regularPanelHeader(
            title: "Details",
            count: selectedDetailToDo == nil ? 0 : 1,
            subtitle: detailPanelSubtitle
         ) {
            if selectedDetailToDo != nil {
               Button {
                  dismissSelectedDetail()
               } label: {
                  Image(systemName: "xmark")
                     .font(.appBodyStrong(13, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
                     .frame(width: 32, height: 32)
                     .contentShape(Circle())
               }
               .buttonStyle(.plain)
               .accessibilityLabel("Dismiss details")
            }
         }

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
      .background(Color.white, in: .rect(cornerRadius: 30))
      .shadow(color: AppColor.black.opacity(0.05), radius: 18, x: 0, y: 8)
      .animation(AppAnimation.snappySection, value: expandedToDoID)
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
               .shadow(color: AppColor.black.opacity(0.16), radius: 34, x: 0, y: 18)
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

         Text("Select a ToDo")
            .font(.appHeadline(20, relativeTo: .title3))
            .foregroundStyle(AppColor.textPrimary)

         Text("Details, notes, tags, reminders, and NanoDos appear here when a ToDo has more to show.")
            .font(.appBody(14, relativeTo: .body))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(22)
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
                     .foregroundStyle(AppColor.white)
                     .padding(.horizontal, 9)
                     .padding(.vertical, 5)
                     .background(Color(red: 180 / 255, green: 0, blue: 0), in: Capsule())
               }
            }
         }

         VStack(alignment: .leading, spacing: 9) {
            if let dueDate = toDo.dueDate {
               toDoDetailInfoRow(
                  systemName: "calendar",
                  title: "Due",
                  value: dueDate.formatted(date: .abbreviated, time: .shortened)
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
               value: toDo.syncUpdatedAt.formatted(date: .abbreviated, time: .shortened)
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
                  .font(.appBody(14, relativeTo: .body))
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

         Button {
            beginInlineDetailEdit(toDo)
         } label: {
            Label("Edit ToDo", systemImage: "arrow.up.right.circle.fill")
               .font(.appBodyStrong(14, relativeTo: .subheadline))
               .frame(maxWidth: .infinity)
               .padding(.vertical, 12)
               .foregroundStyle(AppColor.onAction)
               .background(AppColor.actionPrimary, in: Capsule())
         }
         .buttonStyle(.plain)
         .padding(.top, 2)
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
            Text(title)
               .font(.appBodyStrong(11, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)

            Text(value)
               .font(.appBodyStrong(14, relativeTo: .footnote))
               .foregroundStyle(AppColor.textPrimary)
               .fixedSize(horizontal: false, vertical: true)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(AppColor.surfaceMuted.opacity(0.7), in: .rect(cornerRadius: 16))
   }

   private func toDoDetailSection<Content: View>(
      title: String,
      systemName: String,
      @ViewBuilder content: () -> Content
   ) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Label(title, systemImage: systemName)
            .font(.appBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)

         content()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(AppColor.surfaceMuted.opacity(0.55), in: .rect(cornerRadius: 18))
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
      }
   }

   private func regularPanelHeader<Accessory: View>(
      title: String,
      count: Int,
      subtitle: String,
      @ViewBuilder accessory: () -> Accessory
   ) -> some View {
      HStack(alignment: .center, spacing: 14) {
         VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
               Text(title)
                  .font(.appHeadline(22, relativeTo: .title3))
                  .foregroundStyle(AppColor.textPrimary)

               Text("\(count)")
                  .font(.appBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textPrimary)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(AppColor.surfaceMuted, in: Capsule())
            }

            Text(subtitle)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
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
      count: Int,
      subtitle: String
   ) -> some View {
      regularPanelHeader(title: title, count: count, subtitle: subtitle) {
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
      .animation(AppAnimation.snappySection, value: filteredDoneToDos.map(\.id))
      .animation(AppAnimation.snappySection, value: expandedToDoID)
      .animation(AppAnimation.snappySection, value: workingListAnimationKey)
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color.clear)
   }

   private var regularNewToDoButton: some View {
      Button {
         openNewToDoComposer()
      } label: {
         Label("New ToDo", systemImage: "plus")
            .font(.appBodyStrong(14, relativeTo: .subheadline))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(AppColor.onAction)
            .background(AppColor.actionPrimary, in: Capsule())
      }
      .buttonStyle(.plain)
      .disabled(isComposeButtonSuppressed)
      .opacity(isComposeButtonSuppressed ? 0.42 : 1)
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
      .animation(AppAnimation.snappySection, value: filteredDoneToDos.map(\.id))
      .animation(AppAnimation.snappySection, value: expandedToDoID)
      .animation(AppAnimation.snappySection, value: workingListAnimationKey)
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(AppColor.surface)
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
      .animation(AppAnimation.snappySection, value: filteredDoneToDos.map(\.id))
      .animation(AppAnimation.snappySection, value: expandedToDoID)
      .background(AppColor.surface)
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
         Text(title)
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
            showsCompletedState: toDo.isDoneState,
            isExpanded: !usesRegularWidthLayout && expandedToDoID == toDo.id,
         onToggleDone: { isDone in
            updateCompletionState(for: toDo, isDone: isDone)
         },
         onToggleSelection: {
            toggleSelection(for: toDo.id)
         },
         onEdit: {
            if usesRegularWidthLayout {
               beginInlineDetailEdit(toDo)
            } else {
               openToDo(toDo)
            }
         },
         isTransitioningCompletion: false
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

         toggleExpansion(for: toDo)
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
         if !isComposerPresented {
            openNewToDoComposer()
         }
      } label: {
         Image(systemName: "plus")
            .font(.appDisplay(22, relativeTo: .headline))
      }
      .buttonStyle(
         AppCircleActionButtonStyle(
            intent: .proceed,
            size: 56
         )
      )
      .disabled(isComposeButtonSuppressed)
      .allowsHitTesting(!isComposeButtonSuppressed)
      .opacity(isComposeButtonSuppressed ? 0 : 1)
      .offset(y: isComposeButtonSuppressed ? 96 : 0)
      .animation(AppAnimation.snappySection, value: isComposeButtonSuppressed)
      .padding(.trailing, composeButtonTrailingPadding(containerWidth: containerWidth))
      .padding(.bottom, composeButtonBottomPadding)
   }

   @ViewBuilder
   private var composerSheetContent: some View {
      if let editingToDo {
         ToDoView(
            mode: .edit(editingToDo, context: .sheet),
            onFinish: { savedToDo in
               closeComposer(savedToDo: savedToDo)
            }
         )
      } else {
         ToDoView(
            mode: .create(preselectedTagID: selectedTagID),
            onFinish: { savedToDo in
               closeComposer(savedToDo: savedToDo)
            }
         )
      }
   }

   @ViewBuilder
   private var accountSheetContent: some View {
      if supabaseAuthStore.isAuthenticated {
         AccountView()
      } else {
         AuthenticationScreenView()
      }
   }

   private var isBulkEditing: Bool {
      isSelectionMode
   }

   private var isComposeButtonSuppressed: Bool {
      isSelectionMode || isDoneDrawerExpanded
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
      isBulkEditing ? 900 : 1240
   }

   private var regularDashboardCurrentMaxWidth: CGFloat {
      guard !isBulkEditing else { return regularDashboardMaxWidth }
      return isRegularDetailPanelVisible ? regularDashboardMaxWidth : regularContentMaxWidth
   }

   private var regularWorkingPanelMaxWidth: CGFloat {
      isBulkEditing ? 900 : regularContentMaxWidth
   }

   private var regularDetailPanelWidth: CGFloat {
      420
   }

   private var regularDashboardBottomPadding: CGFloat {
      guard !isBulkEditing else { return 0 }
      return filteredDoneToDos.isEmpty ? 24 : 94
   }

   private var regularPanelSpacing: CGFloat {
      20
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
      isBulkEditing ? "Selecting" : "ToDos"
   }

   private var activePanelSubtitle: String {
      if isBulkEditing {
         return selectedToDoIDs.isEmpty ? "Choose what to update together." : "\(selectedToDoIDs.count) selected"
      }
      return hasActiveFilters ? "Filtered active work." : "Active work, grouped around what matters now."
   }

   private var detailPanelSubtitle: String {
      "Tap a ToDo to inspect what belongs to it."
   }

   private var accountToolbarSymbol: String {
      supabaseAuthStore.isAuthenticated ? "person.crop.circle.fill" : "person.badge.key"
   }

   private var accountToolbarLabel: String {
      supabaseAuthStore.isAuthenticated ? "Open account" : "Open sign in"
   }

   private var listBottomSpacerHeight: CGFloat {
      if isBulkEditing {
         return 88
      }

      if !filteredDoneToDos.isEmpty {
         return 104
      }

      return 88
   }

   private var selectedTag: Tag? {
      tagList.first { $0.id == selectedTagID }
   }

   private var visibleOwnerUserID: UUID? {
      guard supabaseAuthStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return supabaseAuthStore.currentUserID
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

   private var workingListIdentity: String {
      "working:\(sortOption.rawValue):\(isToDoListSortReversed):\(String(describing: selectedTagID))"
   }

   private var doneListIdentity: String {
      "done:\(sortOption.rawValue):\(isToDoListSortReversed)"
   }

   private var workingListAnimationKey: String {
      "working-animation:\(sortOption.rawValue):\(isToDoListSortReversed):\(String(describing: selectedTagID))"
   }

   private var isUtilityTrayVisible: Bool {
      isUtilityTrayPresented || isSearchVisible || isFilterVisible || isBulkEditing
   }

   private var headerPanelTransition: AnyTransition {
      .offset(y: -12).combined(with: .opacity)
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
            Text("ToD\(Text("ō").foregroundStyle(AppColor.main))")
            .font(.appDisplay(headerTitleFontSize, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)

            HStack {
               HStack(spacing: 10) {
                  toolbarButton(
                     systemName: accountToolbarSymbol,
                     label: accountToolbarLabel,
                     isToggled: false
                  ) {
                     openAccountSheet()
                  }

                  toolbarButton(systemName: "gearshape", label: "Open settings", isToggled: false) {
                     openSettingsPanel()
                  }
               }

               Spacer(minLength: 12)

               toolbarButton(
                  systemName: "slider.horizontal.3",
                  label: isUtilityTrayVisible ? "Hide utilities" : "Show utilities",
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
                  isToggled: isSearchVisible
               ) {
                  toggleSearchPanel()
               }
               toolbarButton(
                  systemName: "line.3.horizontal.decrease.circle",
                  label: isFilterVisible ? "Hide filters" : "Show filters",
                  isToggled: isFilterVisible
               ) {
                  toggleFilterPanel()
               }
               toolbarButton(
                  systemName: isBulkEditing ? "checkmark.circle.fill" : "checkmark.circle",
                  label: isBulkEditing ? "Done selecting" : "Select items",
                  isToggled: isBulkEditing
               ) {
                  setSelectionMode(active: !isBulkEditing)
               }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(headerPanelTransition)
         }

         if isSearchVisible {
            searchField
               .transition(headerPanelTransition)
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
      .background(AppColor.surface)
   }

   private var syncNeedsReviewBanner: some View {
      Button {
         isShowingSyncReview = true
      } label: {
         HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
               .font(.appDisplay(14, relativeTo: .caption))
               .foregroundStyle(AppColor.secondary)

            Text(unresolvedSyncConflicts.count == 1
                 ? "Sync needs review: 1 ToDo changed in two places."
                 : "Sync needs review: \(unresolvedSyncConflicts.count) ToDos changed in two places.")
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
               bulkActionButton(systemName: "checkmark.circle.fill", label: "Complete", intent: .proceed, disabled: selectedToDoIDs.isEmpty) {
                  applyBulkCompletion(true)
               }
               bulkActionButton(systemName: "arrow.uturn.backward.circle", label: "Reopen", intent: .neutral, disabled: selectedToDoIDs.isEmpty) {
                  applyBulkCompletion(false)
               }
               bulkActionButton(systemName: "tag", label: "Tag", intent: .neutral, disabled: selectedToDoIDs.isEmpty) {
                  isShowingBulkTagPicker = true
               }
               bulkActionButton(systemName: "trash", label: "Delete", intent: .cancel, disabled: selectedToDoIDs.isEmpty) {
                  deleteSelected()
               }
               bulkActionButton(systemName: "xmark", label: "Cancel", intent: .neutral, disabled: false) {
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

   private var doneDrawer: some View {
      GeometryReader { proxy in
      let bottomInset = proxy.safeAreaInsets.bottom
      let expandedHeight = min(max(proxy.size.height * 0.33, 240), 340)
      let drawerWidth = doneDrawerWidth(for: proxy.size.width)

      VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 0) {
               Button {
                  withAnimation(AppAnimation.snappySection) {
                     isDoneDrawerExpanded.toggle()
                  }
               } label: {
                  doneDrawerHeader(bottomInset: bottomInset)
               }
               .buttonStyle(.plain)

               if isDoneDrawerExpanded {
                  Group {
                     if isRunningInPreview {
                        ScrollView {
                           LazyVStack(alignment: .leading, spacing: 0) {
                              previewToDoSections(doneSections, allowsOpen: true, allowsStateActions: true, showsContextMenu: false)

                              Color.clear
                                 .frame(height: max(bottomInset, 12))
                           }
                           .frame(maxWidth: contentMaxWidth, alignment: .center)
                           .frame(maxWidth: .infinity, alignment: .center)
                           .padding(.horizontal, listHorizontalInset)
                           .padding(.top, 4)
                        }
                        .id(doneListIdentity)
                     } else {
                        List {
                           toDoSections(doneSections, allowsOpen: true, allowsStateActions: true, showsContextMenu: false)

                           Color.clear
                              .frame(height: max(bottomInset, 12))
                              .listRowSeparator(.hidden)
                              .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                     }
                  }
                  .transition(.move(edge: .bottom).combined(with: .opacity))
               }
            }
         .frame(width: drawerWidth)
         .frame(height: isDoneDrawerExpanded ? expandedHeight + max(bottomInset, 10) : 48 + bottomInset, alignment: .top)
         .background {
            if !usesRegularWidthLayout {
               Rectangle().fill(.ultraThinMaterial)
            }
         }
         .clipShape(
            UnevenRoundedRectangle(
                  cornerRadii: .init(
                     topLeading: 30,
                     bottomLeading: usesRegularWidthLayout ? 30 : 0,
                     bottomTrailing: usesRegularWidthLayout ? 30 : 0,
                     topTrailing: 30
                  ),
                  style: .continuous
               )
         )
      }
         .frame(maxWidth: .infinity, alignment: .center)
         .ignoresSafeArea(edges: usesRegularWidthLayout ? [] : .bottom)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      .transition(.move(edge: .bottom).combined(with: .opacity))
      .animation(AppAnimation.snappySection, value: isDoneDrawerExpanded)
      .animation(AppAnimation.snappySection, value: filteredDoneToDos.map(\.id))
   }

   private func doneDrawerWidth(for containerWidth: CGFloat) -> CGFloat {
      guard usesRegularWidthLayout else { return containerWidth }
      return min(containerWidth - regularDashboardHorizontalPadding * 2, regularDashboardMaxWidth)
   }

   private func doneDrawerHeader(bottomInset: CGFloat) -> some View {
      VStack(spacing: 3) {
         HStack(spacing: 10) {
            Text("Done")
               .font(.appHeadline(20, relativeTo: .title3))
               .foregroundStyle(AppColor.textPrimary)

            Text("\(filteredDoneToDos.count)")
               .font(.appBodyStrong(13, relativeTo: .caption)).bold()
               .foregroundStyle(AppColor.textPrimary)
               .padding(.horizontal, 7.5)
               .padding(.vertical, 4.2)
               .background(
                  Group {
                     if !usesRegularWidthLayout {
                        Capsule()
                           .fill(AppColor.surfaceMuted)
                     }
                  }
               )
         }

         Image(systemName: "chevron.up")
            .font(.appBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
            .rotationEffect(.degrees(isDoneDrawerExpanded ? 180 : 0))
            .animation(AppAnimation.snappyStandard, value: isDoneDrawerExpanded)
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .contentShape(Rectangle())
      .padding(.horizontal, 24)
      .padding(.top, isDoneDrawerExpanded ? 14 : 8)
      .padding(.bottom, isDoneDrawerExpanded ? 12 : max(bottomInset, 6))
   }

   private var emptyStateOverlay: some View {
      VStack(spacing: 10) {
         Text(emptyStateTitle)
            .font(.appHeadline(20, relativeTo: .title3))
            .foregroundStyle(AppColor.main)
            .multilineTextAlignment(.center)

         Text(emptyStateSubtitle)
            .font(.appBody(15, relativeTo: .body))
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)

         Button(emptyStateActionTitle) {
            openNewToDoComposer()
         }
         .font(.appBodyStrong(15, relativeTo: .body))
         .foregroundStyle(AppColor.secondary)
         .buttonStyle(.plain)
      }
      .frame(maxWidth: usesRegularWidthLayout ? 420 : 340)
      .padding(.horizontal, 20)
      .padding(.vertical, 28)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .padding(.bottom, filteredDoneToDos.isEmpty ? 0 : 48)
      .allowsHitTesting(true)
   }

   private var emptyStateTitle: String {
      hasActiveFilters ? "No toDōs match this view." : "What’s worth doing today?"
   }

   private var emptyStateSubtitle: String {
      hasActiveFilters ? "Shift the filters or begin a fresh one." : "Start with your first ToDo."
   }

   private var emptyStateActionTitle: String {
      "Add ToDo"
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
         if toDo.isDoneState {
            switch doneSwipePrimaryAction {
            case .archive:
               Button {
                  archiveToDo(toDo)
               } label: {
                  Image(systemName: "archivebox")
               }
               .tint(AppColor.actionSecondary)

               Button(role: .destructive) {
                  deleteToDo(toDo)
               } label: {
                  Image(systemName: "trash")
               }
               .tint(.red)
            case .delete:
               Button(role: .destructive) {
                  deleteToDo(toDo)
               } label: {
                  Image(systemName: "trash")
               }
               .tint(.red)

               Button {
                  archiveToDo(toDo)
               } label: {
                  Image(systemName: "archivebox")
               }
               .tint(AppColor.actionSecondary)
            }
         } else {
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
               .fill(Color.white)

            TextField("Search toDos, notes, tags, nanoDos", text: $searchText)
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

   private func toolbarButton(systemName: String, label: String, isToggled: Bool, action: @escaping () -> Void) -> some View {
      Button(action: action) {
         Image(systemName: systemName)
            .font(.appDisplay(16, relativeTo: .subheadline))
            .contentTransition(.symbolEffect(.replace))
            .animation(AppAnimation.easeStandard, value: systemName)
      }
      .buttonStyle(AppToolbarToggleButtonStyle(isToggled: isToggled, size: 34))
      .accessibilityLabel(label)
   }

   private func bulkActionButton(
      systemName: String,
      label: String,
      intent: AppActionIntent,
      disabled: Bool,
      action: @escaping () -> Void
   ) -> some View {
      VStack(spacing: 5) {
         Button(action: action) {
            Image(systemName: systemName)
               .font(.appDisplay(14, relativeTo: .caption))
         }
         .buttonStyle(AppCircleActionButtonStyle(intent: intent, size: 34))
         .interactionDisabled(disabled)

         Text(label)
            .font(.appDisplay(11, relativeTo: .caption))
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
               .font(.appDisplay(12, relativeTo: .caption))
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
            .font(.appDisplay(12, relativeTo: .caption))
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
         Text(title)
            .font(.appDisplay(12, relativeTo: .caption))
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
            Text(title)
               .font(.appDisplay(13, relativeTo: .subheadline))

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
      .background(
         Capsule()
            .fill(isSelected ? AppColor.actionSecondary : AppColor.surfaceMuted)
      )
      .overlay(
         Capsule()
            .stroke(isSelected ? AppColor.actionSecondary : AppColor.border.opacity(0.4), lineWidth: 1)
      )
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
      switch option {
      case .name:
         return scopedTags.sorted { lhs, rhs in
            let compare = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if compare == .orderedSame {
               return lhs.createdAt > rhs.createdAt
            }
            return isAscending ? compare == .orderedAscending : compare == .orderedDescending
         }
      case .created:
         return scopedTags.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
               return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return isAscending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
         }
      case .linked:
         return scopedTags.sorted { lhs, rhs in
            let leftCount = linkedCount(for: lhs)
            let rightCount = linkedCount(for: rhs)
            if leftCount == rightCount {
               return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return isAscending ? leftCount < rightCount : leftCount > rightCount
         }
      }
   }

   private func linkedCount(for tag: Tag) -> Int {
      let toDoCount = scopedToDos.filter { toDo in
         toDo.effectiveTags.contains(where: { $0.id == tag.id })
      }.count
      let nanoDoCount = tag.allNanoDos.count
      return toDoCount + nanoDoCount
   }

   private var filteredWorkingToDos: [ToDo] {
      visibleToDos(in: [.active])
   }

   private var filteredDoneToDos: [ToDo] {
      visibleToDos(in: [.done])
   }

   private var workingSections: [ToDoListSection] {
      groupedVisibleToDos(in: [.active])
   }

   private var doneSections: [ToDoListSection] {
      groupedVisibleToDos(in: [.done])
   }

   private func visibleToDos(in states: Set<ToDoState>) -> [ToDo] {
      groupedVisibleToDos(in: states).flatMap(\.toDos)
   }

   private func groupedVisibleToDos(in states: Set<ToDoState>) -> [ToDoListSection] {
      let searchFiltered = scopedToDos.filter { toDo in
         guard !toDo.isArchived, states.contains(toDo.lifecycleState) else { return false }
         guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
         let term = searchText.lowercased()
         return toDo.task.lowercased().contains(term)
         || toDo.notes.lowercased().contains(term)
         || toDo.effectiveTags.contains(where: { $0.name.lowercased().contains(term) })
         || toDo.nanoDos.contains(where: { $0.task.lowercased().contains(term) })
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
         if let selectedTag {
            return [
               ToDoListSection(
                  key: "flat:\(AppPreferences.ToDoListSortOption.tag.rawValue):selected",
                  title: "",
                  toDos: applySortDirection(to: tagFiltered.sorted { lhs, rhs in
                     let leftHasTag = lhs.effectiveTags.contains(where: { $0.id == selectedTag.id })
                     let rightHasTag = rhs.effectiveTags.contains(where: { $0.id == selectedTag.id })
                     if leftHasTag != rightHasTag {
                        return leftHasTag
                     }
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
      let calendar = Calendar.current
      let grouped = Dictionary(grouping: toDos) { toDo -> Date? in
         guard let dueDate = toDo.dueDate else { return nil }
         return calendar.date(from: calendar.dateComponents([.year, .month], from: dueDate))
      }

      var sections = grouped.compactMap { key, value -> ToDoListSection? in
         let title: String
         if let key {
            title = key.formatted(.dateTime.year().month(.wide))
         } else {
            title = "No Due Date"
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
      selectedToDoIDs.forEach { id in
         if let toDo = scopedToDos.first(where: { $0.id == id }) {
            updateCompletionState(for: toDo, isDone: isDone)
         }
      }
      selectedToDoIDs.removeAll()
   }

   private func updateCompletionState(for toDo: ToDo, isDone: Bool) {
      if isDone {
         withAnimation(AppAnimation.snappySection) {
            expandedToDoID = nil
            toDo.transition(to: .done)
         }
      } else {
         withAnimation(AppAnimation.snappyStandard) {
            expandedToDoID = nil
            toDo.transition(to: .active)
         }
      }

      persistChanges("Failed to update ToDo completion state")
   }

   private func deleteSelected() {
      selectedToDoIDs.forEach { id in
         if let toDo = scopedToDos.first(where: { $0.id == id }) {
            deleteToDo(toDo)
         }
      }
      selectedToDoIDs.removeAll()
   }

   private var doneSwipePrimaryAction: AppPreferences.DoneSwipePrimaryAction {
      AppPreferences.DoneSwipePrimaryAction(rawValue: doneSwipePrimaryActionRaw) ?? .archive
   }

   private func archiveToDo(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeStandard) {
         if expandedToDoID == toDo.id {
            expandedToDoID = nil
         }
         toDo.transition(to: .archived)
      }
      persistChanges("Failed to archive ToDo")
   }

   private func deleteToDo(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeFast) {
         if expandedToDoID == toDo.id {
            expandedToDoID = nil
         }
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
         context.delete(toDo)
      }
      persistChanges("Failed to delete ToDo")
   }

   private func snoozeMenu(for toDo: ToDo) -> some View {
      Menu {
         ForEach(SnoozeUnit.allCases) { unit in
            let values = snoozeOptions.values(for: unit)
            if !values.isEmpty {
               Menu(unit.title) {
                  ForEach(values, id: \.self) { value in
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
      persistChanges("Failed to snooze ToDo")
   }

   private func applyBulkTag(_ tag: Tag) {
      selectedToDoIDs.forEach { id in
         if let toDo = scopedToDos.first(where: { $0.id == id }) {
            if toDo.effectiveTags.contains(where: { $0.id == tag.id }) { return }
            var updatedTags = toDo.effectiveTags
            guard updatedTags.count < ToDo.maxTagSelection else { return }
            updatedTags.append(tag)
            toDo.setSelectedTags(updatedTags)
         }
      }
      selectedToDoIDs.removeAll()
      persistChanges("Failed to apply bulk tag changes")
   }

   private func clearBulkTags() {
      selectedToDoIDs.forEach { id in
         if let toDo = scopedToDos.first(where: { $0.id == id }) {
            toDo.setSelectedTags([])
         }
      }
      selectedToDoIDs.removeAll()
      persistChanges("Failed to clear bulk tag changes")
   }

   private var hasActiveFilters: Bool {
      let hasSearch = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      return selectedTagID != nil || hasSearch || sortOption != .dueDate
   }

   private func clearFilters() {
      withAnimation(AppAnimation.snappySection) {
         selectedTagID = nil
         searchText = ""
         toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
         isToDoListSortReversed = false
      }
   }

   private func closeComposer(savedToDo: ToDo? = nil) {
      withAnimation(AppAnimation.easeStandard) {
         isShowingNewToDo = false
         editingToDo = nil
         if usesRegularWidthLayout, let savedToDo {
            expandedToDoID = savedToDo.id
         }
      }
   }

   private func openToDo(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeStandard) {
         expandedToDoID = usesRegularWidthLayout ? toDo.id : nil
         inlineEditingToDoID = nil
         isShowingNewToDo = false
         editingToDo = toDo
      }
   }

   private func openNewToDoComposer() {
      editingToDo = nil
      withAnimation(AppAnimation.easeStandard) {
         isShowingNewToDo = true
      }
   }

   private func toggleExpansion(for toDo: ToDo) {
      withAnimation(AppAnimation.snappySection) {
         expandedToDoID = expandedToDoID == toDo.id ? nil : toDo.id
      }
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
      persistChanges("Failed to delete ToDo")
   }

   private var isComposerPresented: Bool {
      isShowingNewToDo || editingToDo != nil
   }

   private var composerSheetIsPresented: Binding<Bool> {
      Binding(
         get: { isComposerPresented },
         set: { shouldPresent in
            guard !shouldPresent else { return }
            isShowingNewToDo = false
            editingToDo = nil
         }
      )
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
      if selectedToDoIDs.contains(id) {
         selectedToDoIDs.remove(id)
      } else {
         selectedToDoIDs.insert(id)
      }
   }

   private func openSettingsPanel() {
      isShowingSettings = true
      isUtilityTrayPresented = false
      isSearchVisible = false
      isFilterVisible = false
      isSearchFieldFocused = false
   }

   private func openAccountSheet() {
      isShowingAccount = true
   }

   private func closeSettingsPanel() {
      isShowingSettings = false
   }

   private var settingsOverlay: some View {
      GeometryReader { proxy in
         let targetWidth = proxy.size.width * (usesRegularWidthLayout ? 0.48 : 0.86)
         let panelWidth = min(max(targetWidth, usesRegularWidthLayout ? 460 : 0), usesRegularWidthLayout ? 560 : 420)
         
         ZStack(alignment: .leading) {
            Color.black
               .opacity(isShowingSettings ? 0.33 : 0)
               .ignoresSafeArea()
               .transaction { transaction in
                  transaction.animation = nil
               }
               .onTapGesture {
                  if isShowingSettings {
                     closeSettingsPanel()
                  }
               }
            
            if isShowingSettings {
               SettingsView(onClose: closeSettingsPanel)
                  .frame(width: panelWidth)
                  .frame(maxHeight: .infinity)
                  .background(AppColor.surface)
                  .shadow(color: AppColor.black.opacity(0.14), radius: 14, x: 6, y: 0)
                  .transition(.move(edge: .leading).combined(with: .opacity))
                  .gesture(
                     DragGesture(minimumDistance: 18)
                        .onEnded { value in
                           if value.translation.width < -70 {
                              closeSettingsPanel()
                           }
                        }
                  )
            }
         }
         .animation(AppAnimation.snappyStandard, value: isShowingSettings)
         .allowsHitTesting(isShowingSettings)
      }
   }

   private func toggleSearchPanel() {
      let shouldShow = !isSearchVisible
      withAnimation(AppAnimation.snappyStandard) {
         isUtilityTrayPresented = true
         isSearchVisible = shouldShow
         if shouldShow {
            isFilterVisible = false
         }
      }
      if shouldShow {
         DispatchQueue.main.async {
            isSearchFieldFocused = true
         }
      } else {
         isSearchFieldFocused = false
      }
   }

   private func toggleFilterPanel() {
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
         print("Failed to seed default tags: \(error)")
      }
   }

   private func persistChanges(_ message: String) {
      do {
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         SyncCoordinator.shared.scheduleLocalSync()
      } catch {
         print("\(message): \(error)")
      }
   }
}

private struct RowContextMenuModifier<MenuContent: View>: ViewModifier {
   let isEnabled: Bool
   @ViewBuilder var menuContent: () -> MenuContent

   @ViewBuilder
   func body(content: Content) -> some View {
      if isEnabled {
         content.contextMenu(menuItems: menuContent)
      } else {
         content
      }
   }
}

private struct ToDoListSection: Identifiable {
   let key: String
   let title: String
   var sortDate: Date = .distantPast
   var sortCount: Int = 0
   let toDos: [ToDo]

   var id: String { key }
}

private struct TagSectionKey: Hashable {
   let key: String
   let title: String
}

private struct ToDoRowView: View {
   @ScaledMetric(relativeTo: .headline) private var leadingCircleSymbolSize: CGFloat = 20
   @State private var titleFirstLineHeight: CGFloat = 0
   @State private var isOverduePulseActive = false
   @State private var expandedContentHeight: CGFloat = 0

   let toDo: ToDo
   let allowsCompletionToggle: Bool
   let isSelectionMode: Bool
   let isSelected: Bool
   let isDetailSelected: Bool
   let hasSyncConflict: Bool
   let showsCompletedState: Bool
   let isExpanded: Bool
   let onToggleDone: (Bool) -> Void
   let onToggleSelection: () -> Void
   let onEdit: () -> Void
   let isTransitioningCompletion: Bool

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         primaryRowContent
            .zIndex(1)

         expandedDetailsContainer
            .zIndex(0)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 12)
      .opacity(rowOpacity)
      .containerShape(.rect(cornerRadius: 18))
      .background(
         rowBackgroundColor,
         in: .rect(cornerRadius: 18)
      )
      .overlay(alignment: .topLeading) {
         expandedDetailsMeasurement
      }
      .compositingGroup()
      .animation(AppAnimation.easeFast, value: isSelected)
      .animation(AppAnimation.easeStandard, value: isTransitioningCompletion)
      .animation(AppAnimation.easeStandard, value: showsCompletedState)
      .animation(AppAnimation.snappySection, value: isExpanded)
      .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isOverduePulseActive)
      .onAppear {
         syncOverduePulse()
      }
      .onChange(of: toDo.isLate) { _, _ in
         syncOverduePulse()
      }
   }

   private var primaryRowContent: some View {
      HStack(alignment: .top, spacing: 12) {
         Button {
            if isSelectionMode {
               onToggleSelection()
            } else {
               guard allowsCompletionToggle else { return }
               onToggleDone(!showsCompletedState)
            }
         } label: {
            Image(systemName: leadingCircleSymbol)
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(leadingCircleColor)
               .frame(width: leadingCircleSymbolSize, height: leadingCircleSymbolSize)
         }
         .buttonStyle(.plain)
         .padding(.top, leadingCircleTopPadding)

         VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
               Text(toDo.task)
                  .font(.appDisplay(22, relativeTo: .headline))
                  .foregroundStyle(taskTextColor)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(firstLineHeightProbe)

               if let primaryTag {
                  HStack(spacing: 6) {
                     Text(primaryTag.displayName)
                        .font(.appAccent(14, relativeTo: .caption))
                        .foregroundStyle(tagTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                           Capsule()
                              .fill(tagBackgroundColor)
                        )

                     if additionalTagCount > 0 {
                        Text("+\(additionalTagCount)")
                           .font(.appAccent(11, relativeTo: .caption))
                           .foregroundStyle(metadataColor)
                     }
                  }
                  .fixedSize(horizontal: true, vertical: false)
               }

               if hasSyncConflict {
                  Image(systemName: "exclamationmark.triangle.fill")
                     .font(.appBodyStrong(13, relativeTo: .caption))
                     .foregroundStyle(syncConflictColor)
                     .padding(.horizontal, 7)
                     .padding(.vertical, 4)
                     .background(
                        Capsule()
                           .fill(syncConflictColor.opacity(isOverdueStylingActive ? 1 : 0.12))
                     )
                     .accessibilityLabel("Sync needs review")
               }
            }

            if hasMetadata {
               HStack(spacing: 12) {
                  if nanoDoCount > 0 {
                     nanoDoCountBadge
                  }

                  if toDo.dueDate != nil {
                     Image(systemName: "calendar")
                        .accessibilityLabel("Has due date")
                  }
               }
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(metadataColor)
            }
         }
      }
   }

   private var expandedDetailsContainer: some View {
      Color.clear
         .frame(height: isExpanded ? expandedContentHeight : 0)
         .overlay(alignment: .top) {
            expandedDetails
               .offset(y: isExpanded ? 0 : -(expandedContentHeight * 0.16 + 10))
               .opacity(isExpanded ? 1 : 0.01)
               .frame(height: isExpanded ? expandedContentHeight : 0, alignment: .top)
               .clipped()
               .allowsHitTesting(isExpanded)
         }
   }

   private var expandedDetails: some View {
      VStack(alignment: .leading, spacing: 12) {
         VStack(alignment: .leading, spacing: 8) {
            if let dueDate = toDo.dueDate {
               expandedDetailRow(
                  systemName: "calendar",
                  title: "Due",
                  value: dueDate.formatted(date: .abbreviated, time: .shortened)
               )
            }

            expandedDetailRow(
               systemName: reminderIntentSystemName,
               title: "Reminder",
               value: toDo.reminderIntent.title
            )

            if let recurrenceSummary = toDo.recurrenceSummary {
               expandedDetailRow(
                  systemName: "arrow.clockwise",
                  title: "Repeat",
                  value: recurrenceSummary
               )
            }

            if !effectiveTags.isEmpty {
               expandedDetailRow(
                  systemName: "tag",
                  title: "Tags",
                  value: effectiveTags.map(\.displayName).joined(separator: " • ")
               )
            }
         }

         if !toDo.nanoDos.isEmpty {
            expandedLongformSection(title: "NanoDos", systemName: "smallcircle.filled.circle") {
               VStack(alignment: .leading, spacing: 7) {
                  ForEach(toDo.nanoDos) { nanoDo in
                     HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "arrow.right.circle"/*nanoDo.isDone ? "checkmark.circle.fill" : "circle"*/)
                           .font(.appBodyStrong(11, relativeTo: .caption))
                           .foregroundStyle(nanoDo.isDone ? AppColor.secondary : AppColor.textSecondary)

                        Text(nanoDo.task)
                           .font(.appBodyStrong(14, relativeTo: .footnote))
                           .foregroundStyle(expandedValueColor)
                           .strikethrough(nanoDo.isDone, color: expandedValueColor.opacity(0.4))
                     }
                  }
               }
            }
         }

         if !trimmedNotes.isEmpty {
            expandedLongformSection(title: "Notes", systemName: "note.text") {
               Text(trimmedNotes)
                  .font(.appBody(14, relativeTo: .footnote))
                  .foregroundStyle(expandedValueColor)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         HStack {
            Spacer(minLength: 0)

            Button(action: onEdit) {
               Image(systemName: "arrow.up.right.circle.fill")
                  .font(.appBodyStrong(23, relativeTo: .caption))
                  .foregroundStyle(/*expandedActionColor*/AppColor.actionNeutral)
                  .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
         }
      }
      .padding(12)
      .background(
         expandedPanelBackground,
         in: .rect(cornerRadius: 16)
      )
      .padding(.leading, leadingCircleSymbolSize + 12)
      .padding(.top, 4)
      .contentTransition(.opacity)
   }

   private var expandedDetailsMeasurement: some View {
      expandedDetails
         .fixedSize(horizontal: false, vertical: true)
         .opacity(0.001)
         .allowsHitTesting(false)
         .accessibilityHidden(true)
         .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
         } action: { value in
            if abs(expandedContentHeight - value) > 0.5 {
               expandedContentHeight = value
            }
         }
   }

   private var taskTextColor: Color {
      if isDetailSelected {
         return AppColor.textPrimary
      }
      guard isOverdueStylingActive else { return AppColor.textPrimary }
      return AppColor.white
   }

   private var metadataColor: Color {
      if isDetailSelected {
         return AppColor.textPrimary.opacity(0.68)
      }
      guard isOverdueStylingActive else { return AppColor.textSecondary }
      return AppColor.white.opacity(0.86)
   }

   private var tagTextColor: Color {
      if isDetailSelected {
         return AppColor.textPrimary
      }
      guard isOverdueStylingActive else { return AppColor.textPrimary }
      return overdueAccentColor
   }

   private var tagBackgroundColor: Color {
      if isDetailSelected {
         return Color.white.opacity(0.5)
      }
      guard isOverdueStylingActive else { return AppColor.surfaceMuted }
      return AppColor.white
   }

   private var syncConflictColor: Color {
      isOverdueStylingActive ? overdueAccentColor : AppColor.secondary
   }

   private var rowBackgroundColor: Color {
      if isSelectionMode && isSelected {
         return isOverdueStylingActive ? overdueSurfaceColor : AppColor.actionSecondary.opacity(0.1)
      }
      if isDetailSelected {
         return AppColor.main
      }
      return isOverdueStylingActive ? overdueSurfaceColor : Color.white
   }

   private var rowOpacity: Double {
      if isDetailSelected {
         return 1
      }
      guard showsCompletedState else { return 1 }
      return isExpanded ? 0.64 : 0.22
   }

   private var expandedPanelBackground: Color {
      Color.white
   }

   private var expandedActionColor: Color {
      AppColor.secondary
   }

   private var overdueSurfaceColor: Color {
      let base = Color(red: 180 / 255, green: 0, blue: 0)
      let emphasized = Color(red: 160 / 255, green: 0, blue: 0)
      return isOverduePulseActive ? emphasized : base
   }

    private var overdueAccentColor: Color {
      let base = Color(red: 180 / 255, green: 0, blue: 0)
      let emphasized = Color(red: 160 / 255, green: 0, blue: 0)
      return isOverduePulseActive ? emphasized : base
   }

   private var isOverdueStylingActive: Bool {
      toDo.isLate && !showsCompletedState
   }

   private var leadingCircleTopPadding: CGFloat {
      max((titleFirstLineHeight - leadingCircleSymbolSize) / 2, 0)
   }

   private var firstLineHeightProbe: some View {
      Text(toDo.task)
         .font(.appDisplay(22, relativeTo: .headline))
         .lineLimit(1)
         .fixedSize(horizontal: false, vertical: true)
         .hidden()
         .background(
            GeometryReader { proxy in
               Color.clear
                  .preference(key: ToDoRowFirstLineHeightKey.self, value: proxy.size.height)
            }
         )
         .onPreferenceChange(ToDoRowFirstLineHeightKey.self) { value in
            titleFirstLineHeight = value
         }
   }

   private var leadingCircleSymbol: String {
      if isSelectionMode {
         return isSelected ? "checkmark.circle.fill" : "circle"
      }
      return showsCompletedState ? "checkmark.circle.fill" : "circle"
   }

   private var leadingCircleColor: Color {
      if isDetailSelected {
         return AppColor.textPrimary
      }
      if isOverdueStylingActive {
         return AppColor.white
      }
      if isSelectionMode {
         return AppColor.actionSecondary
      }
      return showsCompletedState ? AppColor.actionPrimary : AppColor.textSecondary
   }

   private var hasMetadata: Bool {
      toDo.dueDate != nil || !toDo.nanoDos.isEmpty
   }

   private var trimmedNotes: String {
      toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines)
   }

   private var nanoDoCount: Int {
      toDo.nanoDos.count
   }

   private var effectiveTags: [Tag] {
      toDo.effectiveTags
   }

   private var primaryTag: Tag? {
      effectiveTags.first
   }

   private var additionalTagCount: Int {
      max(effectiveTags.count - 1, 0)
   }

   private var completedNanoDoCount: Int {
      toDo.nanoDos.filter(\.isDone).count
   }

   private var nanoDoCountBadge: some View {
      ZStack {
         Circle()
            .fill(nanoDoBadgeFill)
            .frame(width: 20, height: 20)
            .overlay(
               Circle()
                  .stroke(AppColor.border, lineWidth: 0.8)
            )

         Text("\(nanoDoCount)")
            .font(.appBody(10, relativeTo: .caption2))
            .foregroundStyle(nanoDoBadgeTextColor)
      }
      .accessibilityLabel("\(nanoDoCount) nano tasks")
   }

   private var nanoDoBadgeFill: Color {
      if isOverdueStylingActive {
         return AppColor.white
      }
      guard nanoDoCount > 0 else { return AppColor.surfaceMuted }
      if completedNanoDoCount == nanoDoCount {
         return AppColor.actionSuccess.opacity(0.24)
      }
      if completedNanoDoCount > 0 {
         return AppColor.actionPrimary.opacity(0.18)
      }
      return AppColor.surfaceMuted
   }

   private var nanoDoBadgeTextColor: Color {
      guard isOverdueStylingActive else { return AppColor.textPrimary }
      return overdueAccentColor
   }

   private var reminderIntentSystemName: String {
      switch toDo.reminderIntent {
      case .soft:
         return "bell.badge"
      case .due:
         return "bell"
      case .timeSensitive:
         return "exclamationmark.circle"
      }
   }

   private func expandedDetailRow(systemName: String, title: String, value: String) -> some View {
      HStack(alignment: .center, spacing: 8) {
         Image(systemName: systemName)
            .font(.appBodyStrong(14, relativeTo: .caption))
            .foregroundStyle(expandedLabelColor)
            .frame(width: 14, alignment: .center)

         Text(title)
            .font(.appSubtitle(12, relativeTo: .caption))
            .foregroundStyle(expandedLabelColor)
            .frame(width: 56, alignment: .leading)

         Spacer(minLength: 10)

         Text(value)
            .font(.appBodyStrong(14, relativeTo: .footnote))
            .foregroundStyle(expandedValueColor)
            .multilineTextAlignment(.trailing)
      }
   }

   private func expandedLongformSection<Content: View>(title: String, systemName: String, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 7) {
         HStack(spacing: 8) {
            Image(systemName: systemName)
               .font(.appBodyStrong(14, relativeTo: .caption))
               .foregroundStyle(expandedLabelColor)
               .frame(width: 14, alignment: .center)

            Text(title)
               .font(.appSubtitle(14, relativeTo: .caption))
               .foregroundStyle(expandedLabelColor)
         }

         content()
            .padding(.leading, 22)
      }
   }

   private var expandedLabelColor: Color {
      AppColor.textSecondary
   }

   private var expandedValueColor: Color {
      AppColor.textPrimary
   }

   private func syncOverduePulse() {
      guard toDo.isLate, !showsCompletedState else {
         isOverduePulseActive = false
         return
      }

      guard !isOverduePulseActive else { return }
      isOverduePulseActive = true
   }
}

private struct ToDoRowFirstLineHeightKey: PreferenceKey {
   static var defaultValue: CGFloat = 0

   static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = nextValue()
   }
}

private enum PreviewContainerFactory {
   static func makeToDosViewContainer() -> ModelContainer {
      let container = PreviewSupport.makeModelContainer()
      let context = container.mainContext

      let work = Tag(name: "work")
      let personal = Tag(name: "personal")

      let sprint = ToDo(
         task: "Plan weekly sprints",
         notes: "neener neener",
         dueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now),
         tags: [work]
      )
      
      let reset = ToDo(
         task: "Reset home inbox",
         dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
         tags: [personal]
      )
      let outline = NanoDo(task: "Draft outline", toDo: sprint, tag: work)
      let review = NanoDo(task: "Review backlog", toDo: sprint, tag: work)
      sprint.nanoDos = [outline, review]

      context.insert(work)
      context.insert(personal)
      context.insert(sprint)
      context.insert(reset)
      context.insert(outline)
      context.insert(review)

      return container
   }
}

#Preview {
   ToDosView()
      .modelContainer(PreviewContainerFactory.makeToDosViewContainer())
      .environmentObject(SupabaseAuthStore.preview)
}

#Preview("iPad") {
   ToDosView()
      .modelContainer(PreviewContainerFactory.makeToDosViewContainer())
      .environmentObject(SupabaseAuthStore.preview)
      .environment(\.horizontalSizeClass, .regular)
      .frame(width: 1366, height: 1024)
}
