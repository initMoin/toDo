import SwiftUI
import SwiftData
import Combine
import CoreLocation
import MapKit

struct ToDoView: View {
   private struct CreateNanoDoDraft: Identifiable {
      let id: UUID
      var task: String
      var hasDueDate: Bool
      var dueDate: Date
   }

   private struct EditDraftSnapshot: Equatable {
      var task: String
      var notes: String
      var isDone: Bool
      var hasDueDate: Bool
      var dueDate: Date
      var reminderIntent: ToDoReminderIntent
      var isRecurring: Bool
      var recurrenceUnit: ToDoRecurrenceUnit
      var recurrenceInterval: Int
      var recurrenceMode: ToDoRecurrenceMode
      var recurrenceCount: Int
      var hasLocationReminder: Bool
      var locationReminderLatitude: Double
      var locationReminderLongitude: Double
      var locationReminderRadius: Double
      var locationReminderTrigger: ToDoLocationReminderTrigger
      var locationReminderLabel: String
      var selectedTagIDs: [PersistentIdentifier]
   }

   private static let taskCharacterLimit = 160

   enum InteractionContext {
      case pushed
      case sheet
   }

   enum Mode {
      case create(preselectedTagID: PersistentIdentifier?)
      case view(ToDo, context: InteractionContext)
      case edit(ToDo, context: InteractionContext)
   }

   @Environment(\.modelContext) private var context
   @Environment(\.dismiss) private var dismiss
   @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
   @Query private var tags: [Tag]
   @Query private var toDos: [ToDo]
   @Query private var nanoDos: [NanoDo]
   @AppStorage(AppPreferences.Keys.tagSortOption) private var tagSortOption = TagSortOption.name.rawValue

   private let mode: Mode
   private let onFinish: ((ToDo?) -> Void)?
   private let isInlineOverlayEdit: Bool
   private let onDelete: (() -> Void)?
   private let onboardingManager: GuidedOnboardingManager?

   @State private var task: String
   @State private var notes: String
   @State private var isDone: Bool
   @State private var hasDueDate: Bool
   @State private var dueDate: Date
   @State private var reminderIntent: ToDoReminderIntent
   @State private var isRecurring: Bool
   @State private var recurrenceUnit: ToDoRecurrenceUnit
   @State private var recurrenceInterval: Int
   @State private var recurrenceMode: ToDoRecurrenceMode
   @State private var recurrenceCount: Int
   @State private var hasLocationReminder: Bool
   @State private var locationReminderLatitude: Double
   @State private var locationReminderLongitude: Double
   @State private var locationReminderRadius: Double
   @State private var locationReminderTrigger: ToDoLocationReminderTrigger
   @State private var locationReminderLabel: String
   @State private var locationSearchText: String
   @State private var isLocationExpanded: Bool
   @State private var isLocatingReminder = false
   @State private var dueDateSelection: Set<DateComponents>
   @State private var selectedTagIDs: [PersistentIdentifier]
   @State private var isCreateExpanded: Bool
   @State private var isNotesExpanded: Bool
   @State private var isTagExpanded: Bool
   @State private var isNanoDoExpanded: Bool
   @State private var createNanoDos: [CreateNanoDoDraft]
   @State private var isCreateTaskCommitted: Bool
   @State private var newTagName: String

   @State private var pendingLifecycleState: ToDoState? = nil

   @State private var isShowingDiscardChangesConfirmation = false
   @State private var isShowingDeleteConfirmation = false
   @State private var isShowingNewNanoDo = false
   @State private var saveErrorMessage: String?
   @State private var editStartSnapshot: EditDraftSnapshot?
   @State private var hasRequestedInitialCreateFocus = false
   @StateObject private var locationReminderService = LocationReminderService.shared
   @StateObject private var placeSearch = LocationReminderPlaceSearch()
   @Namespace private var tagPillNamespace
   @FocusState private var isCreateTaskFieldFocused: Bool
   private let editingToDo: ToDo?
   private let initialCreateSelectedTagIDs: [PersistentIdentifier]

   init(
      mode: Mode,
      onFinish: ((ToDo?) -> Void)? = nil,
      isInlineOverlayEdit: Bool = false,
      onDelete: (() -> Void)? = nil,
      onboardingManager: GuidedOnboardingManager? = nil
   ) {
      self.mode = mode
      self.onFinish = onFinish
      self.isInlineOverlayEdit = isInlineOverlayEdit
      self.onDelete = onDelete
      self.onboardingManager = onboardingManager
      switch mode {
      case .create(let preselectedTagID):
         let areTagsEnabledByDefault = UserDefaults.standard.bool(forKey: AppPreferences.Keys.createToDoTagsEnabledByDefault)
         let createTagExpanded = preselectedTagID != nil || areTagsEnabledByDefault
         let initialTagIDs = preselectedTagID.map { [$0] } ?? []
         editingToDo = nil
         initialCreateSelectedTagIDs = initialTagIDs
         _task = State(initialValue: "")
         _notes = State(initialValue: "")
         _isDone = State(initialValue: false)
         _hasDueDate = State(initialValue: false)
         _dueDate = State(initialValue: Date())
         _reminderIntent = State(initialValue: .due)
         _isRecurring = State(initialValue: false)
         _recurrenceUnit = State(initialValue: .days)
         _recurrenceInterval = State(initialValue: 1)
         _recurrenceMode = State(initialValue: .finite)
         _recurrenceCount = State(initialValue: 1)
         _hasLocationReminder = State(initialValue: false)
         _locationReminderLatitude = State(initialValue: 37.3349)
         _locationReminderLongitude = State(initialValue: -122.0090)
         _locationReminderRadius = State(initialValue: 150)
         _locationReminderTrigger = State(initialValue: .arriving)
         _locationReminderLabel = State(initialValue: "")
         _locationSearchText = State(initialValue: "")
         _isLocationExpanded = State(initialValue: false)
         _dueDateSelection = State(initialValue: [])
         _selectedTagIDs = State(initialValue: initialTagIDs)
         _isCreateExpanded = State(initialValue: false)
         _isNotesExpanded = State(initialValue: false)
         _isTagExpanded = State(initialValue: createTagExpanded)
         _isNanoDoExpanded = State(initialValue: false)
         _createNanoDos = State(initialValue: [])
         _isCreateTaskCommitted = State(initialValue: false)
         _newTagName = State(initialValue: "")
         _editStartSnapshot = State(initialValue: nil)
      case .view(let toDo, _), .edit(let toDo, _):
         editingToDo = toDo
         initialCreateSelectedTagIDs = []
         let hasInitialNotes = !toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         let fallbackDueDate = Date()
         _task = State(initialValue: toDo.task)
         _notes = State(initialValue: toDo.notes)
         _isDone = State(initialValue: toDo.isDoneState)
         if let dueDate = toDo.dueDate {
            _hasDueDate = State(initialValue: true)
            _dueDate = State(initialValue: dueDate)
            _reminderIntent = State(initialValue: toDo.reminderIntent)
            _isRecurring = State(initialValue: toDo.isRecurring)
            _recurrenceUnit = State(initialValue: toDo.recurrenceUnit ?? .days)
            _recurrenceInterval = State(initialValue: max(toDo.recurrenceInterval ?? 1, 1))
            _recurrenceMode = State(initialValue: toDo.recurrenceMode ?? .finite)
            _recurrenceCount = State(initialValue: max(toDo.recurrenceCount ?? 1, 1))
            _dueDateSelection = State(initialValue: [Self.selectionComponents(for: dueDate)])
         } else {
            _hasDueDate = State(initialValue: false)
            _dueDate = State(initialValue: fallbackDueDate)
            _reminderIntent = State(initialValue: toDo.reminderIntent)
            _isRecurring = State(initialValue: false)
            _recurrenceUnit = State(initialValue: .days)
            _recurrenceInterval = State(initialValue: 1)
            _recurrenceMode = State(initialValue: .finite)
            _recurrenceCount = State(initialValue: 1)
            _dueDateSelection = State(initialValue: [])
         }
         let hasInitialLocationReminder = toDo.hasLocationReminder
         _hasLocationReminder = State(initialValue: hasInitialLocationReminder)
         _locationReminderLatitude = State(initialValue: toDo.locationReminderLatitude ?? 37.3349)
         _locationReminderLongitude = State(initialValue: toDo.locationReminderLongitude ?? -122.0090)
         _locationReminderRadius = State(initialValue: toDo.resolvedLocationReminderRadius)
         _locationReminderTrigger = State(initialValue: toDo.locationReminderTrigger)
         _locationReminderLabel = State(initialValue: toDo.locationReminderLabel ?? "")
         _locationSearchText = State(initialValue: toDo.locationReminderLabel ?? "")
         _isLocationExpanded = State(initialValue: hasInitialLocationReminder)
         let initialSelectedTagIDs = toDo.effectiveTags.map(\.id)
         _selectedTagIDs = State(initialValue: initialSelectedTagIDs)
         _isCreateExpanded = State(initialValue: true)
         _isNotesExpanded = State(initialValue: hasInitialNotes)
         _isTagExpanded = State(initialValue: !initialSelectedTagIDs.isEmpty)
         _isNanoDoExpanded = State(initialValue: !toDo.nanoDos.isEmpty)
         _createNanoDos = State(initialValue: [])
         _isCreateTaskCommitted = State(initialValue: true)
         _newTagName = State(initialValue: "")
         switch mode {
         case .edit:
            _editStartSnapshot = State(initialValue: EditDraftSnapshot(
               task: toDo.task,
               notes: toDo.notes,
               isDone: toDo.isDoneState,
               hasDueDate: toDo.dueDate != nil,
               dueDate: toDo.dueDate ?? fallbackDueDate,
               reminderIntent: toDo.reminderIntent,
               isRecurring: toDo.isRecurring,
               recurrenceUnit: toDo.recurrenceUnit ?? .days,
               recurrenceInterval: max(toDo.recurrenceInterval ?? 1, 1),
               recurrenceMode: toDo.recurrenceMode ?? .finite,
               recurrenceCount: max(toDo.recurrenceCount ?? 1, 1),
               hasLocationReminder: hasInitialLocationReminder,
               locationReminderLatitude: toDo.locationReminderLatitude ?? 37.3349,
               locationReminderLongitude: toDo.locationReminderLongitude ?? -122.0090,
               locationReminderRadius: toDo.resolvedLocationReminderRadius,
               locationReminderTrigger: toDo.locationReminderTrigger,
               locationReminderLabel: toDo.locationReminderLabel ?? "",
               selectedTagIDs: initialSelectedTagIDs
            ))
         case .create, .view:
            _editStartSnapshot = State(initialValue: nil)
         }
      }
   }

   var body: some View {
      VStack(spacing: 0) {
         customTitleHeader

         ScrollView(showsIndicators: false) {
            formContent
         }
         .scrollDismissesKeyboard(.interactively)
         .background(AppColor.surface)
      }
      .background(AppColor.surface.ignoresSafeArea())
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .overlayPreferenceValue(OnboardingSpotlightPreferenceKey.self) { anchors in
         if let onboardingManager,
            onboardingManager.isActive,
            (onboardingManager.currentStep == .enterToDoText || onboardingManager.currentStep == .saveToDo) {
            GuidedOnboardingOverlay(manager: onboardingManager, anchors: anchors) { _ in }
               .zIndex(1200)
         }
      }
      .interactiveDismissDisabled(hasPendingChanges)
      .task {
         guard isCreateMode, !hasRequestedInitialCreateFocus else { return }
         hasRequestedInitialCreateFocus = true
         await Task.yield()
         if onboardingManager?.currentStep == .openAddView {
            prepareOnboardingDueDateIfNeeded()
            onboardingManager?.advance(to: .enterToDoText)
         }
         isCreateTaskFieldFocused = true
      }
      .onChange(of: task) { _, _ in
         guard case .create = mode else { return }
         if !hasEnteredTaskText {
            isCreateTaskCommitted = false
         } else if onboardingManager?.currentStep == .enterToDoText {
            prepareOnboardingDueDateIfNeeded()
            isCreateTaskCommitted = true
            onboardingManager?.advance(to: .saveToDo)
         }
      }
      .onChange(of: hasDueDate) { _, newValue in
         if !newValue {
            dueDate = Date()
            reminderIntent = .due
            isRecurring = false
         }
      }
      .alert("Discard changes?", isPresented: $isShowingDiscardChangesConfirmation) {
         Button("Keep Editing", role: .cancel) {}
         Button("Discard", role: .destructive) {
            confirmDiscardChanges()
         }
      } message: {
         Text("Your unsaved edits will be lost.")
      }
      .alert(
         "Couldn’t Save ToDo",
         isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
               if !isPresented {
                  saveErrorMessage = nil
               }
            }
         )
      ) {
         Button("OK", role: .cancel) {
            saveErrorMessage = nil
         }
      } message: {
         Text(saveErrorMessage ?? "Try again in a moment.")
      }
      .alert("Delete this ToDo?", isPresented: $isShowingDeleteConfirmation) {
         Button("Cancel", role: .cancel) {}
         Button("Delete", role: .destructive) {
            onDelete?()
         }
      } message: {
         Text("This removes the selected ToDo.")
      }
      .sheet(isPresented: $isShowingNewNanoDo) {
         if let toDo = editingToDo {
            NanoDoEditorView(mode: .create(toDo: toDo))
         }
      }
   }

   @ViewBuilder
   private var formContent: some View {
      VStack(alignment: .leading, spacing: 20) {
         switch mode {
         case .create:
            VStack(alignment: .leading, spacing: 8) {
               HStack(alignment: .top, spacing: 12) {
                  TextField(
                     "ToDo",
                     text: taskBinding,
                     prompt: Text("What do you wanna toDo?")
                        .foregroundStyle(AppColor.textSecondary.opacity(0.48)),
                     axis: .vertical
                  )
                  .font(.appDisplay(28, relativeTo: .title2))
                  .lineLimit(1...6)
                  .textInputAutocapitalization(.sentences)
                  .autocorrectionDisabled(false)
                  .focused($isCreateTaskFieldFocused)
                  .onboardingSpotlightAnchor(.taskField)

                  Button {
                     handleCreateTitleAction()
                  } label: {
                     Image(systemName: createTitleActionSymbol)
                        .font(.appHeadline(18, relativeTo: .headline))
                        .contentTransition(.symbolEffect(.replace))
                        .animation(AppAnimation.easeStandard, value: createTitleActionSymbol)
                        .frame(width: 30, height: 30, alignment: .center)
                  }
                  .buttonStyle(.plain)
                  .foregroundStyle(createEntryActionForeground)
                  .background(
                     Circle()
                        .fill(createEntryActionBackground)
                  )
                  .overlay(
                     Circle()
                        .stroke(createEntryActionBorder, lineWidth: 1)
                  )
                  .animation(AppAnimation.easeStandard, value: isCreateTaskCommitted)
                  .animation(AppAnimation.easeStandard, value: hasEnteredTaskText)
                  .interactionDisabled(isCreateTitleActionDisabled)
               }

               taskCharacterCounter
            }

            if isCreateExpanded {
               dueDateSection

               locationReminderSection

               collapsibleNotesSection

               collapsibleDetailSection("Tag", isExpanded: $isTagExpanded) {
                  inlineTagEntryRow

                  tagSelectionRepoView
                     .transition(expandTransition)
               }

               nanoDoDetailSection(isExpanded: $isNanoDoExpanded) {
                  withAnimation(AppAnimation.easeFast) {
                     if !isNanoDoExpanded {
                        isNanoDoExpanded = true
                     }
                     createNanoDos.append(CreateNanoDoDraft(
                        id: UUID(),
                        task: "",
                        hasDueDate: false,
                        dueDate: Date()
                     ))
                  }
               } content: {
                  if createNanoDos.isEmpty {
                     Text("No nanoDo yet")
                        .font(.appBody(13, relativeTo: .footnote))
                        .foregroundStyle(AppColor.textSecondary)
                  }

                  VStack(spacing: 10) {
                     ForEach(createNanoDos.indices, id: \.self) { index in
                        createNanoDoRow($createNanoDos[index])
                     }
                  }
               }
            }
         case .view:
            readOnlyExistingToDoContent
         case .edit:
            editableExistingToDoContent
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 34)
   }

   @ViewBuilder
   private var customTitleHeader: some View {
      if isInlineOverlayEdit && !isCreateMode {
         inlineOverlayEditHeader
      } else {
         standardTitleHeader
      }
   }

   private var standardTitleHeader: some View {
      VStack(spacing: 14) {
         HStack(alignment: .center, spacing: 12) {
            if isCreateMode || isViewMode {
               Button {
                  handleSheetDismissAttempt()
               } label: {
                  Image(systemName: "xmark")
                     .font(.appDisplay(18, relativeTo: .headline))
                     .frame(width: 34, height: 34, alignment: .center)
               }
               .buttonStyle(.plain)
               .foregroundStyle(isCreateMode ? AppColor.onAction : AppColor.textSecondary)
               .background(
                  Circle()
                     .fill(isCreateMode ? AppColor.actionDestructive : AppColor.surfaceMuted)
               )
               .overlay(
                  Circle()
                     .stroke(isCreateMode ? AppColor.actionDestructive : AppColor.border, lineWidth: 1)
               )
               .accessibilityLabel(isCreateMode ? "Cancel" : "Close")
            }

            VStack(alignment: .leading, spacing: 2) {
               styledNavigationTitle
                  .font(.appDisplay(34, relativeTo: .largeTitle))
               Text(modeDescription)
                  .font(.appBody(13, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            if isCreateMode {
               Button {
                  saveFromOnboardingIfNeeded()
               }
               label: {
                  Image(systemName: "checkmark")
                     .font(.appDisplay(18, relativeTo: .headline))
                     .frame(width: 34, height: 34, alignment: .center)
               }
               .buttonStyle(.plain)
               .foregroundStyle(createHeaderActionForeground)
               .background(
                  Circle()
                     .fill(createHeaderActionBackground)
               )
               .overlay(
                  Circle()
                     .stroke(createHeaderActionBorder, lineWidth: 1)
               )
               .animation(AppAnimation.easeStandard, value: isCreateTaskCommitted)
               .animation(AppAnimation.easeStandard, value: isPrimaryActionDisabled)
               .interactionDisabled(isPrimaryActionDisabled)
               .opacity(isPrimaryActionDisabled ? 0.58 : 1)
               .accessibilityLabel(primaryActionAccessibilityLabel)
               .onboardingSpotlightAnchor(.saveButton)
            } else if !isViewMode {
               Button {
                  save()
               }
               label: {
                  Image(systemName: "checkmark")
                     .font(.appDisplay(18, relativeTo: .headline))
               }
               .buttonStyle(AppCircleActionButtonStyle(intent: .proceed, size: 34))
               .interactionDisabled(isPrimaryActionDisabled)
               .animation(AppAnimation.easeStandard, value: isPrimaryActionDisabled)
               .accessibilityLabel(primaryActionAccessibilityLabel)
            }
         }

         Divider()
      }
      .padding(.horizontal, 16)
      .padding(.top, 24)
      .padding(.bottom, 2)
      .background(AppColor.surface)
   }

   private var inlineOverlayEditHeader: some View {
      VStack(spacing: 14) {
         HStack(alignment: .center, spacing: 18) {
            Button {
               handleSheetDismissAttempt()
            } label: {
               Image(systemName: "xmark")
                  .font(.appDisplay(16, relativeTo: .headline))
                  .frame(width: 34, height: 34, alignment: .center)
            }
            .foregroundStyle(AppColor.textSecondary)
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")

            Spacer(minLength: 0)

            VStack(spacing: 2) {
               Text("\(Text("Edit ").foregroundStyle(AppColor.textPrimary.opacity(0.45)))\(Text("ToDo").foregroundStyle(AppColor.textPrimary))")
                  .font(.appDisplay(28, relativeTo: .title2))
               Text("Update the selected item.")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            Button {
               save()
            } label: {
               Image(systemName: "checkmark")
                  .font(.appDisplay(16, relativeTo: .headline))
                  .frame(width: 34, height: 34, alignment: .center)
            }
            .foregroundStyle(isPrimaryActionDisabled ? AppColor.textSecondary : AppColor.textPrimary)
            .buttonStyle(.plain)
            .interactionDisabled(isPrimaryActionDisabled)
            .opacity(isPrimaryActionDisabled ? 0.52 : 1)
            .accessibilityLabel("Update")
         }

         HStack(spacing: 16) {
            Spacer(minLength: 0)

            Button {
               archiveAndSave()
            } label: {
               Image(systemName: "archivebox")
                  .font(.appDisplay(16, relativeTo: .headline))
                  .frame(width: 34, height: 34, alignment: .center)
            }
            .foregroundStyle(AppColor.actionSecondary)
            .buttonStyle(.plain)
            .accessibilityLabel("Archive")

            if onDelete != nil {
               Button {
                  pendingLifecycleState = .trashed
                  if let toDo = editingToDo { toDo.trashedAt = Date() }
                  save()
               } label: {
                  Image(systemName: "trash")
                     .font(.appDisplay(16, relativeTo: .headline))
                     .frame(width: 34, height: 34, alignment: .center)
               }
               .foregroundStyle(AppColor.actionDestructive)
               .buttonStyle(.plain)
               .accessibilityLabel("Delete")
            }
         }

         Divider()
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 2)
      .background(AppColor.surface)
   }

   private var modeDescription: String {
      switch mode {
      case .create:
         return String(localized: "Capture one focus at a time.")
      case .view:
         return String(localized: "Everything attached to this ToDo.")
      case .edit:
         return String(localized: "Refine details with minimal friction.")
      }
   }

   private var isCreateMode: Bool {
      if case .create = mode { return true }
      return false
   }

   private var isViewMode: Bool {
      if case .view = mode { return true }
      return false
   }

   private func sectionTitle(_ title: String) -> some View {
      Text(LocalizedStringKey(title))
         .font(.appDisplay(14, relativeTo: .subheadline))
         .foregroundStyle(AppColor.textSecondary)
   }

   @ViewBuilder
   private var dueDateSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         sectionTitle("Due Date")

         ToDoDueDateCalendar(selection: dueDateCalendarBinding)
            .frame(maxWidth: .infinity, alignment: .leading)

         HStack(spacing: 10) {
            Image(systemName: "clock")
               .foregroundStyle(hasSelectedDueDate ? AppColor.actionPrimary : AppColor.textSecondary)

            Text("Time")
               .font(.appDisplay(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)

            Spacer(minLength: 0)

            DatePicker("Time", selection: $dueDate, displayedComponents: .hourAndMinute)
               .labelsHidden()
               .datePickerStyle(.compact)
               .environment(\.locale, AppLocalization.displayLocale)
               .environment(\.calendar, AppLocalization.displayCalendar)
               .font(.appBodyStrong(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)
               .tint(AppColor.actionPrimary)
               .disabled(!hasSelectedDueDate)
               .opacity(hasSelectedDueDate ? 1 : 0.45)
         }
         .padding(.horizontal, 12)
         .padding(.vertical, 10)
         .containerShape(.rect(cornerRadius: 14))
         .background(
            AppColor.surfaceMuted,
            in: .rect(cornerRadius: 14)
         )

         if hasSelectedDueDate {
            VStack(alignment: .leading, spacing: 8) {
               sectionTitle("Reminder")

               HStack(spacing: 8) {
                  ForEach(ToDoReminderIntent.allCases) { intent in
                     reminderIntentChip(intent)
                  }
               }

               Text(reminderIntent.supportingCopy)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
            .transition(.move(edge: .top).combined(with: .opacity))

            VStack(alignment: .leading, spacing: 10) {
               HStack(spacing: 10) {
                  sectionTitle("Repeat")

                  Spacer(minLength: 0)

                  Toggle("Repeat", isOn: $isRecurring)
                     .labelsHidden()
               }

               if isRecurring {
                  VStack(alignment: .leading, spacing: 12) {
                     HStack(alignment: .center, spacing: 12) {
                        Text("Every")
                           .font(.appDisplay(15, relativeTo: .subheadline))
                           .foregroundStyle(AppColor.textSecondary)

                        Stepper(value: $recurrenceInterval, in: 1...999) {
                           Text(recurrenceUnit.displayLabel(for: recurrenceInterval))
                              .font(.appBodyStrong(14, relativeTo: .subheadline))
                              .foregroundStyle(AppColor.textPrimary)
                        }
                     }
                     .padding(.horizontal, 12)
                     .padding(.vertical, 10)
                     .containerShape(.rect(cornerRadius: 14))
                     .background(
                        AppColor.surfaceMuted,
                        in: .rect(cornerRadius: 14)
                     )

                     Menu {
                        ForEach(ToDoRecurrenceUnit.allCases) { unit in
                           Button(unit.title) {
                              recurrenceUnit = unit
                           }
                        }
                     } label: {
                        HStack(spacing: 10) {
                           Image(systemName: "arrow.clockwise")
                              .foregroundStyle(AppColor.actionPrimary)

                           Text("Unit")
                              .font(.appDisplay(15, relativeTo: .subheadline))
                              .foregroundStyle(AppColor.textSecondary)

                           Spacer(minLength: 0)

                           Text(recurrenceUnit.title)
                              .font(.appBodyStrong(14, relativeTo: .subheadline))
                              .foregroundStyle(AppColor.textPrimary)

                           Image(systemName: "chevron.up.chevron.down")
                              .font(.appBody(11, relativeTo: .caption))
                              .foregroundStyle(AppColor.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .containerShape(.rect(cornerRadius: 14))
                        .background(
                           AppColor.surfaceMuted,
                           in: .rect(cornerRadius: 14)
                        )
                     }
                     .buttonStyle(.plain)

                     HStack(spacing: 8) {
                        ForEach(ToDoRecurrenceMode.allCases) { mode in
                           recurrenceModeChip(mode)
                        }
                     }

                     if recurrenceMode == .finite {
                        HStack(alignment: .center, spacing: 12) {
                           Text("Additional reminders")
                              .font(.appDisplay(15, relativeTo: .subheadline))
                              .foregroundStyle(AppColor.textSecondary)

                           Spacer(minLength: 0)

                           Stepper(value: $recurrenceCount, in: 1...365) {
                              Text(AppLocalization.numberString(recurrenceCount))
                                 .font(.appBodyStrong(14, relativeTo: .subheadline))
                                 .foregroundStyle(AppColor.textPrimary)
                           }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .containerShape(.rect(cornerRadius: 14))
                        .background(
                           AppColor.surfaceMuted,
                           in: .rect(cornerRadius: 14)
                        )
                     }

                     Text(recurrenceSummaryText)
                        .font(.appBody(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.textSecondary)
                  }
                  .transition(.move(edge: .top).combined(with: .opacity))
               }
            }
            .animation(AppAnimation.snappyStandard, value: isRecurring)
         }
      }
      .animation(AppAnimation.snappyStandard, value: hasSelectedDueDate)
      .animation(AppAnimation.snappyStandard, value: reminderIntent)
   }

   @ViewBuilder
   private var locationReminderSection: some View {
      collapsibleDetailSection("Location Reminder", isExpanded: $isLocationExpanded) {
         VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: locationReminderEnabledBinding) {
               VStack(alignment: .leading, spacing: 4) {
                  Text("Remind by place")
                     .font(.appDisplay(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)

                  Text("ToDo can notify you when you arrive at or leave a saved location.")
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }
            }
            .tint(AppColor.actionSecondary)

            if hasLocationReminder {
               locationSearchField

               if !placeSearch.completions.isEmpty {
                  VStack(spacing: 8) {
                     ForEach(Array(placeSearch.completions.prefix(4).enumerated()), id: \.offset) { _, completion in
                        locationSearchResultRow(completion)
                     }
                  }
                  .transition(.move(edge: .top).combined(with: .opacity))
               }

               locationMapPreview

               HStack(spacing: 8) {
                  ForEach(ToDoLocationReminderTrigger.allCases) { trigger in
                     locationTriggerChip(trigger)
                  }
               }

               HStack(spacing: 10) {
                  Image(systemName: "scope")
                     .foregroundStyle(AppColor.actionPrimary)

                  Text("Radius")
                     .font(.appDisplay(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textSecondary)

                  Spacer(minLength: 0)

                  Stepper(value: locationRadiusBinding, in: 100...1_000, step: 50) {
                     Text("\(AppLocalization.numberString(Int(locationReminderRadius))) \(String(localized: "m"))")
                        .font(.appBodyStrong(14, relativeTo: .subheadline))
                        .foregroundStyle(AppColor.textPrimary)
                  }
               }
               .padding(.horizontal, 12)
               .padding(.vertical, 10)
               .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 14))

               TextField("Place label, e.g. Office or Grocery", text: $locationReminderLabel)
                  .textInputAutocapitalization(.words)
                  .font(.appBody(14, relativeTo: .subheadline))
                  .padding(.horizontal, 12)
                  .padding(.vertical, 12)
                  .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 14))
            }

            Button {
               Task {
                  await setLocationReminderToCurrentLocation()
               }
            } label: {
               HStack(spacing: 10) {
                  Image(systemName: isLocatingReminder ? "location.circle" : "location.fill")
                     .font(.appBodyStrong(14, relativeTo: .subheadline))

                  Text(isLocatingReminder ? "Finding Location" : "Use Current Location")
                     .font(.appDisplay(15, relativeTo: .subheadline))

                  Spacer(minLength: 0)
               }
               .foregroundStyle(AppColor.onAction)
               .padding(.horizontal, 14)
               .padding(.vertical, 12)
               .background(AppColor.actionPrimary, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .interactionDisabled(isLocatingReminder)
            .opacity(isLocatingReminder ? 0.65 : 1)

            Text(locationReminderService.locationReminderStatusMessage)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(locationReminderService.canMonitorLocationReminders ? AppColor.textSecondary : AppColor.actionDestructive)
         }
      }
   }

   private var locationSearchField: some View {
      HStack(spacing: 10) {
         Image(systemName: "magnifyingglass")
            .foregroundStyle(AppColor.textSecondary)

         TextField("Search for a place", text: $locationSearchText)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(.appBody(14, relativeTo: .subheadline))
            .onChange(of: locationSearchText) { _, newValue in
               placeSearch.query = newValue
            }

         if placeSearch.isSearching {
            ProgressView()
               .controlSize(.small)
         }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
      .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 14))
   }

   private func locationSearchResultRow(_ completion: MKLocalSearchCompletion) -> some View {
      Button {
         Task {
            await selectLocationSearchCompletion(completion)
         }
      } label: {
         HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.circle.fill")
               .font(.appBodyStrong(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.actionPrimary)
               .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
               Text(completion.title)
                  .font(.appDisplay(14, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textPrimary)
                  .lineLimit(1)

               if !completion.subtitle.isEmpty {
                  Text(completion.subtitle)
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
                     .lineLimit(2)
               }
            }

            Spacer(minLength: 0)
         }
         .padding(.horizontal, 12)
         .padding(.vertical, 10)
         .background(AppColor.surfaceMuted.opacity(0.72), in: .rect(cornerRadius: 14))
      }
      .buttonStyle(.plain)
   }

   private var locationMapPreview: some View {
      Map(position: .constant(.region(locationReminderMapRegion))) {
         Marker(locationReminderDisplayName, coordinate: locationReminderCoordinate)
            .tint(AppColor.actionPrimary)
      }
      .frame(height: 170)
      .clipShape(.rect(cornerRadius: 18))
      .overlay {
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AppColor.border.opacity(0.35), lineWidth: 1)
      }
   }

   private func locationTriggerChip(_ trigger: ToDoLocationReminderTrigger) -> some View {
      Button {
         withAnimation(AppAnimation.easeFast) {
            locationReminderTrigger = trigger
         }
      } label: {
         Text(trigger.title)
            .font(.appDisplay(13, relativeTo: .subheadline))
            .foregroundStyle(locationReminderTrigger == trigger ? AppColor.onAction : AppColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
               RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(locationReminderTrigger == trigger ? AppColor.secondary : AppColor.surfaceMuted)
            )
      }
      .buttonStyle(.plain)
   }

   @ViewBuilder
   private var editableExistingToDoContent: some View {
      VStack(alignment: .leading, spacing: 8) {
         TextField("Task", text: taskBinding, axis: .vertical)
            .font(.appDisplay(28, relativeTo: .title2))
            .lineLimit(1...6)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
         taskCharacterCounter
      }

      dueDateSection

      locationReminderSection

      collapsibleNotesSection

      collapsibleDetailSection("Tag", isExpanded: $isTagExpanded) {
         inlineTagEntryRow

         tagSelectionRepoView
      }

      if let toDo = editingToDo {
         nanoDoDetailSection(isExpanded: $isNanoDoExpanded) {
            withAnimation(AppAnimation.easeFast) {
               if !isNanoDoExpanded {
                  isNanoDoExpanded = true
               }
               isShowingNewNanoDo = true
            }
         } content: {
            if toDo.nanoDos.isEmpty {
               Text("No nanoDo yet")
                  .font(.appBody(13, relativeTo: .footnote))
                  .foregroundStyle(AppColor.textSecondary)
            } else {
               VStack(spacing: 10) {
                  ForEach(toDo.nanoDos) { nanoDo in
                     NanoDoRowView(nanoDo: nanoDo) {
                        deleteNanoDo(nanoDo)
                     }
                  }
               }
            }
         }
      }

      HStack(spacing: 12) {
         Button {
            archiveAndSave()
         } label: {
            Text("Archive")
               .frame(maxWidth: .infinity, alignment: .center)
               .font(.appDisplay(16, relativeTo: .headline))
               .foregroundStyle(AppColor.textPrimary)
               .padding(.vertical, 19)
               .background(
                  RoundedRectangle(cornerRadius: 28, style: .continuous)
                     .fill(AppColor.surfaceElevated)
               )
               .overlay(
                  RoundedRectangle(cornerRadius: 28, style: .continuous)
                     .stroke(AppColor.border, lineWidth: 1)
               )
               .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
         }
         .buttonStyle(.plain)

         Button {
            HapticFeedbackService.play(isDone ? .taskReopened : .taskCompleted)
            isDone.toggle()
         } label: {
            Text(isDone ? "Mark Active" : "Mark Done")
               .frame(maxWidth: .infinity, alignment: .center)
               .font(.appDisplay(16, relativeTo: .headline))
               .foregroundStyle(AppColor.onAction)
               .padding(.vertical, 19)
               .background(
                  RoundedRectangle(cornerRadius: 28, style: .continuous)
                     .fill(isDone ? AppColor.actionNeutral : AppColor.actionSuccess)
               )
               .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
         }
         .buttonStyle(.plain)
      }
   }

   @ViewBuilder
   private var readOnlyExistingToDoContent: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(task)
            .font(.appDisplay(30, relativeTo: .title2))
            .foregroundStyle(AppColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

         Text(isDone ? "Done" : "Active")
            .font(.appBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.surfaceMuted, in: Capsule())
      }

      VStack(alignment: .leading, spacing: 10) {
         sectionTitle("Details")

         if hasDueDate {
            readOnlyInfoRow(
               systemName: "calendar",
               title: "Due",
               value: AppLocalization.dateTimeString(dueDate)
            )
         }

         readOnlyInfoRow(
            systemName: reminderIntentSystemName,
            title: "Reminder",
            value: reminderIntent.title
         )

         if isRecurring {
            readOnlyInfoRow(
               systemName: "arrow.clockwise",
               title: "Repeat",
               value: recurrenceSummaryText
            )
         }

         if hasLocationReminder {
            readOnlyInfoRow(
               systemName: locationReminderTrigger == .arriving ? "location.fill" : "location.slash.fill",
               title: locationReminderTrigger == .arriving ? "Arriving" : "Leaving",
               value: locationReminderDisplayName
            )
         }
      }

      if !selectedTags.isEmpty {
         VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Tags")
            TagPillFlowLayout(spacing: 8, rowSpacing: 8) {
               ForEach(selectedTags) { tag in
                  Text(tag.displayName)
                     .font(.appDisplay(14, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)
                     .padding(.horizontal, 12)
                     .padding(.vertical, 8)
                     .background(AppColor.surfaceMuted, in: Capsule())
               }
            }
         }
      }

      let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmedNotes.isEmpty {
         VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Notes")
            Text(trimmedNotes)
               .font(.appBody(16, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)
               .fixedSize(horizontal: false, vertical: true)
               .padding(14)
               .frame(maxWidth: .infinity, alignment: .leading)
               .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))
         }
      }

      if let toDo = editingToDo, !toDo.nanoDos.isEmpty {
         VStack(alignment: .leading, spacing: 10) {
            sectionTitle("NanoDos")
            VStack(alignment: .leading, spacing: 10) {
               ForEach(toDo.nanoDos) { nanoDo in
                  NanoDoReadOnlyRowView(nanoDo: nanoDo)
                     .padding(12)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))
               }
            }
         }
      }
   }

   private func readOnlyInfoRow(systemName: String, title: String, value: String) -> some View {
      HStack(alignment: .top, spacing: 10) {
         Image(systemName: systemName)
            .font(.appBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(AppColor.actionNeutral)
            .frame(width: 18)

         VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
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
      .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))
   }

   @ViewBuilder
   private var collapsibleNotesSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(AppAnimation.snappyStandard) {
               isNotesExpanded.toggle()
            }
         } label: {
            HStack {
               sectionTitle("Notes")
               Spacer()
               Image(systemName: isNotesExpanded ? "chevron.up" : "chevron.down")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
            .contentShape(Rectangle())
         }
         .buttonStyle(.plain)

         if isNotesExpanded {
            TextField("Add notes to help you complete this toDo.", text: notesBinding, axis: .vertical)
               .lineLimit(4, reservesSpace: true)
               .transition(expandTransition)
         }
      }
   }

   private func collapsibleDetailSection<Content: View>(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(AppAnimation.snappyStandard) {
               isExpanded.wrappedValue.toggle()
            }
         } label: {
            HStack {
               sectionTitle(title)
               Spacer()
               Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
            .contentShape(Rectangle())
         }
         .buttonStyle(.plain)

         if isExpanded.wrappedValue {
            content()
               .transition(expandTransition)
         }
      }
   }

   private func nanoDoDetailSection<Content: View>(
      isExpanded: Binding<Bool>,
      addAction: @escaping () -> Void,
      @ViewBuilder content: () -> Content
   ) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(spacing: 10) {
            Button {
               withAnimation(AppAnimation.snappyStandard) {
                  isExpanded.wrappedValue.toggle()
               }
            } label: {
               HStack(spacing: 8) {
                  sectionTitle("NanoDo")
                  Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }
               .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: addAction) {
               Image(systemName: "plus")
                  .font(.appDisplay(14, relativeTo: .headline))
                  .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.onAction)
            .background(AppColor.actionPrimary, in: Circle())
            .accessibilityLabel("Add nanoDo")
         }

         if isExpanded.wrappedValue {
            content()
               .transition(expandTransition)
         }
      }
   }

   private var styledNavigationTitle: Text {
      switch mode {
      case .create:
         return Text("\(Text("New ").foregroundStyle(AppColor.textPrimary.opacity(0.45)))\(Text("ToDo").foregroundStyle(AppColor.textPrimary))")
      case .view:
         return Text("\(Text("Your ").foregroundStyle(AppColor.textPrimary.opacity(0.45)))\(Text("ToDo").foregroundStyle(AppColor.textPrimary))")
      case .edit:
         return Text("\(Text("Edit ").foregroundStyle(AppColor.textPrimary.opacity(0.45)))\(Text("ToDo").foregroundStyle(AppColor.textPrimary))")
      }
   }

   private var isPrimaryActionDisabled: Bool {
      switch mode {
      case .create:
         return !hasEnteredTaskText || !isCreateTaskCommitted
      case .view:
         return false
      case .edit:
         return !hasEnteredTaskText || !hasPendingEditChanges
      }
   }

   private var primaryActionAccessibilityLabel: String {
      switch mode {
      case .create:
         return "Create"
      case .view:
         return "Close"
      case .edit:
         return "Update"
      }
   }

   private var hasPendingChanges: Bool {
      switch mode {
      case .create:
         return hasPendingCreateChanges
      case .view:
         return false
      case .edit:
         return hasPendingEditChanges
      }
   }

   private var hasPendingNewTagName: Bool {
      !newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
   }

   private var isCreateTaskCommittedVisual: Bool {
      isCreateTaskCommitted && hasEnteredTaskText
   }

   private var createEntryActionForeground: Color {
      isCreateTaskCommittedVisual ? AppColor.onAction : (hasEnteredTaskText ? AppColor.textPrimary : AppColor.textSecondary)
   }

   private var createEntryActionBackground: Color {
      isCreateTaskCommittedVisual ? AppColor.iconCircle : AppColor.surface
   }

   private var createEntryActionBorder: Color {
      isCreateTaskCommittedVisual ? AppColor.iconCircle : AppColor.border
   }

   private var createHeaderActionForeground: Color {
      isCreateTaskCommittedVisual ? AppColor.onAction : AppColor.textPrimary
   }

   private var createHeaderActionBackground: Color {
      isCreateTaskCommittedVisual ? AppColor.iconCircle : AppColor.surface
   }

   private var createHeaderActionBorder: Color {
      isCreateTaskCommittedVisual ? AppColor.iconCircle : AppColor.border
   }

   private var inlineTagEntryRow: some View {
      HStack(spacing: 12) {
         TextField("Add a tag", text: $newTagName)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.appBody(14, relativeTo: .subheadline))

         Button {
            addTagInline()
         } label: {
            Image(systemName: hasPendingNewTagName ? "checkmark" : "plus")
               .font(.appDisplay(13, relativeTo: .caption))
               .frame(width: 30, height: 30, alignment: .center)
         }
         .buttonStyle(AppCircleActionButtonStyle(intent: .proceed, size: 30))
         .interactionDisabled(!hasPendingNewTagName)
      }
   }

   @ViewBuilder
   private var tagSelectionRepoView: some View {
      VStack(alignment: .leading, spacing: 12) {
         if !selectedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
               Text(
                  String(
                     format: String(localized: "Selected (%@/%@)"),
                     AppLocalization.numberString(selectedTags.count),
                     AppLocalization.numberString(ToDo.maxTagSelection)
                  )
               )
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
               TagPillFlowLayout(spacing: 8, rowSpacing: 8) {
                  ForEach(Array(selectedTags.enumerated()), id: \.element.id) { index, tag in
                     tagPillButton(
                        id: tag.id,
                        title: tag.displayName,
                        style: index == 0 ? .selectedPrimary : .selectedSecondary
                     ) {
                        toggleTagSelection(tag)
                     }
                  }
               }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
         }

         VStack(alignment: .leading, spacing: 8) {
            Text("Available")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)

            if availableTags.isEmpty {
               Text(tagList.isEmpty ? "No tags available" : "No additional tags")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            } else {
               availableTagPillSelector
            }

            if selectedTagLimitReached {
               Text(String(format: String(localized: "Up to %@ tags per toDo"), AppLocalization.numberString(ToDo.maxTagSelection)))
                  .font(.appBody(11, relativeTo: .caption2))
                  .foregroundStyle(AppColor.textSecondary)
            }
         }
         .transition(.move(edge: .top).combined(with: .opacity))
      }
      .animation(AppAnimation.tagTransition, value: tagAnimationKey)
   }

   private var availableTagPillSelector: some View {
      TagPillFlowLayout(spacing: 8, rowSpacing: 8) {
         ForEach(availableTags) { tag in
            tagPillButton(id: tag.id, title: tag.displayName, style: .available, isDisabled: selectedTagLimitReached) {
               toggleTagSelection(tag)
            }
         }
      }
      .padding(.vertical, 4)
   }

   private enum TagPillStyle {
      case available
      case selectedPrimary
      case selectedSecondary
   }

   private func tagPillButton(
      id: AnyHashable,
      title: String,
      style: TagPillStyle,
      isDisabled: Bool = false,
      action: @escaping () -> Void
   ) -> some View {
      let foreground: Color
      let background: Color
      switch style {
      case .available:
         foreground = AppColor.textPrimary
         background = AppColor.surfaceMuted
      case .selectedPrimary:
         foreground = AppColor.onAction
         background = AppColor.secondary
      case .selectedSecondary:
         foreground = AppColor.onAction
         background = AppColor.actionPrimary
      }

      return Button(action: action) {
         Text(title)
            .lineLimit(1)
            .font(.appDisplay(14, relativeTo: .subheadline))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
               Capsule()
                  .fill(background)
            )
            .matchedGeometryEffect(id: id, in: tagPillNamespace)
      }
      .buttonStyle(.plain)
      .interactionDisabled(isDisabled)
      .opacity(isDisabled ? 0.52 : 1)
      .animation(AppAnimation.tagTransition, value: style)
      .animation(AppAnimation.tagTransition, value: isDisabled)
   }

   private var tagAnimationKey: String {
      "\(selectedTags.map(\.name).joined(separator: ","))-\(tagList.count)-\(availableTags.count)"
   }

   private var selectedTagIDSet: Set<PersistentIdentifier> {
      Set(selectedTagIDs)
   }

   private var tagsByID: [PersistentIdentifier: Tag] {
      Dictionary(uniqueKeysWithValues: tagList.map { ($0.id, $0) })
   }

   private var selectedTags: [Tag] {
      let indexedTags = tagsByID
      return selectedTagIDs.compactMap { id in
         indexedTags[id]
      }
   }

   private var availableTags: [Tag] {
      tagList.filter { !selectedTagIDSet.contains($0.id) }
   }

   private var selectedTagLimitReached: Bool {
      selectedTagIDs.count >= ToDo.maxTagSelection
   }

   private func toggleTagSelection(_ tag: Tag) {
      withAnimation(AppAnimation.tagTransition) {
         if let index = selectedTagIDs.firstIndex(of: tag.id) {
            selectedTagIDs.remove(at: index)
            return
         }

         guard selectedTagIDs.count < ToDo.maxTagSelection else { return }
         selectedTagIDs.append(tag.id)
      }
   }

   private var currentEditSnapshot: EditDraftSnapshot {
      EditDraftSnapshot(
         task: task,
         notes: notes,
         isDone: isDone,
         hasDueDate: hasDueDate,
         dueDate: dueDate,
         reminderIntent: reminderIntent,
         isRecurring: isRecurring,
         recurrenceUnit: recurrenceUnit,
         recurrenceInterval: recurrenceInterval,
         recurrenceMode: recurrenceMode,
         recurrenceCount: recurrenceCount,
         hasLocationReminder: hasLocationReminder,
         locationReminderLatitude: locationReminderLatitude,
         locationReminderLongitude: locationReminderLongitude,
         locationReminderRadius: locationReminderRadius,
         locationReminderTrigger: locationReminderTrigger,
         locationReminderLabel: locationReminderLabel,
         selectedTagIDs: selectedTagIDs
      )
   }

   private var hasPendingEditChanges: Bool {
      guard let editStartSnapshot else { return false }
      var current = currentEditSnapshot
      var start = editStartSnapshot

      if !current.hasDueDate {
         current.dueDate = .distantPast
         current.reminderIntent = .soft
         current.isRecurring = false
      }
      if !start.hasDueDate {
         start.dueDate = .distantPast
         start.reminderIntent = .soft
         start.isRecurring = false
      }

      if !current.isRecurring {
         current.recurrenceInterval = 1
         current.recurrenceUnit = .days
         current.recurrenceMode = .finite
         current.recurrenceCount = 1
      }
      if !start.isRecurring {
         start.recurrenceInterval = 1
         start.recurrenceUnit = .days
         start.recurrenceMode = .finite
         start.recurrenceCount = 1
      }

      if !current.hasLocationReminder {
         current.locationReminderLatitude = 0
         current.locationReminderLongitude = 0
         current.locationReminderRadius = 150
         current.locationReminderTrigger = .arriving
         current.locationReminderLabel = ""
      }
      if !start.hasLocationReminder {
         start.locationReminderLatitude = 0
         start.locationReminderLongitude = 0
         start.locationReminderRadius = 150
         start.locationReminderTrigger = .arriving
         start.locationReminderLabel = ""
      }

      return current != start
   }

   private var hasPendingCreateChanges: Bool {
      guard case .create = mode else { return false }
      let hasTask = hasEnteredTaskText
      let hasNotes = !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      let changedTag = selectedTagIDs != initialCreateSelectedTagIDs
      let changedReminderIntent = hasDueDate && reminderIntent != .due
      let changedRecurrence = hasDueDate && isRecurring
      return hasTask || hasNotes || isDone || hasDueDate || hasLocationReminder || changedTag || changedReminderIntent || changedRecurrence || !createNanoDos.isEmpty
   }

   private func confirmDiscardChanges() {
      dismissComposer()
   }

   private func handleSheetDismissAttempt() {
      if hasPendingChanges {
         isShowingDiscardChangesConfirmation = true
      } else {
         dismissComposer()
      }
   }

   private func dismissComposer(savedToDo: ToDo? = nil) {
      if let onFinish {
         onFinish(savedToDo)
      } else {
         dismiss()
      }
   }

   private var visibleOwnerUserID: UUID? {
      guard supabaseAuthStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return supabaseAuthStore.currentUserID
   }

   private var scopedTags: [Tag] {
      tags.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var scopedToDos: [ToDo] {
      toDos.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var scopedNanoDos: [NanoDo] {
      nanoDos.filter { $0.ownerUserID == visibleOwnerUserID }
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
            let leftCount = (lhs.toDos?.count ?? 0) + (lhs.primaryToDos?.count ?? 0) + (lhs.nanoDos?.count ?? 0)
            let rightCount = (rhs.toDos?.count ?? 0) + (rhs.primaryToDos?.count ?? 0) + (rhs.nanoDos?.count ?? 0)
            if leftCount == rightCount {
               return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return isAscending ? leftCount < rightCount : leftCount > rightCount
         }
      }
   }

   private var taskBinding: Binding<String> {
      Binding(
         get: { task },
         set: { newValue in
            task = String(newValue.prefix(Self.taskCharacterLimit))
         }
      )
   }

   private var taskCharacterCounter: some View {
      Text("\(AppLocalization.numberString(task.count))/\(AppLocalization.numberString(Self.taskCharacterLimit))")
         .font(.appBody(12, relativeTo: .caption))
         .foregroundStyle(AppColor.textSecondary)
         .frame(maxWidth: .infinity, alignment: .trailing)
   }

   private var notesBinding: Binding<String> {
      $notes
   }

   private var dueDateSelectionBinding: Binding<Set<DateComponents>> {
      Binding(
         get: { dueDateSelection },
         set: { newValue in
            guard let selectedComponent = selectedDateComponent(from: newValue) else {
               dueDateSelection = []
               hasDueDate = false
               return
            }

            let normalizedSelection = Self.normalizedSelectionComponents(selectedComponent)
            dueDateSelection = [normalizedSelection]
            hasDueDate = true

            let calendar = Calendar.current
            let time = calendar.dateComponents([.hour, .minute, .second], from: dueDate)
            var merged = normalizedSelection
            merged.hour = time.hour
            merged.minute = time.minute
            merged.second = time.second
            if let nextDate = calendar.date(from: merged) ?? calendar.date(from: normalizedSelection) {
               dueDate = nextDate
            }
         }
      )
   }

   private var dueDateCalendarBinding: Binding<Date?> {
      Binding(
         get: {
            hasSelectedDueDate ? dueDate : nil
         },
         set: { newValue in
            guard let newValue else {
               dueDateSelection = []
               hasDueDate = false
               return
            }

            let calendar = Calendar.current
            let selectedDay = Self.selectionComponents(for: newValue)
            let time = calendar.dateComponents([.hour, .minute, .second], from: dueDate)
            var merged = selectedDay
            merged.hour = time.hour
            merged.minute = time.minute
            merged.second = time.second

            dueDateSelection = [Self.normalizedSelectionComponents(selectedDay)]
            hasDueDate = true
            dueDate = calendar.date(from: merged) ?? newValue
         }
      )
   }

   private static func selectionComponents(for date: Date) -> DateComponents {
      let calendar = Calendar.current
      var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
      components.calendar = calendar
      components.timeZone = calendar.timeZone
      return components
   }

   private static func normalizedSelectionComponents(_ components: DateComponents) -> DateComponents {
      let calendar = components.calendar ?? Calendar.current
      var normalized = components
      normalized.calendar = calendar
      normalized.timeZone = components.timeZone ?? calendar.timeZone
      return normalized
   }

   private func selectedDateComponent(from newValue: Set<DateComponents>) -> DateComponents? {
      if let newlyAdded = newValue.subtracting(dueDateSelection).first {
         return newlyAdded
      }
      return newValue.first
   }

   private var hasSelectedDueDate: Bool {
      !dueDateSelection.isEmpty
   }

   private var locationReminderCoordinate: CLLocationCoordinate2D {
      CLLocationCoordinate2D(
         latitude: locationReminderLatitude,
         longitude: locationReminderLongitude
      )
   }

   private var locationReminderMapRegion: MKCoordinateRegion {
      MKCoordinateRegion(
         center: locationReminderCoordinate,
         latitudinalMeters: max(locationReminderRadius * 5, 700),
         longitudinalMeters: max(locationReminderRadius * 5, 700)
      )
   }

   private var locationReminderDisplayName: String {
      let label = locationReminderLabel.trimmingCharacters(in: .whitespacesAndNewlines)
      if !label.isEmpty {
         return label
      }

      return String(
         format: "%.4f, %.4f",
         locationReminderLatitude,
         locationReminderLongitude
      )
   }

   private var locationReminderEnabledBinding: Binding<Bool> {
      Binding(
         get: { hasLocationReminder },
         set: { isEnabled in
            withAnimation(AppAnimation.snappyStandard) {
               hasLocationReminder = isEnabled
               if isEnabled {
                  locationReminderService.requestLocationReminderAuthorization()
               }
            }
         }
      )
   }

   private var locationRadiusBinding: Binding<Double> {
      Binding(
         get: { locationReminderRadius },
         set: { locationReminderRadius = min(max($0, 100), 1_000) }
      )
   }

   private var reminderIntentSystemName: String {
      switch reminderIntent {
      case .soft:
         return "bell.badge"
      case .due:
         return "bell"
      case .timeSensitive:
         return "exclamationmark.circle"
      }
   }

   private var expandTransition: AnyTransition {
      .move(edge: .top).combined(with: .opacity)
   }

   private var createTitleActionSymbol: String {
      isCreateTaskCommittedVisual ? "checkmark" : "plus"
   }

   private var hasEnteredTaskText: Bool {
      task.unicodeScalars.contains { scalar in
         !Self.ignoredInputScalars.contains(scalar)
      }
   }

   private var isCreateTitleActionDisabled: Bool {
      guard case .create = mode else { return false }
      return !hasEnteredTaskText
   }

   private static let ignoredInputScalars: CharacterSet = {
      var set = CharacterSet.whitespacesAndNewlines
      set.formUnion(.controlCharacters)
      set.formUnion(CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{2060}\u{FE0E}\u{FE0F}\u{FEFF}\u{00AD}"))
      return set
   }()

   private var trimmedTaskText: String {
      task.trimmingCharacters(in: .whitespacesAndNewlines)
   }

   private func handleCreateTitleAction() {
      guard case .create = mode else { return }
      guard hasEnteredTaskText else { return }
      isCreateTaskFieldFocused = false
      withAnimation(AppAnimation.easeStandard) {
         isCreateTaskCommitted = true
      }
      if !isCreateExpanded {
         withAnimation(.snappy) {
            isCreateExpanded = true
         }
      }
   }

   private func setLocationReminderToCurrentLocation() async {
      guard !isLocatingReminder else { return }

      isLocatingReminder = true
      defer { isLocatingReminder = false }

      locationReminderService.requestLocationReminderAuthorization()
      guard let location = await locationReminderService.requestCurrentLocation() else {
         return
      }

      withAnimation(AppAnimation.snappyStandard) {
         hasLocationReminder = true
         isLocationExpanded = true
         locationReminderLatitude = location.coordinate.latitude
         locationReminderLongitude = location.coordinate.longitude
         if locationReminderLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            locationReminderLabel = String(localized: "Current Location")
         }
         locationSearchText = locationReminderLabel
         placeSearch.query = ""
         placeSearch.completions = []
      }
   }

   private func selectLocationSearchCompletion(_ completion: MKLocalSearchCompletion) async {
      await placeSearch.resolve(completion)

      guard let selection = placeSearch.selectedPlace else { return }
      locationReminderService.requestLocationReminderAuthorization()

      withAnimation(AppAnimation.snappyStandard) {
         hasLocationReminder = true
         isLocationExpanded = true
         locationReminderLatitude = selection.coordinate.latitude
         locationReminderLongitude = selection.coordinate.longitude
         locationReminderLabel = selection.title
         locationSearchText = selection.displayText
         placeSearch.query = ""
         placeSearch.completions = []
      }
   }

   private func addTagInline() {
      let normalized = Tag.normalizeName(newTagName)
      guard !normalized.isEmpty else { return }
      if let existingTag = tagList.first(where: { $0.displayName == normalized }) {
         withAnimation(AppAnimation.tagTransition) {
            if !selectedTagIDs.contains(existingTag.id), selectedTagIDs.count < ToDo.maxTagSelection {
               selectedTagIDs.append(existingTag.id)
            }
            newTagName = ""
            isTagExpanded = true
         }
         return
      }
      guard selectedTagIDs.count < ToDo.maxTagSelection else { return }
      let newTag = Tag(name: normalized, ownerUserID: visibleOwnerUserID)
      withAnimation(AppAnimation.tagTransition) {
         context.insert(newTag)
         selectedTagIDs.append(newTag.id)
         isTagExpanded = true
         newTagName = ""
      }
   }

   @ViewBuilder
   private func createNanoDoRow(_ nanoDo: Binding<CreateNanoDoDraft>) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle")
               .font(.appDisplay(18, relativeTo: .headline))
               .foregroundStyle(AppColor.textSecondary)
               .frame(width: 30, height: 30)

            TextField(
               "",
               text: nanoDo.task,
               prompt: Text("What do you wanna nanoDo?")
                  .foregroundStyle(AppColor.textSecondary.opacity(0.48)),
               axis: .vertical
            )
            .lineLimit(1...3)
            .font(.appDisplay(18, relativeTo: .headline))

            Button(role: .destructive) {
               removeCreateNanoDo(id: nanoDo.wrappedValue.id)
            } label: {
               Image(systemName: "trash")
                  .font(.appDisplay(14, relativeTo: .subheadline))
                  .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.actionDestructive)
            .background(AppColor.surface, in: Circle())
            .accessibilityLabel("Remove nanoDo")
         }

         HStack(spacing: 10) {
            if nanoDo.wrappedValue.hasDueDate {
               Image(systemName: "calendar")
                  .font(.appBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.actionPrimary)

               DatePicker(
                  "",
                  selection: nanoDo.dueDate,
                  displayedComponents: [.date, .hourAndMinute]
               )
               .labelsHidden()
               .datePickerStyle(.compact)
               .font(.appBodyStrong(12, relativeTo: .caption))
               .tint(AppColor.actionPrimary)

               Button {
                  withAnimation(AppAnimation.easeFast) {
                     nanoDo.wrappedValue.hasDueDate = false
                  }
               } label: {
                  Image(systemName: "xmark.circle.fill")
                     .font(.appBodyStrong(13, relativeTo: .caption))
               }
               .buttonStyle(.plain)
               .foregroundStyle(AppColor.textSecondary)
               .accessibilityLabel("Clear nanoDo due date")
            } else {
               Button {
                  withAnimation(.snappy(duration: 0.22)) {
                     nanoDo.wrappedValue.hasDueDate = true
                  }
               } label: {
                  Label("Add due date", systemImage: "calendar.badge.plus")
                     .font(.appBodyStrong(13, relativeTo: .caption))
               }
               .buttonStyle(.plain)
               .foregroundStyle(AppColor.actionPrimary)
            }
         }
         .padding(.leading, 40)
         .font(.appBodyStrong(12, relativeTo: .caption))
      }
      .padding(12)
      .background(AppColor.main.opacity(0.16), in: .rect(cornerRadius: 18))
      .overlay(
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AppColor.main.opacity(0.28), lineWidth: 1)
      )
   }

   private func removeCreateNanoDo(id: UUID) {
      createNanoDos.removeAll { $0.id == id }
   }

   private func prepareOnboardingDueDateIfNeeded() {
      guard onboardingManager?.isActive == true, isCreateMode else { return }
      hasDueDate = false
      reminderIntent = .soft
      isCreateExpanded = false
   }

   private func saveFromOnboardingIfNeeded() {
      guard onboardingManager?.isActive == true, isCreateMode else {
         save()
         return
      }

      prepareOnboardingDueDateIfNeeded()
      save()
   }

   private func save() {
      let trimmedTask = trimmedTaskText
      guard hasEnteredTaskText else { return }
      let resolvedDueDate = hasDueDate ? dueDate : nil
      let resolvedReminderIntent: ToDoReminderIntent = hasDueDate ? reminderIntent : .soft
      let resolvedRecurrenceUnit: ToDoRecurrenceUnit? = (hasDueDate && isRecurring) ? recurrenceUnit : nil
      let resolvedRecurrenceInterval: Int? = (hasDueDate && isRecurring) ? max(recurrenceInterval, 1) : nil
      let resolvedRecurrenceMode: ToDoRecurrenceMode? = (hasDueDate && isRecurring) ? recurrenceMode : nil
      let resolvedRecurrenceCount: Int? = (hasDueDate && isRecurring && recurrenceMode == .finite) ? max(recurrenceCount, 1) : nil
      let resolvedRecurrenceAnchorDate: Date? = (hasDueDate && isRecurring) ? dueDate : nil
      let indexedTags = tagsByID
      let selectedTags = selectedTagIDs.compactMap { id in
         indexedTags[id]
      }
      let firstSelectedTag = selectedTags.first
      var savedToDo: ToDo?

      switch mode {
      case .create:
         let newToDo = ToDo(
            task: trimmedTask,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: resolvedDueDate,
            reminderIntent: resolvedReminderIntent,
            recurrenceUnit: resolvedRecurrenceUnit,
            recurrenceInterval: resolvedRecurrenceInterval,
            recurrenceMode: resolvedRecurrenceMode,
            recurrenceCount: resolvedRecurrenceCount,
            recurrenceAnchorDate: resolvedRecurrenceAnchorDate,
            locationReminderLatitude: hasLocationReminder ? locationReminderLatitude : nil,
            locationReminderLongitude: hasLocationReminder ? locationReminderLongitude : nil,
            locationReminderRadius: hasLocationReminder ? locationReminderRadius : nil,
            locationReminderTrigger: hasLocationReminder ? locationReminderTrigger : nil,
            locationReminderLabel: hasLocationReminder ? locationReminderLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            lifecycleState: isDone ? .done : .active,
            tag: firstSelectedTag,
            tags: selectedTags,
            ownerUserID: visibleOwnerUserID
         )
         context.insert(newToDo)
         newToDo.setSelectedTags(selectedTags)
         savedToDo = newToDo

         if !createNanoDos.isEmpty {
            for createNanoDo in createNanoDos {
               let trimmedNanoDoTask = createNanoDo.task.trimmingCharacters(in: .whitespacesAndNewlines)
               guard !trimmedNanoDoTask.isEmpty else { continue }
               let nanoDo = NanoDo(
                  task: trimmedNanoDoTask,
                  dueDate: createNanoDo.hasDueDate ? createNanoDo.dueDate : nil,
                  isDone: false,
                  toDo: newToDo,
                  tag: firstSelectedTag,
                  ownerUserID: visibleOwnerUserID
               )
               newToDo.nanoDos.append(nanoDo)
               context.insert(nanoDo)
            }
         }
      case .view:
         return
      case .edit(let toDo, _):
         toDo.task = trimmedTask
         toDo.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
         toDo.transition(to: pendingLifecycleState ?? (isDone ? .done : .active))
         toDo.dueDate = resolvedDueDate
         toDo.reminderIntent = resolvedReminderIntent
         toDo.recurrenceUnit = resolvedRecurrenceUnit
         toDo.recurrenceInterval = resolvedRecurrenceInterval
         toDo.recurrenceMode = resolvedRecurrenceMode
         toDo.recurrenceCount = resolvedRecurrenceCount
         toDo.recurrenceAnchorDate = resolvedRecurrenceAnchorDate
         toDo.recurrenceEndDate = nil
         if hasLocationReminder {
            toDo.locationReminderLatitude = locationReminderLatitude
            toDo.locationReminderLongitude = locationReminderLongitude
            toDo.locationReminderRadius = locationReminderRadius
            toDo.locationReminderTrigger = locationReminderTrigger
            toDo.locationReminderLabel = locationReminderLabel.trimmingCharacters(in: .whitespacesAndNewlines)
         } else {
            toDo.clearLocationReminder()
         }
         if !isRecurring || !hasDueDate {
            toDo.clearRecurrence()
         }
         toDo.setSelectedTags(selectedTags)
         toDo.markUpdated()
         savedToDo = toDo
      }

      do {
         try context.save()
         switch pendingLifecycleState {
         case .archived:
            HapticFeedbackService.play(.warning)
         case .trashed:
            HapticFeedbackService.play(.destructive)
         default:
            HapticFeedbackService.play(.saved)
         }
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         if let savedToDo,
            !savedToDo.isActive || savedToDo.reminderIntent != .timeSensitive || savedToDo.dueDate == nil {
            LiveActivityService.shared.endActivity(for: savedToDo)
         }
         LiveActivityService.shared.refresh(from: context, preferredToDo: savedToDo)
         SyncCoordinator.shared.scheduleLocalSync()
         syncLocationReminderIfNeeded(for: savedToDo)
         syncCalendarMirrorIfNeeded(for: savedToDo)
      } catch {
         saveErrorMessage = "ToDo couldn’t save this change. \(error.localizedDescription)"
         AppLog.error("Failed to save ToDo changes: \(error)", logger: AppLog.app)
         return
      }

      dismissComposer(savedToDo: savedToDo)
   }

   private func syncCalendarMirrorIfNeeded(for toDo: ToDo?) {
      guard let toDo else { return }

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

   private func syncLocationReminderIfNeeded(for toDo: ToDo?) {
      guard let toDo else { return }
      LocationReminderService.shared.syncMonitoring(for: toDo)
   }

   private func archiveAndSave() {
      pendingLifecycleState = .archived
      save()
   }

   private func deleteNanoDo(_ nanoDo: NanoDo) {
      guard let toDo = editingToDo else { return }
      HapticFeedbackService.play(.destructive)
      SyncTombstoneStore.recordDelete(
         table: .nanoDos,
         recordID: nanoDo.cloudID,
         userID: nanoDo.ownerUserID
      )
      toDo.nanoDos.removeAll { $0 === nanoDo }
      context.delete(nanoDo)
   }

   private func reminderIntentChip(_ intent: ToDoReminderIntent) -> some View {
      Button {
         reminderIntent = intent
      } label: {
         Text(intent.title)
            .font(.appDisplay(13, relativeTo: .subheadline))
            .foregroundStyle(reminderIntent == intent ? AppColor.onAction : AppColor.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
      }
      .buttonStyle(.plain)
      .background(
         Capsule()
            .fill(reminderIntent == intent ? AppColor.secondary : AppColor.surfaceMuted)
      )
      .overlay(
         Capsule()
            .stroke(reminderIntent == intent ? AppColor.secondary : AppColor.border.opacity(0.35), lineWidth: 1)
      )
   }

   private func recurrenceModeChip(_ mode: ToDoRecurrenceMode) -> some View {
      Button {
         recurrenceMode = mode
      } label: {
         Text(mode.title)
            .font(.appDisplay(13, relativeTo: .subheadline))
            .foregroundStyle(recurrenceMode == mode ? AppColor.onAction : AppColor.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
      }
      .buttonStyle(.plain)
      .background(
         Capsule()
            .fill(recurrenceMode == mode ? AppColor.secondary : AppColor.surfaceMuted)
      )
      .overlay(
         Capsule()
            .stroke(recurrenceMode == mode ? AppColor.secondary : AppColor.border.opacity(0.35), lineWidth: 1)
      )
   }

   private var recurrenceSummaryText: String {
      let cadence = "Every \(recurrenceUnit.displayLabel(for: recurrenceInterval))"
      switch recurrenceMode {
      case .continuous:
         return "\(cadence), continuing until you change or remove it."
      case .finite:
         let label = recurrenceCount == 1 ? "1 additional reminder" : "\(recurrenceCount) additional reminders"
         return "\(cadence), for \(label) after the first due moment."
      }
   }

}
