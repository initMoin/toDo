import SwiftUI

struct SnoozeOptionsView: View {
   private struct EditorContext: Identifiable {
      let id = UUID()
      let unit: SnoozeUnit
      let existingValue: Int?
   }

   @AppStorage(SnoozePreferences.storageKey) private var snoozeOptionsStorage = SnoozePreferences.defaultEncodedString
   @State private var options: SnoozeOptionsStore
   @State private var editorContext: EditorContext?

   init() {
      let initial = UserDefaults.standard.string(forKey: SnoozePreferences.storageKey) ?? SnoozePreferences.defaultEncodedString
      _options = State(initialValue: SnoozePreferences.decode(initial))
   }

   var body: some View {
      ZStack(alignment: .top) {
         ScrollView {
            VStack(alignment: .leading, spacing: 24) {
               ForEach(SnoozeUnit.allCases) { unit in
                  snoozeSection(for: unit)
               }

               Button {
                  resetOptions()
               } label: {
                  HStack(spacing: 12) {
                     Image(systemName: "arrow.counterclockwise")
                        .font(.appDisplay(15, relativeTo: .subheadline))

                     VStack(alignment: .leading, spacing: 3) {
                        Text("Reset Snooze Options")
                           .font(.appBodyStrong(15, relativeTo: .subheadline))
                        Text("Restore every unit to the default preset values.")
                           .font(.appBody(12, relativeTo: .caption))
                           .foregroundStyle(AppColor.textSecondary)
                     }

                     Spacer(minLength: 0)
                  }
                  .foregroundStyle(AppColor.textPrimary)
                  .padding(.horizontal, 14)
                  .padding(.vertical, 12)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .containerShape(.rect(cornerRadius: 18))
                  .background(
                     AppColor.surfaceMuted,
                     in: .rect(corners: .concentric, isUniform: true)
                  )
               }
               .buttonStyle(.plain)

               Color.clear
                  .frame(height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 62)
            .padding(.bottom, 24)
         }

         pinnedTitleHeader
      }
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .appNavigationChrome()
      .sheet(item: $editorContext) { context in
         SnoozeValueEditorSheet(
            unit: context.unit,
            existingValue: context.existingValue,
            onSave: { value in
               saveOption(value, for: context.unit, replacing: context.existingValue)
            }
         )
         .presentationDetents([.fraction(0.32)])
         .presentationDragIndicator(.visible)
      }
      .onChange(of: options) { _, newValue in
         snoozeOptionsStorage = SnoozePreferences.encode(newValue)
         NotificationManager.shared.scheduleRefresh()
      }
   }

   private var pinnedTitleHeader: some View {
      VStack(spacing: 0) {
         Text("Snooze Options")
            .font(.appTitle(34, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 16)
            .padding(.top, -4)
            .padding(.bottom, 2)
            .background(AppColor.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func snoozeSection(for unit: SnoozeUnit) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(unit.title)
            .font(.appSubtitle(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textPrimary)

         VStack(alignment: .leading, spacing: 10) {
            ForEach(options.values(for: unit), id: \.self) { value in
               HStack(spacing: 12) {
                  Text(unit.displayLabel(for: value))
                     .font(.appBodyStrong(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)

                  Spacer(minLength: 0)

                  Button {
                     editorContext = EditorContext(unit: unit, existingValue: value)
                  } label: {
                     Image(systemName: "pencil")
                        .font(.appBodyStrong(12, relativeTo: .caption))
                  }
                  .buttonStyle(AppCircleActionButtonStyle(intent: .neutral, size: 28))

                  Button {
                     deleteOption(value, from: unit)
                  } label: {
                     Image(systemName: "trash")
                        .font(.appBodyStrong(12, relativeTo: .caption))
                  }
                  .buttonStyle(AppCircleActionButtonStyle(intent: .cancel, size: 28))
               }
            }

            Button {
               editorContext = EditorContext(unit: unit, existingValue: nil)
            } label: {
               HStack(spacing: 10) {
                  Image(systemName: "plus")
                     .font(.appBodyStrong(12, relativeTo: .caption))

                  Text("Add Custom Option")
                     .font(.appBodyStrong(14, relativeTo: .subheadline))
               }
               .foregroundStyle(AppColor.secondary)
               .padding(.horizontal, 12)
               .padding(.vertical, 10)
               .frame(maxWidth: .infinity, alignment: .leading)
               .containerShape(.rect(cornerRadius: 18))
               .background(
                  AppColor.secondary.opacity(0.08),
                  in: .rect(corners: .concentric, isUniform: true)
               )
            }
            .buttonStyle(.plain)
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

   private func saveOption(_ value: Int, for unit: SnoozeUnit, replacing existingValue: Int?) {
      var updated = options.values(for: unit)
      if let existingValue, let index = updated.firstIndex(of: existingValue) {
         updated[index] = value
      } else {
         updated.append(value)
      }
      options.setValues(updated, for: unit)
   }

   private func deleteOption(_ value: Int, from unit: SnoozeUnit) {
      var updated = options.values(for: unit)
      updated.removeAll { $0 == value }
      options.setValues(updated, for: unit)
   }

   private func resetOptions() {
      options = .default
   }
}

private struct SnoozeValueEditorSheet: View {
   @Environment(\.dismiss) private var dismiss

   let unit: SnoozeUnit
   let existingValue: Int?
   let onSave: (Int) -> Void

   @State private var valueText: String
   @FocusState private var isFocused: Bool

   init(unit: SnoozeUnit, existingValue: Int?, onSave: @escaping (Int) -> Void) {
      self.unit = unit
      self.existingValue = existingValue
      self.onSave = onSave
      _valueText = State(initialValue: existingValue.map(String.init) ?? "")
   }

   var body: some View {
      VStack(alignment: .leading, spacing: 18) {
         Text(existingValue == nil ? "Add \(unit.singularTitle) Option" : "Edit \(unit.singularTitle) Option")
            .font(.appTitle(28, relativeTo: .title2))
            .foregroundStyle(AppColor.textPrimary)

         TextField("Enter a value", text: $valueText)
            .keyboardType(.numberPad)
            .font(.appBodyStrong(18, relativeTo: .headline))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
               Color.white,
               in: .rect(cornerRadius: 18)
            )
            .focused($isFocused)

         Text("This option will appear in the \(unit.title.lowercased()) snooze menu.")
            .font(.appBody(13, relativeTo: .footnote))
            .foregroundStyle(AppColor.textSecondary)

         Spacer(minLength: 0)

         HStack(spacing: 12) {
            Button("Cancel") {
               dismiss()
            }
            .buttonStyle(.plain)
            .font(.appBodyStrong(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textSecondary)

            Spacer(minLength: 0)

            Button {
               guard let value = Int(valueText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
                  return
               }
               onSave(value)
               dismiss()
            } label: {
               Text(existingValue == nil ? "Add" : "Save")
                  .font(.appBodyStrong(15, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.onAction)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
                  .background(
                     AppColor.secondary,
                     in: .rect(corners: .concentric, isUniform: true)
                  )
            }
            .buttonStyle(.plain)
         }
      }
      .padding(20)
      .background(AppColor.surface)
      .onAppear {
         DispatchQueue.main.async {
            isFocused = true
         }
      }
   }
}

#Preview {
   NavigationStack {
      SnoozeOptionsView()
   }
}
