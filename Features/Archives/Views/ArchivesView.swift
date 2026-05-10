import SwiftUI
import SwiftData

struct ArchivesView: View {
   @Environment(\.modelContext) private var context
   @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
   @Query private var toDos: [ToDo]
   @State private var isShowingPurgeConfirmation = false
   @State private var editingArchivedToDo: ToDo?

   var body: some View {
      ZStack(alignment: .top) {
         ScrollView {
            VStack(alignment: .leading, spacing: 24) {
               archiveSection("Archived ToDos") {
                  if archivedToDos.isEmpty {
                     Text("No archived ToDos")
                        .foregroundStyle(AppColor.textSecondary)
                  } else {
                     ForEach(Array(archivedToDos.enumerated()), id: \.element.id) { index, toDo in
                        archivedToDoRow(toDo)

                        if index < archivedToDos.count - 1 {
                           Divider()
                        }
                     }
                  }
               }
               
               Color.clear
                  .frame(height: 116)
            }
            .padding(.horizontal, 16)
            .padding(.top, 62)
            .padding(.bottom, 24)
         }
         
         pinnedTitleHeader
      }
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .overlay(alignment: .bottom) {
         bottomPurgeBar
      }
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .appNavigationChrome()
      .confirmationDialog("Purge all archived ToDos?", isPresented: $isShowingPurgeConfirmation, titleVisibility: .visible) {
         Button("Purge Archives", role: .destructive) {
            purgeArchives()
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("This permanently deletes every archived ToDo.")
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
      VStack(spacing: 0) {
         Text("Archives")
            .font(.appTitle(34, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 16)
            .padding(.top, -4)
            .padding(.bottom, 2)
            .background(AppColor.black)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private var visibleOwnerUserID: UUID? {
      guard supabaseAuthStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return supabaseAuthStore.currentUserID
   }

   private var archivedToDos: [ToDo] {
      toDos
         .filter { $0.ownerUserID == visibleOwnerUserID }
         .filter(\.isArchived)
         .sorted { $0.createdAt > $1.createdAt }
   }

   private func archiveSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(title)
            .font(.appSubtitle(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textPrimary)

         VStack(alignment: .leading, spacing: 14) {
            content()
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(
            Color.white,
            in: .rect(cornerRadius: 24)
         )
      }
   }

   private func archivedToDoRow(_ toDo: ToDo) -> some View {
      HStack(alignment: .top, spacing: 10) {
         VStack(alignment: .leading, spacing: 4) {
            Text(toDo.task)
               .foregroundStyle(AppColor.textPrimary)
               .lineLimit(2)

            if let dueDate = toDo.dueDate {
               Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
         }

         Spacer(minLength: 8)
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
         Button {
            restoreToActive(toDo)
         } label: {
            Label("Restore", systemImage: "arrow.uturn.backward.circle")
         }
         .tint(AppColor.actionPrimary)
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
         Button {
            restoreWithEdits(toDo)
         } label: {
            Label("Restore with Edits", systemImage: "square.and.pencil")
         }
         .tint(AppColor.actionSecondary)

         Button(role: .destructive) {
            deleteToDo(toDo)
         } label: {
            Label("Delete", systemImage: "trash")
         }
      }
      .contextMenu {
         Button {
            restoreToActive(toDo)
         } label: {
            Label("Restore", systemImage: "arrow.uturn.backward.circle")
         }

         Button {
            restoreWithEdits(toDo)
         } label: {
            Label("Restore with Edits", systemImage: "square.and.pencil")
         }

         Button(role: .destructive) {
            deleteToDo(toDo)
         } label: {
            Label("Delete", systemImage: "trash")
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
               Text("Permanently deletes all archived ToDos.")
                  .font(.appBody(12, relativeTo: .caption))
                  .opacity(0.92)
            }

            Spacer()
         }
         .foregroundStyle(AppColor.onAction)
         .padding(.horizontal, 16)
         .padding(.vertical, 14)
         .frame(maxWidth: .infinity)
         .background(
            AppColor.actionDestructive,
            in: .rect(corners: .concentric, isUniform: true)
         )
      }
      .buttonStyle(.plain)
      .disabled(archivedToDos.isEmpty)
      .opacity(archivedToDos.isEmpty ? 0.45 : 1)
   }

   private var bottomPurgeBar: some View {
      VStack(spacing: 0) {
         purgeArchivesButton
            .padding(8)
            .containerShape(.rect(cornerRadius: 28))
            .background(
               Color.white,
               in: .rect(cornerRadius: 28)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
      }
   }

   private func purgeArchives() {
      for toDo in archivedToDos {
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
         context.delete(toDo)
      }

      persistChanges("Failed to purge archived ToDos")
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

   private func restoreToActive(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeStandard) {
         toDo.transition(to: .active)
      }
      persistChanges("Failed to restore archived ToDo")
   }

   private func restoreWithEdits(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeStandard) {
         toDo.transition(to: .active)
      }
      persistChanges("Failed to restore archived ToDo for editing")
      editingArchivedToDo = toDo
   }

   private func deleteToDo(_ toDo: ToDo) {
      withAnimation(AppAnimation.easeFast) {
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
         context.delete(toDo)
      }
      persistChanges("Failed to delete archived ToDo")
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
