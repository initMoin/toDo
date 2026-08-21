import SwiftUI
import SwiftData

struct BulkTagPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedTagID: PersistentIdentifier?
    let tags: [Tag]
    let onApply: (Tag) -> Void
    let onClear: () -> Void

    var body: some View {
        NavigationStack {
            List {
                AppLargeScreenTitle(title: "Bulk Tags")
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Section("Apply Tag") {
                    if tags.isEmpty {
                        Text("No tags available")
                            .foregroundStyle(AppColor.textSecondary)
                            .listRowBackground(AppColor.surfaceElevated)
                    } else {
                        ForEach(tags) { tag in
                            Button {
                                onApply(tag)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(tag.displayName)
                                        .foregroundStyle(AppColor.textPrimary)
                                    Spacer()
                                    if tag.id == selectedTagID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppColor.actionSecondary)
                                    }
                                }
                            }
                            .listRowBackground(AppColor.surfaceElevated)
                        }
                    }
                }

                Section("Other") {
                    Button("Clear all tags", role: .destructive) {
                        onClear()
                        dismiss()
                    }
                    .listRowBackground(AppColor.surfaceElevated)
                }
            }
            .appListChrome()
            .tint(AppColor.actionPrimary)
            .appBaseTypography()
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let tags = [Tag(name: "work"), Tag(name: "personal")]
    BulkTagPickerView(selectedTagID: nil, tags: tags, onApply: { _ in }, onClear: {})
}
