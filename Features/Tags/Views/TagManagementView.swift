import SwiftUI
import SwiftData

struct TagManagementView: View {
    static let defaultTagNames = Tag.defaultTagNames
    private static let maxTagCharacterCount = 23

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore
    @Query private var tags: [Tag]
    @Query private var toDos: [ToDo]
    @Query private var nanoDos: [NanoDo]

    @AppStorage(AppPreferences.Keys.tagSortOption) private var tagSortOption = TagSortOption.name.rawValue
    @AppStorage(AppPreferences.Keys.tagSortAscending) private var tagSortAscending = TagSortOption.name.defaultAscending
    @AppStorage(AppPreferences.Keys.tagManagementDefaultTagsExpanded) private var isDefaultTagsExpanded = true

    @State private var newTagName = ""
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var isShowingResetTagsConfirmation = false
    @State private var isShowingResetTagsFinalConfirmation = false
    @State private var isShowingSortDialog = false
    @State private var isDeleteMode = false
    @State private var deleteModeShakeTrigger: CGFloat = 0
    @State private var duplicateHighlightName: String?
    @State private var isDuplicateHighlightActive = false
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isNewTagFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isSearchVisible {
                        searchBarRow
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                    }

                    addSection
                      .padding(.top, 16)

                    tagsSection
                        .padding(.top, 33)

                    defaultTagsSection
                        .padding(.top, 47)

                    Color.clear
                        .frame(height: 120)
                }
                .padding(.top, 86)
                .padding(.bottom, 8)
            }

            pinnedTitleHeader
        }
        .scrollIndicators(.hidden)
        .background(AppColor.surface)
        .onChange(of: normalizedNewTagName) { _, _ in
            syncDuplicateTagFeedback()
        }
        .overlay(alignment: .bottom) {
            bottomResetBar
        }
        .confirmationDialog("Reset all tags to defaults?", isPresented: $isShowingResetTagsConfirmation, titleVisibility: .visible) {
            Button("Continue", role: .destructive) {
                isShowingResetTagsFinalConfirmation = true
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes all existing tags and clears tag links on toDōs and nanoDos.")
        }
        .confirmationDialog("Final confirmation required", isPresented: $isShowingResetTagsFinalConfirmation, titleVisibility: .visible) {
            Button("Yes, Reset Everything", role: .destructive) {
                resetAllTagsToDefault()
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This cannot be undone.")
        }
        .tint(AppColor.actionPrimary)
        .appBaseTypography()
        .appNavigationChrome()
    }

    private var pinnedTitleHeader: some View {
        AppSettingsDetailHeader(title: "Manage Tags") {
            Button {
                if isSearchVisible {
                    isSearchFieldFocused = false
                    withAnimation(.snappy(duration: 0.20)) {
                        isSearchVisible = false
                    }
                } else {
                    withAnimation(.snappy(duration: 0.24, extraBounce: 0.02)) {
                        isSearchVisible = true
                    }
                    Task { @MainActor in
                        isSearchFieldFocused = true
                    }
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.appDisplay(14, relativeTo: .caption))
            }
            .buttonStyle(TagManagementToolbarButtonStyle(isToggled: isSearchVisible, size: 30))

            Button {
                isShowingSortDialog = true
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.appDisplay(14, relativeTo: .caption))
            }
            .buttonStyle(TagManagementToolbarButtonStyle(isToggled: isShowingSortDialog, size: 30))
            .popover(isPresented: $isShowingSortDialog, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                sortPopoverContent
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var addSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Add")

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        TextField("new tag", text: $newTagName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isNewTagFieldFocused)
                        .font(.appAccent(21, relativeTo: .subheadline))
                        .onChange(of: newTagName) { _, value in
                            if value.count > Self.maxTagCharacterCount {
                                newTagName = String(value.prefix(Self.maxTagCharacterCount))
                            }
                        }

                    Button {
                        handleTagFieldAction()
                    } label: {
                        Image(systemName: "plus")
                            .font(.appDisplay(15, relativeTo: .caption))
                            .foregroundStyle(addTagButtonForeground)
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(isDuplicateTagEntry ? 45 : 0))
                            .background(
                                Circle()
                                    .fill(addTagButtonBackground)
                            )
                            .overlay(
                                Circle()
                                    .stroke(addTagButtonBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isTagFieldActionEnabled ? 1 : 0.98)
                    .animation(AppAnimation.easeStandard, value: isTagFieldActionEnabled)
                    .animation(AppAnimation.easeStandard, value: isDuplicateTagEntry)
                    .interactionDisabled(!isTagFieldActionEnabled)
                    .accessibilityLabel(isDuplicateTagEntry ? "Clear tag text" : "Add tag")
                }
                .padding(.bottom, 10)

                Capsule()
                    .fill(AppColor.secondary)
                    .frame(height: 2)
                    .scaleEffect(x: isNewTagFieldFocused ? 1 : 0.001, y: 1, anchor: .leading)
                    .opacity(isNewTagFieldFocused ? 1 : 0)
                    .padding(.leading, 2)
                    .padding(.trailing, 44)
                    .padding(.bottom, 2)
                    .animation(AppAnimation.snappyStandard, value: isNewTagFieldFocused)
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Your Tags")

            if filteredTags.isEmpty {
                Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No tags yet" : "No matching tags")
                    .font(.appBody(12, relativeTo: .caption))
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                let usageCounts = usageCountsByTagID()
                tagFlow {
                    ForEach(filteredTags) { tag in
                        tagRow(for: tag, usageCounts: usageCounts)
                    }
                }
                .animation(AppAnimation.snappySection, value: filteredTags.map(\.id))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var defaultTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(AppAnimation.snappyFast) {
                    isDefaultTagsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Default Tags")
                        //.font(.appDisplay(14, relativeTo: .headline))
                      .font(.appDisplay(22, relativeTo: .title3))
                      .foregroundStyle(AppColor.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.appDisplay(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.textSecondary)
                        .rotationEffect(.degrees(isDefaultTagsExpanded ? 90 : 0))
                        .animation(AppAnimation.easeStandard, value: isDefaultTagsExpanded)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isDefaultTagsExpanded {
                if filteredDefaultTagNames.isEmpty {
                    Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No default tags" : "No matching default tags")
                        .font(.appBody(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    let defaultUsageCounts = defaultTagUsageCountsByNormalizedName()
                    tagFlow {
                        ForEach(Array(filteredDefaultTagNames.enumerated()), id: \.offset) { _, name in
                            let usageCount = defaultUsageCounts[Tag.normalizeName(name), default: 0]
                            tagPill(name: Tag.localizedDefaultName(name), usageCount: usageCount)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var sortOption: TagSortOption {
        TagSortOption.resolvedOption(from: tagSortOption)
    }

    private var visibleOwnerUserID: UUID? {
        guard supabaseAuthStore.effectiveSyncMode == .syncEverywhere else { return nil }
        return supabaseAuthStore.scopedOwnerUserID
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

    private var isSortAscending: Bool {
        TagSortOption.resolvedDirection(
            from: tagSortOption,
            storedDirection: UserDefaults.standard.object(forKey: AppPreferences.Keys.tagSortAscending) as? Bool
        )
    }

    private var sortedTags: [Tag] {
        let usageCounts = sortOption == .linked ? usageCountsByTagID() : [:]
        return TagSortOption.sortedTags(scopedTags, option: sortOption, isAscending: isSortAscending) { tag in
            usageCounts[tag.id, default: 0]
        }
    }

    private var filteredTags: [Tag] {
        let defaultTagNames = Set(Self.defaultTagNames)
        let customTags = sortedTags.filter { !defaultTagNames.contains($0.displayName) }
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return customTags }
        return customTags.filter { $0.displayName.localizedCaseInsensitiveContains(term) }
    }

    private var filteredDefaultTagNames: [String] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return Self.defaultTagNames }
        return Self.defaultTagNames.filter { $0.localizedCaseInsensitiveContains(term) }
    }

    private var searchBarRow: some View {
        searchBarView
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textSecondary)
            TextField("Search tags", text: $searchText)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.appBody(14, relativeTo: .subheadline))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .containerShape(.rect(cornerRadius: 14))
        .background(
            AppColor.surfaceMuted,
            in: .rect(cornerRadius: 14)
        )
    }

    private var resetTagsWarningButton: some View {
        Button {
            isShowingResetTagsConfirmation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.appDisplay(18, relativeTo: .headline))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset All Tags to Default")
                        .font(.appDisplay(18, relativeTo: .headline))
                    Text("Deletes current tags and clears existing tag links.")
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
    }

    private var bottomResetBar: some View {
        VStack(spacing: 0) {
            resetTagsWarningButton
                .padding(8)
                .containerShape(.rect(cornerRadius: 28))
                .background(
                    AppColor.surfaceElevated,
                    in: .rect(cornerRadius: 28)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var normalizedNewTagName: String {
        Tag.normalizeName(newTagName)
    }

    private var duplicateTagName: String? {
        let normalizedName = normalizedNewTagName
        guard !normalizedName.isEmpty else { return nil }
        if Self.defaultTagNames.contains(normalizedName) {
            return normalizedName
        }
        return existingCustomTag(named: normalizedName)?.displayName
    }

    private var isTagFieldActionEnabled: Bool {
        !normalizedNewTagName.isEmpty
    }

    private var isDuplicateTagEntry: Bool {
        duplicateTagName != nil
    }

    private var addTagButtonForeground: Color {
        isTagFieldActionEnabled ? AppColor.onAction : AppColor.textPrimary
    }

    private var addTagButtonBackground: Color {
        if isDuplicateTagEntry {
            return AppColor.actionDestructive
        }
        return isTagFieldActionEnabled ? AppColor.secondary : AppColor.surfaceMuted
    }

    private var addTagButtonBorder: Color {
        if isDuplicateTagEntry {
            return AppColor.actionDestructive
        }
        return isTagFieldActionEnabled ? AppColor.secondary : AppColor.border
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(LocalizedStringKey(title))
          .font(.appDisplay(22, relativeTo: .title3))
          .foregroundStyle(AppColor.secondary)
            .textCase(nil)
    }

    private func tagFlow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        TagFlowLayout(spacing: 10, rowSpacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func tagRow(for tag: Tag, usageCounts: [PersistentIdentifier: Int]) -> some View {
        interactiveTagPill(for: tag, usageCount: usageCounts[tag.id, default: 0])
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .scale(scale: 0.01).combined(with: .opacity)
                ))
            .animation(AppAnimation.snappyStandard, value: isDeleteMode)
    }

    private func interactiveTagPill(for tag: Tag, usageCount: Int) -> some View {
        tagPill(name: tag.displayName, usageCount: usageCount)
            .modifier(ShakeEffect(animatableData: deleteModeShakeTrigger))
            .overlay(alignment: .topTrailing) {
                if isDeleteMode {
                    Button {
                        deleteTagFromDeleteMode(tag)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.appDisplay(9, relativeTo: .caption2))
                            .foregroundStyle(AppColor.onAction)
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(AppColor.iconCircle)
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .animation(AppAnimation.easeStandard, value: isDeleteMode)
            .contentShape(Rectangle())
            .onTapGesture {
                if isDeleteMode {
                    exitDeleteMode()
                }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                enterDeleteMode()
            }
    }

    private func tagPill(name: String, usageCount: Int) -> some View {
        let isDuplicateHighlight = duplicateHighlightName == Tag.normalizeName(name) && isDuplicateHighlightActive

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name)
                .font(.appAccent(15, relativeTo: .subheadline))
                .foregroundStyle(isDuplicateHighlight ? AppColor.white : AppColor.textPrimary)

            Text(AppLocalization.numberString(usageCount))
                .font(.appBody(11, relativeTo: .caption2))
                .foregroundStyle(isDuplicateHighlight ? AppColor.white.opacity(0.9) : AppColor.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(isDuplicateHighlight ? AppColor.secondary : AppColor.surfaceMuted.opacity(0.7))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isDuplicateHighlight ? AppColor.secondary : AppColor.border.opacity(0.7), lineWidth: 1)
        )
        .animation(AppAnimation.easeStandard, value: isDuplicateHighlight)
    }

//    private func usageCountsByTagID() -> [PersistentIdentifier: Int] {
//        var counts: [PersistentIdentifier: Int] = [:]
//        for toDo in scopedToDos {
//            for tag in toDo.effectiveTags {
//                counts[tag.id, default: 0] += 1
//            }
//        }
//        for nanoDo in scopedNanoDos {
//            if let tagID = nanoDo.tag?.id {
//                counts[tagID, default: 0] += 1
//            }
//        }
//        return counts
//    }

   private func usageCountsByTagID() -> [PersistentIdentifier: Int] {
      let toDoIDs = scopedToDos.flatMap { $0.effectiveTags.map(\.id) }
      let nanoDoIDs = scopedNanoDos.compactMap { $0.tag?.id }
      let allIDs = toDoIDs + nanoDoIDs
      let grouped = Dictionary(grouping: allIDs, by: { $0 })

      return grouped.mapValues { $0.count }
   }

    private func handleTagFieldAction() {
        if isDuplicateTagEntry {
            clearNewTagEntry()
        } else {
            addTag()
        }
    }

    private func addTag() {
        let normalized = normalizedNewTagName
        guard !normalized.isEmpty else { return }
        if duplicateTagName != nil {
            syncDuplicateTagFeedback()
            return
        }
        context.insert(Tag(name: normalized, ownerUserID: visibleOwnerUserID))
        persistChanges("Failed to add tag")
        clearNewTagEntry()
    }

    private func existingCustomTag(named normalizedName: String) -> Tag? {
        let defaultTagNames = Set(Self.defaultTagNames)
        return scopedTags.first {
            !defaultTagNames.contains($0.displayName) && $0.displayName == normalizedName
        }
    }

    private func syncDuplicateTagFeedback() {
        guard let duplicateTagName else {
            withAnimation(AppAnimation.easeStandard) {
                isDuplicateHighlightActive = false
            }
            duplicateHighlightName = nil
            return
        }

        isNewTagFieldFocused = true
        self.duplicateHighlightName = duplicateTagName

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation(AppAnimation.easeStandard) {
                searchText = ""
            }
        }

        if Self.defaultTagNames.contains(duplicateTagName), !isDefaultTagsExpanded {
            withAnimation(AppAnimation.easeStandard) {
                isDefaultTagsExpanded = true
            }
        }

        withAnimation(AppAnimation.easeStandard) {
            isDuplicateHighlightActive = true
        }
    }

    private func clearNewTagEntry() {
        newTagName = ""
    }

    private func selectSortOption(_ option: TagSortOption) {
        let currentOption = sortOption
        let currentDirection = isSortAscending

        if currentOption == option {
            tagSortOption = option.rawValue
            tagSortAscending = !currentDirection
        } else {
            tagSortOption = option.rawValue
            tagSortAscending = option.defaultAscending
        }
    }

    private func menuDirection(for option: TagSortOption) -> Bool {
        if option == sortOption {
            return isSortAscending
        }
        return option.defaultAscending
    }

    private var sortPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sort Tags")
              .font(.appSubtitle(15, relativeTo: .subheadline)).bold()
                .foregroundStyle(AppColor.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(TagSortOption.allCases) { option in
                    Button {
                        selectSortOption(option)
                        isShowingSortDialog = false
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.appBodyStrong(14, relativeTo: .subheadline))
                                    .foregroundStyle(AppColor.textPrimary)

                                Text(option.directionTitle(isAscending: menuDirection(for: option)))
                                    .font(.appBody(11, relativeTo: .caption2))
                                    .foregroundStyle(AppColor.textSecondary)
                            }

                            Spacer(minLength: 8)

                            if option == sortOption {
                                Image(systemName: "checkmark")
                                    .font(.appBodyStrong(12, relativeTo: .caption))
                                    .foregroundStyle(AppColor.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Capsule(style: .continuous)
                                .fill(option == sortOption ? AppColor.surfaceMuted : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 236, alignment: .leading)
        .containerShape(.rect(cornerRadius: 22))
        .background(
            AppColor.surface,
            in: .rect(cornerRadius: 22)
        )
        .appBaseTypography()
    }

   private func defaultTagUsageCountsByNormalizedName() -> [String: Int] {
      let names = scopedToDos.flatMap { $0.effectiveTags.map { Tag.normalizeName($0.name) } }
      let grouped = Dictionary(grouping: names, by: { $0 })

      return grouped.mapValues { $0.count }
   }

    private func resetAllTagsToDefault() {
        for toDo in scopedToDos {
            toDo.setSelectedTags([])
        }
        for nanoDo in scopedNanoDos {
            nanoDo.tag = nil
            nanoDo.markUpdated()
        }
        for tag in scopedTags {
            SyncTombstoneStore.recordDelete(
                table: .tags,
                recordID: tag.cloudID,
                userID: tag.ownerUserID
            )
            context.delete(tag)
        }
        for name in Self.defaultTagNames {
            context.insert(Tag(name: name, ownerUserID: visibleOwnerUserID))
        }
        persistChanges("Failed to reset tags")
    }

    private func enterDeleteMode() {
        guard !isDeleteMode else { return }
        withAnimation(.linear(duration: 0.42)) {
            deleteModeShakeTrigger += 1
        }
        withAnimation(AppAnimation.snappyFast) {
            isDeleteMode = true
        }
    }

    private func exitDeleteMode() {
        withAnimation(AppAnimation.snappyFast) {
            isDeleteMode = false
        }
    }

    private func deleteTagFromDeleteMode(_ tag: Tag) {
        let shouldExitDeleteMode = filteredTags.count <= 1
        withAnimation(AppAnimation.snappySection) {
            deleteTag(tag)
            if shouldExitDeleteMode {
                isDeleteMode = false
            }
        }
    }

    private func deleteTag(_ tag: Tag) {
        for toDo in scopedToDos {
            let remaining = toDo.effectiveTags.filter { $0.id != tag.id }
            if remaining.count != toDo.effectiveTags.count {
                toDo.setSelectedTags(remaining)
            }
        }
        for nanoDo in scopedNanoDos where nanoDo.tag?.id == tag.id {
            nanoDo.tag = nil
            nanoDo.markUpdated()
        }
        SyncTombstoneStore.recordDelete(
            table: .tags,
            recordID: tag.cloudID,
            userID: tag.ownerUserID
        )
        context.delete(tag)
        persistChanges("Failed to delete tag")
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
}

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 3
    var shakesPerUnit: CGFloat = 5
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

private struct TagManagementToolbarButtonStyle: ButtonStyle {
    var isToggled: Bool
    var size: CGFloat = 30
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let isActive = isEnabled && (isToggled || configuration.isPressed)
        let foreground = AppColor.headerControlForeground(for: colorScheme)
        let background = AppColor.headerControlBackground(for: colorScheme)
        let border = isActive ? AppColor.border : AppColor.border

        return configuration.label
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background {
                if #unavailable(iOS 26.0) {
                    Circle()
                        .fill(background.opacity(isEnabled ? (isActive ? 0.28 : 1) : 0.3))
                }
            }
            .appInteractiveCircleGlass(tint: background.opacity(isEnabled ? (isActive ? 0.28 : 1) : 0.3))
            .overlay {
                if #unavailable(iOS 26.0) {
                    Circle()
                        .stroke(border.opacity(isEnabled ? 1 : 0.4), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(AppAnimation.easeFast, value: configuration.isPressed)
            .animation(AppAnimation.easeStandard, value: isToggled)
    }
}

private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > 0, currentX + size.width > maxWidth {
                totalHeight += currentRowHeight + rowSpacing
                currentX = 0
                currentRowHeight = 0
            }

            currentX += (currentX > 0 ? spacing : 0) + size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }

        if currentRowHeight > 0 {
            totalHeight += currentRowHeight
        }

        return CGSize(width: proposal.width ?? currentX, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

#Preview {
    let container = PreviewSupport.makeModelContainer()
    NavigationStack {
        TagManagementView()
    }
    .modelContainer(container)
    .environmentObject(SupabaseAuthStore.preview)
}
