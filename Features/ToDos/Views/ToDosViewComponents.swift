import SwiftUI
import SwiftData
import Combine

struct RowContextMenuModifier<MenuContent: View>: ViewModifier {
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

struct ToDoListSection: Identifiable {
   let key: String
   let title: String
   var sortDate: Date = .distantPast
   var sortCount: Int = 0
   let toDos: [ToDo]

   var id: String { key }
}

struct PendingNotificationToDoRoute: Equatable {
   let localIdentifier: String?
   let cloudID: UUID?
}

struct TagSectionKey: Hashable {
   let key: String
   let title: String
}

enum ToDoCompletionAnimationPhase: Equatable {
   case none
   case striking
   case grayscale
   case dissolving

   var isAnimating: Bool {
      self != .none
   }
}

struct LiquidGlassPanelBackground: View {
   let tint: Color
   let cornerRadius: CGFloat
   let fallbackMaterial: Material

   var body: some View {
      if #available(iOS 26.0, *) {
         RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint.opacity(0.14))
            .glassEffect(
               .regular.tint(tint.opacity(0.58)),
               in: .rect(cornerRadius: cornerRadius)
            )
      } else {
         RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fallbackMaterial)
            .overlay {
               RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                  .fill(tint.opacity(0.18))
            }
      }
   }
}

struct DoneDrawerRowView: View {
   let toDo: ToDo
   let hasSyncConflict: Bool
   let onOpen: () -> Void
   let onReopen: () -> Void

   var body: some View {
      HStack(alignment: .top, spacing: 12) {
         Button(action: onReopen) {
            Image(systemName: "checkmark.circle.fill")
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(AppColor.actionPrimary)
               .frame(width: 22, height: 22)
         }
         .buttonStyle(.plain)
         .accessibilityLabel("Mark active")

         Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
               HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(toDo.task)
                     .font(.appDisplay(20, relativeTo: .headline))
                     .foregroundStyle(AppColor.textPrimary)
                     .strikethrough(true, color: AppColor.textPrimary.opacity(0.35))
                     .frame(maxWidth: .infinity, alignment: .leading)

                  if hasSyncConflict {
                     Image(systemName: "exclamationmark.triangle.fill")
                        .font(.appBodyStrong(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.secondary)
                        .accessibilityLabel("Sync needs review")
                  }
               }

               if hasMetadata {
                  HStack(spacing: 10) {
                     if toDo.dueDate != nil {
                        Image(systemName: "calendar")
                           .accessibilityLabel("Has due date")
                     }

                     if !toDo.nanoDos.isEmpty {
                        Label(AppLocalization.numberString(toDo.nanoDos.count), systemImage: "smallcircle.filled.circle")
                           .labelStyle(.titleAndIcon)
                           .accessibilityLabel(String(format: String(localized: "%@ nano tasks"), AppLocalization.numberString(toDo.nanoDos.count)))
                     }

                     if toDo.reminderIntent == .timeSensitive {
                        Image(systemName: "clock.fill")
                           .foregroundStyle(AppColor.actionDestructive)
                           .accessibilityLabel("Time-sensitive reminder")
                     }
                  }
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
               }
            }
            .contentShape(Rectangle())
         }
         .buttonStyle(.plain)
      }
      .padding(.vertical, 9)
      .padding(.horizontal, 12)
      .background(AppColor.surfaceMuted.opacity(0.55), in: .rect(cornerRadius: 18))
      .opacity(0.72)
   }

   private var hasMetadata: Bool {
      toDo.dueDate != nil || !toDo.nanoDos.isEmpty || toDo.reminderIntent == .timeSensitive
   }
}

struct ToDoRowView: View {
   @ScaledMetric(relativeTo: .headline) private var leadingCircleSymbolSize: CGFloat = 20
   @State private var titleFirstLineHeight: CGFloat = 0

   let toDo: ToDo
   let allowsCompletionToggle: Bool
   let isSelectionMode: Bool
   let isSelected: Bool
   let isDetailSelected: Bool
   let hasSyncConflict: Bool
   let showsCompletedState: Bool
   let completionAnimationPhase: ToDoCompletionAnimationPhase
   let onToggleDone: (Bool) -> Void
   let onToggleSelection: () -> Void
   let isTransitioningCompletion: Bool

   var body: some View {
      VStack(alignment: .leading, spacing: 0) {
         primaryRowContent
            .zIndex(1)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 12)
      .opacity(rowOpacity)
      .containerShape(.rect(cornerRadius: 18))
      .background(
         rowBackgroundColor,
         in: .rect(cornerRadius: 18)
      )
      .overlay(
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .inset(by: 2)
            .stroke(timeSensitiveBorderColor, lineWidth: timeSensitiveBorderWidth)
      )
      .saturation(rowSaturation)
      .compositingGroup()
      .animation(AppAnimation.easeFast, value: isSelected)
      .animation(AppAnimation.easeStandard, value: isTransitioningCompletion)
      .animation(AppAnimation.easeStandard, value: showsCompletedState)
      .animation(AppAnimation.easeStandard, value: completionAnimationPhase)
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
               AnimatedCompletionTaskText(
                  text: toDo.task,
                  isCompleted: showsCompletedState,
                  phase: completionAnimationPhase,
                  textColor: taskTextColor,
                  lineColor: taskTextColor.opacity(0.72),
                  firstLineHeightProbe: AnyView(firstLineHeightProbe)
               )

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
                        Text("+\(AppLocalization.numberString(additionalTagCount))")
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
               HStack(spacing: 7) {
                  if let dueDate = toDo.dueDate {
                     metadataChip(
                        systemName: "calendar",
                        text: AppLocalization.dateString(dueDate),
                        tint: dueDateChipTint,
                        foreground: dueDateChipForeground
                     )
                     .accessibilityLabel(String(format: String(localized: "Due %@"), AppLocalization.dateString(dueDate)))
                  }

                  if nanoDoCount > 0 {
                     metadataChip(
                        systemName: "smallcircle.filled.circle",
                        text: nanoDoChipText,
                        tint: nanoDoBadgeFill,
                        foreground: nanoDoBadgeTextColor
                     )
                     .accessibilityLabel(String(format: String(localized: "%@ nano tasks"), AppLocalization.numberString(nanoDoCount)))
                  }

                  if isTimeSensitiveReminder {
                     metadataChip(
                        systemName: "clock.fill",
                        text: toDo.reminderIntent.title,
                        tint: timeSensitiveChipTint,
                        foreground: timeSensitiveChipForeground
                     )
                        .accessibilityLabel("Time-sensitive reminder")
                  }
               }
               .lineLimit(1)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(metadataColor)
            }
         }
      }
   }

   private var taskTextColor: Color {
      if isDetailSelected {
         return AppColor.onAction
      }
      guard isOverdueStylingActive else { return AppColor.textPrimary }
      return AppColor.white
   }

   private var metadataColor: Color {
      if isDetailSelected {
         return AppColor.onAction.opacity(0.78)
      }
      guard isOverdueStylingActive else { return AppColor.textSecondary }
      return AppColor.white.opacity(0.86)
   }

   private var tagTextColor: Color {
      if isDetailSelected {
         return AppColor.actionPrimary
      }
      guard isOverdueStylingActive else { return AppColor.textPrimary }
      return overdueAccentColor
   }

   private var tagBackgroundColor: Color {
      if isDetailSelected {
         return AppColor.onAction.opacity(0.92)
      }
      guard isOverdueStylingActive else { return AppColor.surfaceMuted }
      return AppColor.white
   }

   private var syncConflictColor: Color {
      isOverdueStylingActive ? overdueAccentColor : AppColor.secondary
   }

   private var timeSensitiveIndicatorColor: Color {
      isOverdueStylingActive ? AppColor.white : AppColor.actionDestructive
   }

   private var rowBackgroundColor: Color {
      if completionAnimationPhase == .dissolving {
         return AppColor.surface
      }
      if completionAnimationPhase == .grayscale {
         return AppColor.surfaceMuted.opacity(0.74)
      }
      if isSelectionMode && isSelected {
         return isOverdueStylingActive ? overdueSurfaceColor : AppColor.actionSecondary.opacity(0.1)
      }
      if isDetailSelected {
         return AppColor.actionPrimary
      }
      return isOverdueStylingActive ? overdueSurfaceColor : AppColor.surfaceElevated
   }

   private var rowOpacity: Double {
      if completionAnimationPhase == .dissolving {
         return 0.04
      }
      if isDetailSelected {
         return 1
      }
      return showsCompletedState || completionAnimationPhase.isAnimating ? 0.72 : 1
   }

   private var rowSaturation: Double {
      completionAnimationPhase == .none ? 1 : 0
   }

   private var overdueSurfaceColor: Color {
      AppColor.actionDestructive
   }

   private var overdueAccentColor: Color {
      AppColor.actionDestructive
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
      toDo.dueDate != nil || !toDo.nanoDos.isEmpty || isTimeSensitiveReminder
   }

   private var isTimeSensitiveReminder: Bool {
      toDo.reminderIntent == .timeSensitive
   }

   private var timeSensitiveBorderColor: Color {
      guard isTimeSensitiveReminder && !showsCompletedState else { return .clear }
      return AppColor.actionDestructive
   }

   private var timeSensitiveBorderWidth: CGFloat {
      isTimeSensitiveReminder && !showsCompletedState ? 2 : 0
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

   private func metadataChip(systemName: String, text: String, tint: Color, foreground: Color) -> some View {
      HStack(spacing: 5) {
         Image(systemName: systemName)
            .font(.appBodyStrong(10, relativeTo: .caption2))

         Text(text)
            .font(.appAccent(11, relativeTo: .caption2))
      }
      .foregroundStyle(foreground)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
         Capsule()
            .fill(tint)
      )
   }

   private var dueDateChipTint: Color {
      if isOverdueStylingActive {
         return AppColor.white
      }
      return AppColor.actionPrimary.opacity(0.14)
   }

   private var dueDateChipForeground: Color {
      if isOverdueStylingActive {
         return overdueAccentColor
      }
      return AppColor.textPrimary
   }

   private var nanoDoChipText: String {
      if completedNanoDoCount > 0 {
         return "\(AppLocalization.numberString(completedNanoDoCount))/\(AppLocalization.numberString(nanoDoCount))"
      }
      return AppLocalization.numberString(nanoDoCount)
   }

   private var timeSensitiveChipTint: Color {
      if isOverdueStylingActive {
         return AppColor.white.opacity(0.22)
      }
      return AppColor.actionDestructive.opacity(0.12)
   }

   private var timeSensitiveChipForeground: Color {
      if isOverdueStylingActive {
         return AppColor.white
      }
      return AppColor.actionDestructive
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

}

private struct AnimatedCompletionTaskText: View {
   let text: String
   let isCompleted: Bool
   let phase: ToDoCompletionAnimationPhase
   let textColor: Color
   let lineColor: Color
   let firstLineHeightProbe: AnyView

   @State private var strikeProgress: CGFloat = 0

   var body: some View {
      Text(text)
         .font(.appDisplay(22, relativeTo: .headline))
         .foregroundStyle(textColor)
         .frame(maxWidth: .infinity, alignment: .leading)
         .background(firstLineHeightProbe)
         .overlay(alignment: .leading) {
            GeometryReader { proxy in
               Capsule(style: .continuous)
                  .fill(lineColor)
                  .frame(width: proxy.size.width * strikeProgress, height: 2.2)
                  .offset(y: max(0, proxy.size.height * 0.53))
            }
            .allowsHitTesting(false)
         }
         .onAppear {
            strikeProgress = isCompleted || phase != .none ? 1 : 0
         }
         .onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .striking:
               strikeProgress = 0
               withAnimation(.linear(duration: 0.52)) {
                  strikeProgress = 1
               }
            case .none:
               strikeProgress = isCompleted ? 1 : 0
            case .grayscale, .dissolving:
               strikeProgress = 1
            }
         }
         .onChange(of: isCompleted) { _, newValue in
            if phase == .none {
               strikeProgress = newValue ? 1 : 0
            }
         }
   }
}

struct ToDoRowFirstLineHeightKey: PreferenceKey {
   static var defaultValue: CGFloat = 0

   static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = nextValue()
   }
}

enum PreviewContainerFactory {
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

struct SyncFeedbackOverlay: View {
   let feedback: SyncFeedback

   var body: some View {
      VStack {
         HStack(spacing: 12) {
            Image(systemName: styleIcon)
               .font(.appBodyStrong(16, relativeTo: .headline))
               .foregroundStyle(styleColor)

            VStack(alignment: .leading, spacing: 2) {
               Text(feedback.title)
                  .font(.appBodyStrong(14, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textPrimary)
               Text(feedback.message)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()
         }
         .padding(.horizontal, 16)
         .padding(.vertical, 12)
         .background(AppColor.surfaceElevated)
         .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
         .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
               .stroke(styleColor.opacity(0.2), lineWidth: 1)
         )
         .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
         .padding(.horizontal, 16)
         .padding(.top, 12)

         Spacer()
      }
   }

   private var styleColor: Color {
      switch feedback.style {
      case .success: return AppColor.tertiary
      case .warning: return AppColor.main
      case .failure: return AppColor.destructive
      }
   }

   private var styleIcon: String {
      switch feedback.style {
      case .success: return "checkmark.circle.fill"
      case .warning: return "exclamationmark.triangle.fill"
      case .failure: return "xmark.circle.fill"
      }
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

@MainActor
final class GuidedOnboardingManager: ObservableObject {
   static let shared = GuidedOnboardingManager()

   @Published private(set) var isActive: Bool
   @Published private(set) var currentStep: GuidedOnboardingStep
   @Published private(set) var highlightedToDoID: PersistentIdentifier?

   private let defaults: UserDefaults

   private init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      let didComplete = defaults.bool(forKey: AppPreferences.Keys.didCompleteOnboarding)
      let rawStep = defaults.string(forKey: AppPreferences.Keys.currentOnboardingStep)
      let restoredStep: GuidedOnboardingStep
      if let rawStep, let step = GuidedOnboardingStep(rawValue: rawStep) {
         restoredStep = step
      } else {
         restoredStep = .welcome
         if rawStep != nil {
            defaults.set(GuidedOnboardingStep.welcome.rawValue, forKey: AppPreferences.Keys.currentOnboardingStep)
         }
      }
      self.currentStep = restoredStep
      self.isActive = !didComplete || rawStep != nil
   }

   var canSkip: Bool {
      isActive && currentStep == .welcome
   }

   var blocksToDosChrome: Bool {
      isActive && currentStep.blocksToDosChrome
   }

   var blocksSettingsChrome: Bool {
      isActive && currentStep.blocksSettingsChrome
   }

   func startIfNeeded() {
      guard !defaults.bool(forKey: AppPreferences.Keys.didCompleteOnboarding) else { return }
      isActive = true
      if defaults.string(forKey: AppPreferences.Keys.currentOnboardingStep) == nil {
         setStep(.welcome)
      }
   }

   func restart() {
      defaults.set(false, forKey: AppPreferences.Keys.didCompleteOnboarding)
      defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboardingOnce)
      highlightedToDoID = nil
      isActive = true
      setStep(.welcome)
   }

   func advance(to step: GuidedOnboardingStep) {
      guard isActive else { return }
      setStep(step)
   }

   func recordCreatedToDo(_ toDo: ToDo) {
      highlightedToDoID = toDo.id
      setStep(.creationSuccess)
   }

   func complete() {
      defaults.set(true, forKey: AppPreferences.Keys.didCompleteOnboarding)
      defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboardingOnce)
      defaults.removeObject(forKey: AppPreferences.Keys.currentOnboardingStep)
      highlightedToDoID = nil
      currentStep = .completion
      isActive = false
   }

   func skipIfAllowed() {
      guard canSkip else { return }
      complete()
   }

   private func setStep(_ step: GuidedOnboardingStep) {
      currentStep = step
      defaults.set(step.rawValue, forKey: AppPreferences.Keys.currentOnboardingStep)
   }
}

enum GuidedOnboardingStep: String, CaseIterable {
   case welcome
   case highlightAddButton
   case openAddView
   case enterToDoText
   case saveToDo
   case creationSuccess
   case highlightSettings
   case signInAndSync
   case notificationPermission
   case archiveVsDelete
   case completion

   var spotlightID: OnboardingSpotlightID? {
      switch self {
      case .welcome, .openAddView, .archiveVsDelete, .completion:
         return nil
      case .highlightAddButton:
         return .addButton
      case .enterToDoText:
         return .taskField
      case .saveToDo:
         return .saveButton
      case .creationSuccess:
         return .createdToDo
      case .highlightSettings:
         return .settingsButton
      case .signInAndSync:
         return .settingsSync
      case .notificationPermission:
         return .settingsNotifications
      }
   }

   var blocksToDosChrome: Bool {
      switch self {
      case .welcome, .highlightAddButton, .creationSuccess, .highlightSettings:
         return true
      default:
         return false
      }
   }

   var blocksSettingsChrome: Bool {
      switch self {
      case .signInAndSync, .notificationPermission, .archiveVsDelete, .completion:
         return true
      default:
         return false
      }
   }
}

enum OnboardingSpotlightID: Hashable {
   case addButton
   case taskField
   case saveButton
   case createdToDo
   case settingsButton
   case settingsAccount
   case settingsNotifications
   case settingsSync
}

struct OnboardingSpotlightPreferenceKey: PreferenceKey {
   static var defaultValue: [OnboardingSpotlightID: Anchor<CGRect>] = [:]

   static func reduce(
      value: inout [OnboardingSpotlightID: Anchor<CGRect>],
      nextValue: () -> [OnboardingSpotlightID: Anchor<CGRect>]
   ) {
      value.merge(nextValue(), uniquingKeysWith: { _, new in new })
   }
}

extension View {
   func onboardingSpotlightAnchor(_ id: OnboardingSpotlightID) -> some View {
      anchorPreference(key: OnboardingSpotlightPreferenceKey.self, value: .bounds) { anchor in
         [id: anchor]
      }
   }
}

struct OnboardingCreatedRowAnchorModifier: ViewModifier {
   let isHighlighted: Bool

   func body(content: Content) -> some View {
      if isHighlighted {
         content.onboardingSpotlightAnchor(.createdToDo)
      } else {
         content
      }
   }
}

struct GuidedOnboardingOverlay: View {
   @ObservedObject var manager: GuidedOnboardingManager
   let anchors: [OnboardingSpotlightID: Anchor<CGRect>]
   let onPrimaryAction: (GuidedOnboardingStep) -> Void

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var isPulseVisible = false

   var body: some View {
      GeometryReader { proxy in
         let spotlightRect = resolvedSpotlightRect(in: proxy)

         ZStack {
            spotlightShield(in: proxy.size, spotlightRect: spotlightRect)
            spotlightCard(spotlightRect: spotlightRect, containerSize: proxy.size)
         }
         .animation(reduceMotion ? nil : AppAnimation.snappySection, value: manager.currentStep)
      }
      .ignoresSafeArea()
      .transition(.opacity)
      .onAppear {
         guard !reduceMotion else { return }
         withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            isPulseVisible = true
         }
      }
   }

   private func resolvedSpotlightRect(in proxy: GeometryProxy) -> CGRect? {
      guard manager.isActive,
            let id = manager.currentStep.spotlightID,
            let anchor = anchors[id] else {
         return nil
      }

      let rect = proxy[anchor]
      guard rect.width > 0, rect.height > 0 else { return nil }
      return rect.insetBy(dx: -10, dy: -10)
   }

   @ViewBuilder
   private func spotlightShield(in size: CGSize, spotlightRect: CGRect?) -> some View {
      let screen = CGRect(origin: .zero, size: size)

      ZStack {
         Path { path in
            path.addRect(screen)
            if let spotlightRect {
               path.addRoundedRect(in: spotlightRect, cornerSize: CGSize(width: 22, height: 22))
            }
         }
         .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
         .allowsHitTesting(false)

         if let spotlightRect {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
               .stroke(AppColor.main.opacity(isPulseVisible && !reduceMotion ? 0.92 : 0.68), lineWidth: 2)
               .frame(width: spotlightRect.width, height: spotlightRect.height)
               .position(x: spotlightRect.midX, y: spotlightRect.midY)
               .allowsHitTesting(false)

            OnboardingHitShield(screen: screen, hole: spotlightRect)
         } else {
            Color.clear
               .contentShape(Rectangle())
         }
      }
   }

   private func spotlightCard(spotlightRect: CGRect?, containerSize: CGSize) -> some View {
      let content = contentForCurrentStep
      let maxWidth = min(containerSize.width - 32, 430)
      let placement = cardPlacement(for: spotlightRect, containerSize: containerSize, maxWidth: maxWidth)

      return VStack(alignment: .leading, spacing: 14) {
         Label(content.title, systemImage: content.systemImage)
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

         Text(content.message)
            .font(.appBody(14, relativeTo: .body))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

         HStack(spacing: 10) {
            if let primaryTitle = content.primaryTitle {
               Button {
                  onPrimaryAction(manager.currentStep)
               } label: {
                  Text(primaryTitle)
                     .frame(maxWidth: .infinity)
               }
               .buttonStyle(GuidedOnboardingPrimaryButtonStyle())
            }

            if manager.canSkip {
               Button {
                  manager.skipIfAllowed()
               } label: {
                  Text("Skip")
                     .frame(maxWidth: content.primaryTitle == nil ? .infinity : nil)
               }
               .buttonStyle(GuidedOnboardingSecondaryButtonStyle())
            }
         }
      }
      .padding(20)
      .frame(width: maxWidth, alignment: .leading)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 28))
      .shadow(color: AppColor.shadow, radius: 28, x: 0, y: 14)
      .position(x: placement.x, y: placement.y)
   }

   private func cardPlacement(for spotlightRect: CGRect?, containerSize: CGSize, maxWidth: CGFloat) -> CGPoint {
      guard let spotlightRect else {
         return CGPoint(x: containerSize.width / 2, y: containerSize.height * 0.70)
      }

      let estimatedCardHeight: CGFloat = manager.currentStep == .completion ? 210 : 230
      let bottomSpace = containerSize.height - spotlightRect.maxY
      let topSpace = spotlightRect.minY
      let y: CGFloat

      if bottomSpace >= estimatedCardHeight + 24 {
         y = min(containerSize.height - estimatedCardHeight / 2 - 16, spotlightRect.maxY + estimatedCardHeight / 2 + 18)
      } else if topSpace >= estimatedCardHeight + 24 {
         y = max(estimatedCardHeight / 2 + 16, spotlightRect.minY - estimatedCardHeight / 2 - 18)
      } else {
         y = containerSize.height * 0.72
      }

      let preferredX = spotlightRect.midX
      let halfWidth = maxWidth / 2
      let x = min(max(preferredX, halfWidth + 16), containerSize.width - halfWidth - 16)
      return CGPoint(x: x, y: y)
   }

   private var contentForCurrentStep: GuidedOnboardingContent {
      switch manager.currentStep {
      case .welcome:
         return GuidedOnboardingContent(title: String(localized: "Welcome to toDō"), message: String(localized: "A focused task system designed for clarity, urgency, and momentum. Create what matters. Complete it intentionally. Keep moving."), systemImage: "target", primaryTitle: String(localized: "Begin"))
      case .highlightAddButton:
         return GuidedOnboardingContent(title: String(localized: "Create your first toDō"), message: String(localized: "Capture something important. A task, reminder, responsibility, or idea."), systemImage: "plus.circle.fill", primaryTitle: nil)
      case .openAddView:
         return GuidedOnboardingContent(title: String(localized: "Start simple"), message: String(localized: "Write the task exactly how you think about it."), systemImage: "square.and.pencil", primaryTitle: nil)
      case .enterToDoText:
         return GuidedOnboardingContent(title: String(localized: "Write the toDō"), message: String(localized: "Use your own words. Submit project proposal, pick up groceries, or call Sarah at 4 PM all work."), systemImage: "text.cursor", primaryTitle: nil)
      case .saveToDo:
         return GuidedOnboardingContent(title: String(localized: "Save the toDō"), message: String(localized: "toDō keeps your tasks organized and ready to act on."), systemImage: "checkmark.circle.fill", primaryTitle: nil)
      case .creationSuccess:
         return GuidedOnboardingContent(title: String(localized: "Good."), message: String(localized: "Your first toDō is now active. From here, you can complete, archive, and refine your workflow over time."), systemImage: "checkmark.seal.fill", primaryTitle: String(localized: "Continue"))
      case .highlightSettings:
         return GuidedOnboardingContent(title: String(localized: "Configure your workflow"), message: String(localized: "Customize how toDō behaves, syncs, and notifies you."), systemImage: "gearshape.fill", primaryTitle: nil)
      case .signInAndSync:
         return GuidedOnboardingContent(title: String(localized: "Sync across devices"), message: String(localized: "Your toDōs already work on this device.\n\nChoose iCloud for Apple-only sync, toDō Sync for account-based cross-platform sync, or stay local if you prefer no remote copy."), systemImage: "arrow.triangle.2.circlepath", primaryTitle: String(localized: "Continue with This Device Only"))
      case .notificationPermission:
         return GuidedOnboardingContent(title: String(localized: "Stay aware without distraction"), message: String(localized: "toDō can remind you when tasks become important."), systemImage: "bell.fill", primaryTitle: String(localized: "Enable Notifications"))
      case .archiveVsDelete:
         return GuidedOnboardingContent(title: String(localized: "Understand task lifecycle"), message: String(localized: "Completed tasks can be archived for future reference.\n\nDeleted tasks are permanently removed."), systemImage: "archivebox.fill", primaryTitle: String(localized: "Continue"))
      case .completion:
         return GuidedOnboardingContent(title: String(localized: "You're ready."), message: String(localized: "toDō is designed to adapt to your workflow over time.\n\nStart small. Refine continuously."), systemImage: "checkmark.circle.fill", primaryTitle: String(localized: "Enter toDō"))
      }
   }
}

struct GuidedOnboardingContent {
   let title: String
   let message: String
   let systemImage: String
   let primaryTitle: String?
}

struct OnboardingHitShield: View {
   let screen: CGRect
   let hole: CGRect

   var body: some View {
      ZStack(alignment: .topLeading) {
         shieldRect(CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: max(0, hole.minY - screen.minY)))
         shieldRect(CGRect(x: screen.minX, y: hole.maxY, width: screen.width, height: max(0, screen.maxY - hole.maxY)))
         shieldRect(CGRect(x: screen.minX, y: hole.minY, width: max(0, hole.minX - screen.minX), height: max(0, hole.height)))
         shieldRect(CGRect(x: hole.maxX, y: hole.minY, width: max(0, screen.maxX - hole.maxX), height: max(0, hole.height)))
      }
   }

   private func shieldRect(_ rect: CGRect) -> some View {
      Color.clear
         .contentShape(Rectangle())
         .frame(width: rect.width, height: rect.height)
         .position(x: rect.midX, y: rect.midY)
   }
}

struct GuidedOnboardingPrimaryButtonStyle: ButtonStyle {
   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.appBodyStrong(15, relativeTo: .subheadline))
         .foregroundStyle(AppColor.onAction)
         .padding(.horizontal, 16)
         .padding(.vertical, 14)
         .background {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(AppColor.actionPrimary.opacity(configuration.isPressed ? 0.75 : 1))
            }
         }
         .appInteractiveRoundedGlass(tint: AppColor.actionPrimary.opacity(configuration.isPressed ? 0.75 : 1), cornerRadius: 18)
   }
}

struct GuidedOnboardingSecondaryButtonStyle: ButtonStyle {
   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.appBodyStrong(15, relativeTo: .subheadline))
         .foregroundStyle(AppColor.textPrimary)
         .padding(.horizontal, 16)
         .padding(.vertical, 14)
         .background {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(AppColor.surfaceMuted.opacity(configuration.isPressed ? 0.65 : 1))
            }
         }
         .appInteractiveRoundedGlass(tint: AppColor.surfaceMuted.opacity(configuration.isPressed ? 0.65 : 1), cornerRadius: 18)
   }
}
