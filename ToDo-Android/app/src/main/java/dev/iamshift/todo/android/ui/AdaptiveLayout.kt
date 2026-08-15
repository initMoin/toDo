package dev.iamshift.todo.android.ui

/**
 * The Android adaptive layout contract uses the platform's canonical 600dp
 * compact/tablet boundary. The decision is based on the available width, so
 * landscape phones and resizable windows adapt without device-model checks.
 */
internal const val TABLET_MIN_WIDTH_DP = 600

internal fun usesExpandedNavigation(widthDp: Int): Boolean =
    widthDp >= TABLET_MIN_WIDTH_DP
