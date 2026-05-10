import SwiftUI
import SwiftData

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
      var selectedTagIDs: [PersistentIdentifier]
   }

   private static let taskCharacterLimit = 160
   
   enum InteractionContext {
      case pushed
      case sheet
   }
   
   enum Mode {
      case create(preselectedTagID: PersistentIdentifier?)
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
   @State private var dueDateSelection: Set<DateComponents>
   @State private var selectedTagIDs: [PersistentIdentifier]
   @State private var isCreateExpanded: Bool
   @State private var isNotesExpanded: Bool
   @State private var isTagExpanded: Bool
   @State private var isNanoDoExpanded: Bool
   @State private var createNanoDos: [CreateNanoDoDraft]
   @State private var isCreateTaskCommitted: Bool
   @State private var newTagName: String
   
   @State private var isShowingDiscardChangesConfirmation = false
   @State private var isShowingDeleteConfirmation = false
   @State private var isShowingNewNanoDo = false
   @State private var saveErrorMessage: String?
   @State private var editStartSnapshot: EditDraftSnapshot?
   @State private var hasRequestedInitialCreateFocus = false
   @Namespace private var tagPillNamespace
   @FocusState private var isCreateTaskFieldFocused: Bool
   private let editingToDo: ToDo?
   private let initialCreateSelectedTagIDs: [PersistentIdentifier]
   
   init(
      mode: Mode,
      onFinish: ((ToDo?) -> Void)? = nil,
      isInlineOverlayEdit: Bool = false,
      onDelete: (() -> Void)? = nil
   ) {
      self.mode = mode
      self.onFinish = onFinish
      self.isInlineOverlayEdit = isInlineOverlayEdit
      self.onDelete = onDelete
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
      case .edit(let toDo, _):
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
         let initialSelectedTagIDs = toDo.effectiveTags.map(\.id)
         _selectedTagIDs = State(initialValue: initialSelectedTagIDs)
         _isCreateExpanded = State(initialValue: true)
         _isNotesExpanded = State(initialValue: hasInitialNotes)
         _isTagExpanded = State(initialValue: !initialSelectedTagIDs.isEmpty)
         _isNanoDoExpanded = State(initialValue: !toDo.nanoDos.isEmpty)
         _createNanoDos = State(initialValue: [])
         _isCreateTaskCommitted = State(initialValue: true)
         _newTagName = State(initialValue: "")
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
            selectedTagIDs: initialSelectedTagIDs
         ))
      }
   }
   
   var body: some View {
      VStack(spacing: 0) {
         customTitleHeader
         
         ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
               switch mode {
               case .create:
                  VStack(alignment: .leading, spacing: 8) {
                     HStack(alignment: .top, spacing: 12) {
                        TextField("What do you want toDo?", text: taskBinding, axis: .vertical)
                           .font(.appDisplay(28, relativeTo: .title2))
                           .lineLimit(1...6)
                           .focused($isCreateTaskFieldFocused)
                        
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
                     
                     collapsibleNotesSection
                     
                     collapsibleDetailSection("Tag", isExpanded: $isTagExpanded) {
                        inlineTagEntryRow
                        
                        tagSelectionRepoView
                           .transition(expandTransition)
                     }
                     
                     collapsibleDetailSection("NanoDo", isExpanded: $isNanoDoExpanded) {
                        HStack {
                           Button("Add nanoDo") {
                              createNanoDos.append(CreateNanoDoDraft(
                                 id: UUID(),
                                 task: "",
                                 hasDueDate: false,
                                 dueDate: Date()
                              ))
                           }
                           Spacer()
                        }
                        
                        if createNanoDos.isEmpty {
                           Text("No nanoDo yet")
                              .foregroundStyle(AppColor.textSecondary)
                        }
                        
                        VStack(spacing: 10) {
                           ForEach(createNanoDos.indices, id: \.self) { index in
                              createNanoDoRow($createNanoDos[index])
                           }
                        }
                     }
                  }
               case .edit:
                  editableExistingToDoContent
               }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 34)
         }
         .scrollDismissesKeyboard(.interactively)
         .background(AppColor.surface)
      }
      .background(AppColor.surface.ignoresSafeArea())
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .interactiveDismissDisabled(hasPendingChanges)
      .task {
         guard case .create = mode, !hasRequestedInitialCreateFocus else { return }
         hasRequestedInitialCreateFocus = true
         try? await Task.sleep(nanoseconds: 75_000_000)
         guard !Task.isCancelled else { return }
         isCreateTaskFieldFocused = true
      }
      .onChange(of: task) { _, _ in
         guard case .create = mode else { return }
         if !hasEnteredTaskText {
            isCreateTaskCommitted = false
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
            if isCreateMode {
               Button {
                  handleSheetDismissAttempt()
               } label: {
                  Image(systemName: "xmark")
                     .font(.appDisplay(16, relativeTo: .headline))
                     .frame(width: 34, height: 34, alignment: .center)
               }
               .buttonStyle(.plain)
               .foregroundStyle(AppColor.textSecondary)
               .accessibilityLabel("Cancel")
            }

            VStack(alignment: .leading, spacing: 2) {
               Text(navigationTitleText)
                  .font(.appDisplay(34, relativeTo: .largeTitle))
                  .foregroundStyle(AppColor.textPrimary)
               Text(modeDescription)
                  .font(.appBody(13, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            if isCreateMode {
               Button {
                  save()
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
            } else {
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
               Text("Edit ToDo")
                  .font(.appDisplay(28, relativeTo: .title2))
                  .foregroundStyle(AppColor.textPrimary)
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

         HStack {
            Spacer(minLength: 0)

            if onDelete != nil {
               Button {
                  isShowingDeleteConfirmation = true
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
         return "Capture one focus at a time."
      case .edit:
         return "Refine details with minimal friction."
      }
   }

   private var isCreateMode: Bool {
      if case .create = mode { return true }
      return false
   }

   private func sectionTitle(_ title: String) -> some View {
      Text(title)
         .font(.appDisplay(14, relativeTo: .subheadline))
         .foregroundStyle(AppColor.textSecondary)
   }
   
   @ViewBuilder
   private var dueDateSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         sectionTitle("Due Date")
         
         MultiDatePicker("Due Date", selection: dueDateSelectionBinding)
            .labelsHidden()
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
                              Text("\(recurrenceCount)")
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
   private var editableExistingToDoContent: some View {
      VStack(alignment: .leading, spacing: 8) {
         TextField("Task", text: taskBinding, axis: .vertical)
            .font(.appDisplay(28, relativeTo: .title2))
            .lineLimit(1...6)
         taskCharacterCounter
      }
      
      dueDateSection
      
      collapsibleNotesSection
      
      collapsibleDetailSection("Tag", isExpanded: $isTagExpanded) {
         inlineTagEntryRow
         
         tagSelectionRepoView
      }
      
      if let toDo = editingToDo {
         collapsibleDetailSection("NanoDo", isExpanded: $isNanoDoExpanded) {
            HStack {
               Button("Add nanoDo") {
                  isShowingNewNanoDo = true
               }
               Spacer()
            }
            
            if toDo.nanoDos.isEmpty {
               Text("No nanoDo yet")
                  .foregroundStyle(AppColor.textSecondary)
            } else {
               VStack(spacing: 10) {
                  ForEach(toDo.nanoDos) { nanoDo in
                     HStack(alignment: .top, spacing: 10) {
                        NanoDoRowView(nanoDo: nanoDo)
                        
                        Button(role: .destructive) {
                           deleteNanoDo(nanoDo)
                        } label: {
                           Image(systemName: "xmark.circle.fill")
                              .foregroundStyle(AppColor.textSecondary)
                              .font(.appDisplay(14, relativeTo: .caption))
                        }
                        .buttonStyle(.plain)
                     }
                  }
               }
            }
         }
      }
      
      Button {
         isDone.toggle()
      } label: {
         Text(isDone ? "Mark Active" : "Mark Done")
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.appDisplay(16, relativeTo: .headline))
            .foregroundStyle(AppColor.onAction)
            .padding(.vertical, 19)
            .containerShape(.rect(cornerRadius: 20))
            .background(
               isDone ? AppColor.actionNeutral : AppColor.actionSuccess,
               in: .rect(corners: .concentric, isUniform: true)
            )
      }
      .buttonStyle(.plain)
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
   
   private var navigationTitleText: String {
      switch mode {
      case .create:
         return "New ToDo"
      case .edit:
         return "Edit ToDo"
      }
   }
   
   private var isPrimaryActionDisabled: Bool {
      switch mode {
      case .create:
         return !hasEnteredTaskText || !isCreateTaskCommitted
      case .edit:
         return !hasEnteredTaskText || !hasPendingEditChanges
      }
   }

   private var primaryActionAccessibilityLabel: String {
      switch mode {
      case .create:
         return "Create"
      case .edit:
         return "Update"
      }
   }

   private var hasPendingChanges: Bool {
      switch mode {
      case .create:
         return hasPendingCreateChanges
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
               Text("Selected (\(selectedTags.count)/\(ToDo.maxTagSelection))")
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
               Text("Up to \(ToDo.maxTagSelection) tags per toDo")
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

   private var selectedTags: [Tag] {
      selectedTagIDs.compactMap { id in
         tagList.first(where: { $0.id == id })
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
      
      return current != start
   }

   private var hasPendingCreateChanges: Bool {
      guard case .create = mode else { return false }
      let hasTask = hasEnteredTaskText
      let hasNotes = !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      let changedTag = selectedTagIDs != initialCreateSelectedTagIDs
      let changedReminderIntent = hasDueDate && reminderIntent != .due
      let changedRecurrence = hasDueDate && isRecurring
      return hasTask || hasNotes || isDone || hasDueDate || changedTag || changedReminderIntent || changedRecurrence || !createNanoDos.isEmpty
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
      let nanoDoCount = scopedNanoDos.filter { $0.tag?.id == tag.id }.count
      return toDoCount + nanoDoCount
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
      Text("\(task.count)/\(Self.taskCharacterLimit)")
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
      HStack(alignment: .top, spacing: 10) {
         TextField("nanoDo task", text: nanoDo.task, axis: .vertical)
            .lineLimit(1...3)
            .font(.appBody(16, relativeTo: .subheadline))
         
         if nanoDo.wrappedValue.hasDueDate {
            DatePicker(
               "",
               selection: nanoDo.dueDate,
               displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .font(.appBody(12, relativeTo: .caption))
         } else {
            Button {
               withAnimation(.snappy(duration: 0.22)) {
                  nanoDo.wrappedValue.hasDueDate = true
               }
            } label: {
               Label("Due?", systemImage: "calendar")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.actionPrimary)
            }
            .buttonStyle(.plain)
         }
         
         Button(role: .destructive) {
            removeCreateNanoDo(id: nanoDo.wrappedValue.id)
         } label: {
            Image(systemName: "xmark.circle.fill")
               .foregroundStyle(AppColor.textSecondary)
         }
         .buttonStyle(.plain)
      }
   }
   
   private func removeCreateNanoDo(id: UUID) {
      createNanoDos.removeAll { $0.id == id }
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
      let selectedTags = selectedTagIDs.compactMap { id in
         tagList.first(where: { $0.id == id })
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
      case .edit(let toDo, _):
         toDo.task = trimmedTask
         toDo.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
         toDo.transition(to: isDone ? .done : .active)
         toDo.dueDate = resolvedDueDate
         toDo.reminderIntent = resolvedReminderIntent
         toDo.recurrenceUnit = resolvedRecurrenceUnit
         toDo.recurrenceInterval = resolvedRecurrenceInterval
         toDo.recurrenceMode = resolvedRecurrenceMode
         toDo.recurrenceCount = resolvedRecurrenceCount
         toDo.recurrenceAnchorDate = resolvedRecurrenceAnchorDate
         toDo.recurrenceEndDate = nil
         if !isRecurring || !hasDueDate {
            toDo.clearRecurrence()
         }
         toDo.setSelectedTags(selectedTags)
         toDo.markUpdated()
         savedToDo = toDo
      }

      do {
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         SyncCoordinator.shared.scheduleLocalSync()
      } catch {
         saveErrorMessage = "ToDo couldn’t save this change. \(error.localizedDescription)"
         print("Failed to save ToDo changes: \(error)")
         return
      }
      
      dismissComposer(savedToDo: savedToDo)
   }
   
   private func deleteNanoDo(_ nanoDo: NanoDo) {
      guard let toDo = editingToDo else { return }
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

private struct TagPillFlowLayout: Layout {
   var spacing: CGFloat
   var rowSpacing: CGFloat
   
   func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      let maxWidth = proposal.width ?? .greatestFiniteMagnitude
      var x: CGFloat = 0
      var y: CGFloat = 0
      var rowHeight: CGFloat = 0
      var usedWidth: CGFloat = 0
      
      for subview in subviews {
         let size = subview.sizeThatFits(.unspecified)
         let nextX = x == 0 ? size.width : x + spacing + size.width
         
         if nextX > maxWidth, x > 0 {
            usedWidth = max(usedWidth, x)
            x = size.width
            y += rowHeight + rowSpacing
            rowHeight = size.height
         } else {
            x = nextX
            rowHeight = max(rowHeight, size.height)
         }
      }
      
      usedWidth = max(usedWidth, x)
      return CGSize(width: proposal.width ?? usedWidth, height: y + rowHeight)
   }
   
   func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
      let maxX = bounds.maxX
      var x = bounds.minX
      var y = bounds.minY
      var rowHeight: CGFloat = 0
      
      for subview in subviews {
         let size = subview.sizeThatFits(.unspecified)
         let needsWrap = x > bounds.minX && (x + spacing + size.width > maxX)
         if needsWrap {
            x = bounds.minX
            y += rowHeight + rowSpacing
            rowHeight = 0
         } else if x > bounds.minX {
            x += spacing
         }
         
         subview.place(
            at: CGPoint(x: x, y: y),
            proposal: ProposedViewSize(width: size.width, height: size.height)
         )
         x += size.width
         rowHeight = max(rowHeight, size.height)
      }
   }
}

private struct NanoDoReadOnlyRowView: View {
   let nanoDo: NanoDo
   
   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         HStack(spacing: 8) {
            Image(systemName: nanoDo.isDone ? "checkmark.circle.fill" : "circle")
               .foregroundStyle(nanoDo.isDone ? AppColor.actionPrimary : AppColor.textSecondary)
            Text(nanoDo.task)
               .foregroundStyle(AppColor.textPrimary)
         }
         
         if let dueDate = nanoDo.dueDate {
            Text(dueDate.formatted(date: .abbreviated, time: .shortened))
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
   }
}

private struct NanoDoRowView: View {
   @Bindable var nanoDo: NanoDo
   
   var body: some View {
      VStack(alignment: .leading, spacing: 6) {
         HStack {
            Toggle("", isOn: Binding(
               get: { nanoDo.isDone },
               set: {
                  nanoDo.isDone = $0
                  nanoDo.markUpdated()
                  SyncCoordinator.shared.scheduleLocalSync()
               }
            ))
               .labelsHidden()
            TextField("NanoDo", text: Binding(
               get: { nanoDo.task },
               set: {
                  nanoDo.task = $0
                  nanoDo.markUpdated()
                  SyncCoordinator.shared.scheduleLocalSync()
               }
            ))
         }
         
         if let dueDate = nanoDo.dueDate {
            DatePicker("Due", selection: Binding(
               get: { dueDate },
               set: {
                  nanoDo.dueDate = $0
                  nanoDo.markUpdated()
                  SyncCoordinator.shared.scheduleLocalSync()
               }
            ), displayedComponents: .date)
            .datePickerStyle(.compact)
            Button("Clear due date") {
               nanoDo.dueDate = nil
               nanoDo.markUpdated()
               SyncCoordinator.shared.scheduleLocalSync()
            }
            .font(.appBody(12, relativeTo: .caption))
         } else {
            Button("Add due date") {
               nanoDo.dueDate = Date()
               nanoDo.markUpdated()
               SyncCoordinator.shared.scheduleLocalSync()
            }
            .font(.appBody(12, relativeTo: .caption))
         }
      }
   }
}

#Preview {
   let container = PreviewSupport.makeModelContainer()
   let toDo = ToDo(task: "Preview ToDo", notes: "Sample notes", dueDate: Date())
   let nano = NanoDo(task: "NanoDo", toDo: toDo)
   toDo.nanoDos = [nano]
   container.mainContext.insert(toDo)
   return NavigationStack {
      ToDoView(mode: .edit(toDo, context: .pushed))
   }
   .modelContainer(container)
   .environmentObject(SupabaseAuthStore.preview)
}

#Preview("iPad Inline Edit") {
   let container = PreviewSupport.makeModelContainer()
   let toDo = ToDo(
      task: "Preview inline edit",
      notes: "This preview matches the iPad detail-panel edit container.",
      dueDate: Date()
   )
   let nano = NanoDo(task: "Confirm details panel behavior", toDo: toDo)
   toDo.nanoDos = [nano]
   container.mainContext.insert(toDo)
   container.mainContext.insert(nano)

   return ToDoView(
      mode: .edit(toDo, context: .sheet),
      isInlineOverlayEdit: true
   )
   .frame(width: 720, height: 820)
   .modelContainer(container)
   .environmentObject(SupabaseAuthStore.preview)
}
