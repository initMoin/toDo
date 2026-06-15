import SwiftUI
import SwiftData

struct ArchivesView: View {
   @Environment(\.modelContext) private var context
   @Environment(\.dismiss) private var dismiss
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass
   @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
   @Query private var toDos: [ToDo]
   @State private var isShowingPurgeConfirmation = false
   @State private var editingArchivedToDo: ToDo?
   @State private var isSelectionMode = false
   @State private var selectedToDoIDs = Set<PersistentIdentifier>()

   private var contentMaxWidth: CGFloat {
      horizontalSizeClass == .regular ? 760 : .infinity
   }

   var body: some View {
      ZStack(alignment: .top) {
         ScrollView {
            VStack(alignment: .leading, spacing: 24) {
               if isArchivesEmpty {
                  archiveSection("Archives") {
                     Text("No completed or archived toDōs")
                        .foregroundStyle(AppColor.textSecondary)
                  }
               } else {
                  if !completedToDos.isEmpty {
                     archiveSection("Completed") {
                        ForEach(Array(completedToDos.enumerated()), id: \.element.id) { index, toDo in
                           archivedToDoRow(toDo)

                           if index < completedToDos.count - 1 {
                              Divider()
                           }
                        }
                     }
                  }

                  if !archivedToDos.isEmpty {
                     archiveSection("Archived") {
                        ForEach(Array(archivedToDos.enumerated()), id: \.element.id) { index, toDo in
                           archivedToDoRow(toDo)

                           if index < archivedToDos.count - 1 {
                              Divider()
                           }
                        }
                     }
                  }
               }

               Color.clear
                  .frame(height: 116)
            }
            .frame(maxWidth: contentMaxWidth, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 16)
            .padding(.top, 86)
            .padding(.bottom, 24)
         }

         pinnedTitleHeader
      }
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .overlay(alignment: .bottom) {
         if isSelectionMode {
            bulkActionBar
               .transition(.move(edge: .bottom).combined(with: .opacity))
         } else {
            bottomPurgeBar
               .transition(.move(edge: .bottom).combined(with: .opacity))
         }
      }
      .tint(AppColor.actionPrimary)
      .animation(AppAnimation.snappyStandard, value: isSelectionMode)
      .appBaseTypography()
      .appNavigationChrome()
      .confirmationDialog("Purge all completed and archived toDōs?", isPresented: $isShowingPurgeConfirmation, titleVisibility: .visible) {
         Button("Purge Archives", role: .destructive) {
            purgeArchives()
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("This permanently deletes every completed and archived toDō.")
      }
      .sheet(item: $editingArchivedToDo) { toDo in
         ToDoView(
            mode: .edit(toDo, context: .sheet),
            onFinish: { _ in
               editingArchivedToDo = nil
            }
         )
         .presentationDetents([.large])
         .presentationDragIndicator(.visible)
      }
   }

   private var pinnedTitleHeader: some View {
      AppSettingsDetailHeader(title: "Archives") {
            if !isArchivesEmpty {
               Button {
                  withAnimation(AppAnimation.snappyStandard) {
                     isSelectionMode.toggle()
                     if !isSelectionMode { selectedToDoIDs.removeAll() }
                  }
               } label: {
                  Label(isSelectionMode ? "Done" : "Select", systemImage: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                     .font(.appBodyStrong(15, relativeTo: .headline))
                     .foregroundStyle(AppColor.headerForeground(for: colorScheme))
               }
               .buttonStyle(.plain)
            }
      }
   }

   private var visibleOwnerUserID: UUID? {
      guard supabaseAuthStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return supabaseAuthStore.scopedOwnerUserID
   }

   private var scopedToDos: [ToDo] {
      toDos.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var completedToDos: [ToDo] {
      scopedToDos
         .filter { $0.lifecycleState == .done && !$0.isArchived }
         .sorted { $0.syncUpdatedAt > $1.syncUpdatedAt }
   }

   private var archivedToDos: [ToDo] {
      scopedToDos
         .filter { $0.lifecycleState == .archived || $0.isArchived }
         .sorted { $0.syncUpdatedAt > $1.syncUpdatedAt }
   }

   private var isArchivesEmpty: Bool {
      completedToDos.isEmpty && archivedToDos.isEmpty
   }

   private func archiveSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(LocalizedStringKey(title))
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 14) {
            content()
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(
            AppColor.surfaceElevated,
            in: .rect(cornerRadius: 24)
         )
      }
   }

   private func archivedToDoRow(_ toDo: ToDo) -> some View {
      HStack(alignment: .top, spacing: 10) {
         if isSelectionMode {
            Image(systemName: selectedToDoIDs.contains(toDo.id) ? "checkmark.circle.fill" : "circle")
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(selectedToDoIDs.contains(toDo.id) ? AppColor.actionPrimary : AppColor.textSecondary)
               .padding(.top, 2)
         }

         VStack(alignment: .leading, spacing: 4) {
            Text(toDo.task)
               .foregroundStyle(AppColor.textPrimary)
               .lineLimit(2)

            if let dueDate = toDo.dueDate {
               Text(String(format: String(localized: "Due %@"), AppLocalization.dateString(dueDate)))
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
         }

         Spacer(minLength: 8)
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
      .onTapGesture {
         if isSelectionMode { toggleSelection(for: toDo) }
      }
      .swipeActions(edge: .leading, allowsFullSwipe: !isSelectionMode) {
         if !isSelectionMode {
            Button { restoreToActive(toDo) } label: { Label("Restore", systemImage: "arrow.uturn.backward.circle") }
               .tint(AppColor.actionPrimary)
         }
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectionMode) {
         if !isSelectionMode {
            Button { restoreWithEdits(toDo) } label: { Label("Restore with Edits", systemImage: "square.and.pencil") }
               .tint(AppColor.actionSecondary)

            Button(role: .destructive) { deleteToDo(toDo) } label: { Label("Delete", systemImage: "trash") }
         }
      }
   }

   private var purgeArchivesButton: some View {
      Button {
         isShowingPurgeConfirmation = true
      } label: {
         HStack(spacing: 12) {
            Image(systemName: "trash.fill")
               .font(.appDisplay(18, relativeTo: .headline))

            VStack(alignment: .leading, spacing: 2) {
               Text("Purge Archives")
                  .font(.appDisplay(18, relativeTo: .headline))
               Text("Permanently deletes all completed and archived toDōs.")
                  .font(.appBody(12, relativeTo: .caption))
                  .opacity(0.92)
            }

            Spacer()
         }
         .foregroundStyle(AppColor.onAction)
         .padding(.horizontal, 16)
         .padding(.vertical, 14)
         .frame(maxWidth: .infinity)
         .background(AppColor.actionDestructive, in: .rect(cornerRadius: 22))
      }
      .buttonStyle(.plain)
      .disabled(isArchivesEmpty)
      .opacity(isArchivesEmpty ? 0.45 : 1)
   }

   private var bottomPurgeBar: some View {
      VStack(spacing: 0) {
         purgeArchivesButton
            .padding(8)
            .containerShape(.rect(cornerRadius: 28))
            .background(
               AppColor.surfaceElevated,
               in: .rect(cornerRadius: 28)
            )
            .frame(maxWidth: contentMaxWidth)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
      }
   }

   private func purgeArchives() {
      guard !isArchivesEmpty else { return }
      HapticFeedbackService.play(.destructive)
      let allToPurge = completedToDos + archivedToDos
      for toDo in allToPurge {
         removeCalendarMirrorIfPresent(for: toDo)
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
         context.delete(toDo)
      }

      persistChanges("Failed to purge archived toDōs")
   }

   private func persistChanges(_ message: String) {
      do {
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         SyncCoordinator.shared.scheduleLocalSync()
      } catch {
         AppLog.error("\(message): \(error)", logger: AppLog.app)
      }
   }

   private func restoreToActive(_ toDo: ToDo) {
      HapticFeedbackService.play(.restored)
      withAnimation(AppAnimation.easeStandard) {
         toDo.transition(to: .active)
      }
      persistChanges("Failed to restore archived toDō")
   }

   private func restoreWithEdits(_ toDo: ToDo) {
      HapticFeedbackService.play(.restored)
      withAnimation(AppAnimation.easeStandard) {
         toDo.transition(to: .active)
      }
      persistChanges("Failed to restore archived toDō for editing")
      editingArchivedToDo = toDo
   }

   private func deleteToDo(_ toDo: ToDo) {
      HapticFeedbackService.play(.destructive)
      withAnimation(AppAnimation.easeFast) {
         toDo.trashedAt = Date()
         toDo.transition(to: .trashed)
      }
      removeCalendarMirrorIfPresent(for: toDo)
      persistChanges("Failed to delete archived toDō")
   }

   private func removeCalendarMirrorIfPresent(for toDo: ToDo) {
      guard toDo.calendarEventIdentifier != nil else { return }

      do {
         try CalendarIntegrationService.shared.removeCalendarEvent(for: toDo)
      } catch {
         AppLog.error("Failed to remove mirrored Calendar event: \(error)", logger: AppLog.calendar)
      }
   }

   private var bulkActionBar: some View {
      VStack(spacing: 0) {
         Divider()
         HStack(spacing: 0) {
            bulkActionButton(systemName: "arrow.uturn.backward.circle", label: "Restore", disabled: selectedToDoIDs.isEmpty) {
               restoreSelected()
            }
            bulkActionButton(systemName: "trash", label: "Delete", isDestructive: true, disabled: selectedToDoIDs.isEmpty) {
               deleteSelected()
            }
         }
         .padding(.vertical, 12)
         .background(AppColor.surface)
      }
      .frame(maxWidth: contentMaxWidth)
      .frame(maxWidth: .infinity)
   }

   private func bulkActionButton(systemName: String, label: String, isDestructive: Bool = false, disabled: Bool, action: @escaping () -> Void) -> some View {
      Button(action: action) {
         VStack(spacing: 5) {
            Image(systemName: systemName)
               .font(.appDisplay(20, relativeTo: .title2))
            Text(label)
               .font(.appDisplay(11, relativeTo: .caption))
         }
         .frame(maxWidth: .infinity)
         .foregroundStyle(isDestructive ? AppColor.actionDestructive : AppColor.textPrimary)
         .opacity(disabled ? 0.45 : 1)
      }
      .buttonStyle(.plain)
      .disabled(disabled)
   }

   private func toggleSelection(for toDo: ToDo) {
      HapticFeedbackService.play(.selection)
      if selectedToDoIDs.contains(toDo.id) {
         selectedToDoIDs.remove(toDo.id)
      } else {
         selectedToDoIDs.insert(toDo.id)
      }
   }

   private func restoreSelected() {
      guard !selectedToDoIDs.isEmpty else { return }
      HapticFeedbackService.play(.restored)
      withAnimation(AppAnimation.snappyStandard) {
         let toDosToRestore = scopedToDos.filter { selectedToDoIDs.contains($0.id) }
         for toDo in toDosToRestore {
            toDo.transition(to: .active)
         }
         selectedToDoIDs.removeAll()
         isSelectionMode = false
      }
      persistChanges("Failed to restore selected")
   }

   private func deleteSelected() {
      guard !selectedToDoIDs.isEmpty else { return }
      HapticFeedbackService.play(.destructive)
      withAnimation(AppAnimation.easeFast) {
         let toDosToDelete = scopedToDos.filter { selectedToDoIDs.contains($0.id) }
         for toDo in toDosToDelete {
            toDo.trashedAt = Date()
            toDo.transition(to: .trashed)
            removeCalendarMirrorIfPresent(for: toDo)
         }
         selectedToDoIDs.removeAll()
         isSelectionMode = false
      }
      persistChanges("Failed to move selected to trash")
   }
}

#Preview {
   let container = PreviewSupport.makeModelContainer()
   NavigationStack {
      ArchivesView()
   }
   .modelContainer(container)
   .environmentObject(SupabaseAuthStore.preview)
}
