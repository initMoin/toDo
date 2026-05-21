//
//  TrashView.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/15/26.
//

import SwiftUI
import SwiftData

enum TrashAutoEmptyInterval: String, CaseIterable, Identifiable {
   case oneWeek = "1 Week"
   case twoWeeks = "2 Weeks"
   case oneMonth = "1 Month"
   case threeMonths = "3 Months"
   case never = "Never"
   
   var id: String { rawValue }
   var title: String { rawValue }
   
   var days: Int? {
      switch self {
      case .oneWeek: return 7
      case .twoWeeks: return 14
      case .oneMonth: return 30
      case .threeMonths: return 90
      case .never: return nil
      }
   }
}

struct TrashView: View {
   @Environment(\.modelContext) private var context
   @Environment(\.dismiss) private var dismiss
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @Query private var toDos: [ToDo]
   @AppStorage("trashAutoEmptyInterval") private var trashAutoEmptyIntervalRaw = TrashAutoEmptyInterval.oneMonth.rawValue
   @State private var isShowingEmptyTrashConfirmation = false
   @State private var isSelectionMode = false
   @State private var selectedToDoIDs = Set<PersistentIdentifier>()

   private var visibleOwnerUserID: UUID? {
      guard authStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return authStore.currentUserID
   }

   private var trashedToDos: [ToDo] {
      toDos
         .filter { $0.ownerUserID == visibleOwnerUserID && $0.lifecycleState == .trashed }
         .sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
   }

   private var resolvedInterval: TrashAutoEmptyInterval {
      TrashAutoEmptyInterval(rawValue: trashAutoEmptyIntervalRaw) ?? .oneMonth
   }

   var body: some View {
      ZStack(alignment: .top) {
         ScrollView {
            VStack(alignment: .leading, spacing: 24) {
               if trashedToDos.isEmpty {
                  emptyState
               } else {
                  VStack(alignment: .leading, spacing: 10) {
                     Text("Recently Deleted")
                        .font(.appSubtitle(15, relativeTo: .subheadline))
                        .foregroundStyle(AppColor.textPrimary)

                     VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(trashedToDos.enumerated()), id: \.element.id) { index, toDo in
                           trashRow(toDo)
                           if index < trashedToDos.count - 1 { Divider() }
                        }
                     }
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .padding(16)
                     .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
                  }
               }
               Color.clear.frame(height: 116)
            }
            .padding(.horizontal, 16)
            .padding(.top, 86)
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
            bottomActionbar
               .transition(.move(edge: .bottom).combined(with: .opacity))
         }
      }
      .animation(AppAnimation.snappyStandard, value: isSelectionMode)
      .appBaseTypography()
      .appNavigationChrome()
      .toolbar(.hidden, for: .navigationBar)
      .navigationBarBackButtonHidden()
      .onAppear {
         runRollingAutoEmpty()
      }
      .confirmationDialog("Empty Trash?", isPresented: $isShowingEmptyTrashConfirmation, titleVisibility: .visible) {
         Button("Empty Trash Now", role: .destructive) { emptyTrashNow() }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("This permanently deletes all items in the trash. This cannot be undone.")
      }
   }

   private var pinnedTitleHeader: some View {
      AppSettingsDetailHeader(title: "Trash") {
            if !trashedToDos.isEmpty {
               Button {
                  withAnimation(AppAnimation.snappyStandard) {
                     isSelectionMode.toggle()
                     if !isSelectionMode { selectedToDoIDs.removeAll() }
                  }
               } label: {
                  Text(isSelectionMode ? "Done" : "Select")
                     .font(.appBodyStrong(16, relativeTo: .headline))
                     .foregroundStyle(AppColor.white)
               }
               .buttonStyle(.plain)
            }
      }
   }

   private var emptyState: some View {
      VStack(spacing: 12) {
         Image(systemName: "trash")
            .font(.appDisplay(32, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.surfaceMuted)
         Text("Trash is empty.")
            .font(.appHeadline(20, relativeTo: .title3))
            .foregroundStyle(AppColor.textPrimary)
         Text("Items will be permanently deleted after \(resolvedInterval.title.lowercased()).")
            .font(.appBody(15, relativeTo: .body))
            .foregroundStyle(AppColor.textSecondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 64)
   }

   private func trashRow(_ toDo: ToDo) -> some View {
      HStack(alignment: .top, spacing: 12) {
         if isSelectionMode {
            Image(systemName: selectedToDoIDs.contains(toDo.id) ? "checkmark.circle.fill" : "circle")
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(selectedToDoIDs.contains(toDo.id) ? AppColor.actionPrimary : AppColor.textSecondary)
               .padding(.top, 2)
         }
         
         VStack(alignment: .leading, spacing: 6) {
            Text(toDo.task)
               .font(.appBodyStrong(16, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)
            
            Text(daysRemainingText(for: toDo))
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.actionDestructive)
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         
         if !isSelectionMode {
            Menu {
               Button("Restore") { restore(toDo) }
               Button("Delete Permanently", role: .destructive) { deletePermanently(toDo) }
            } label: {
               Image(systemName: "ellipsis")
                  .font(.appBodyStrong(14, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textSecondary)
                  .frame(width: 34, height: 34)
                  .background(AppColor.surfaceMuted, in: Circle())
            }
            .buttonStyle(.plain)
         }
      }
      .contentShape(Rectangle())
      .onTapGesture {
         if isSelectionMode { toggleSelection(for: toDo) }
      }
      .swipeActions(edge: .leading, allowsFullSwipe: !isSelectionMode) {
         if !isSelectionMode {
            Button { restore(toDo) } label: { Label("Restore", systemImage: "arrow.uturn.backward.circle") }
               .tint(AppColor.actionPrimary)
         }
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectionMode) {
         if !isSelectionMode {
            Button(role: .destructive) { deletePermanently(toDo) } label: { Label("Delete", systemImage: "trash") }
         }
      }
   }

   private var bottomActionbar: some View {
      Button {
         isShowingEmptyTrashConfirmation = true
      } label: {
         HStack {
            Image(systemName: "trash.fill")
            Text("Empty Trash Now")
         }
         .font(.appDisplay(16, relativeTo: .headline))
         .foregroundStyle(AppColor.onAction)
         .frame(maxWidth: .infinity)
         .padding(.vertical, 16)
         .background(AppColor.actionDestructive, in: .rect(cornerRadius: 24))
      }
      .buttonStyle(.plain)
      .padding(16)
      .disabled(trashedToDos.isEmpty)
      .opacity(trashedToDos.isEmpty ? 0 : 1)
      .animation(.snappy, value: trashedToDos.isEmpty)
   }

   private func daysRemainingText(for toDo: ToDo) -> String {
      guard let dayLimit = resolvedInterval.days, let trashedAt = toDo.trashedAt else { return "Will not auto-delete" }
      let expirationDate = Calendar.current.date(byAdding: .day, value: dayLimit, to: trashedAt) ?? Date()
      let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
      if daysLeft <= 0 { return "Deleting today" }
      return daysLeft == 1 ? "1 day left" : "\(daysLeft) days left"
   }
   
   private func restore(_ toDo: ToDo) {
      HapticFeedbackService.play(.restored)
      withAnimation(AppAnimation.snappyStandard) {
         toDo.transition(to: .active)
         toDo.trashedAt = nil
      }
      persistChanges("Failed to restore")
      syncCalendarMirrorIfNeeded(for: toDo)
   }
   
   private func deletePermanently(_ toDo: ToDo) {
      HapticFeedbackService.play(.destructive)
      withAnimation(AppAnimation.easeFast) {
         removeCalendarMirrorIfPresent(for: toDo)
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
         context.delete(toDo)
      }
      persistChanges("Failed to delete permanently")
   }
   
   private func emptyTrashNow() {
      guard !trashedToDos.isEmpty else { return }
      HapticFeedbackService.play(.destructive)
      for toDo in trashedToDos {
         removeCalendarMirrorIfPresent(for: toDo)
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
         context.delete(toDo)
      }
      persistChanges("Failed to empty trash")
   }
   
   private func runRollingAutoEmpty() {
      guard let dayLimit = resolvedInterval.days else { return }
      let cutoffDate = Calendar.current.date(byAdding: .day, value: -dayLimit, to: Date()) ?? Date()
      var didPurge = false
      
      for toDo in trashedToDos {
         if let trashedAt = toDo.trashedAt, trashedAt < cutoffDate {
            removeCalendarMirrorIfPresent(for: toDo)
            SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
            context.delete(toDo)
            didPurge = true
         }
      }
      if didPurge { persistChanges("Failed to auto-purge") }
   }
   
   private func persistChanges(_ message: String) {
      do {
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         SyncCoordinator.shared.scheduleLocalSync()
      } catch { AppLog.error("\(message): \(error)", logger: AppLog.app) }
   }
   
   private var bulkActionBar: some View {
      VStack(spacing: 0) {
         Divider()
         HStack(spacing: 0) {
            bulkActionButton(systemName: "arrow.uturn.backward.circle", label: "Restore", disabled: selectedToDoIDs.isEmpty) {
               restoreSelected()
            }
            bulkActionButton(systemName: "trash", label: "Delete", isDestructive: true, disabled: selectedToDoIDs.isEmpty) {
               deleteSelectedPermanently()
            }
         }
         .padding(.vertical, 12)
         .background(AppColor.surface)
      }
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
      let toDosToRestore = trashedToDos.filter { selectedToDoIDs.contains($0.id) }

      withAnimation(AppAnimation.snappyStandard) {
         for toDo in toDosToRestore {
            toDo.transition(to: .active)
            toDo.trashedAt = nil
         }
         selectedToDoIDs.removeAll()
         isSelectionMode = false
      }
      persistChanges("Failed to restore selected")
      for toDo in toDosToRestore {
         syncCalendarMirrorIfNeeded(for: toDo)
      }
   }
   
   private func deleteSelectedPermanently() {
      guard !selectedToDoIDs.isEmpty else { return }
      HapticFeedbackService.play(.destructive)
      withAnimation(AppAnimation.easeFast) {
         let toDosToDelete = trashedToDos.filter { selectedToDoIDs.contains($0.id) }
         for toDo in toDosToDelete {
            removeCalendarMirrorIfPresent(for: toDo)
            SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
            context.delete(toDo)
         }
         selectedToDoIDs.removeAll()
         isSelectionMode = false
      }
      persistChanges("Failed to permanently delete selected")
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
               try context.save()
            }
         } catch {
            AppLog.error("Calendar mirror failed: \(error.localizedDescription)", logger: AppLog.calendar)
         }
      }
   }
}
