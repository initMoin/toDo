package dev.iamshift.todo.android

import dev.iamshift.todo.android.ui.TABLET_MIN_WIDTH_DP
import dev.iamshift.todo.android.ui.usesExpandedNavigation
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdaptiveLayoutTest {
    @Test
    fun compactNavigationRemainsAtWidthsBelowTabletBoundary() {
        assertFalse(usesExpandedNavigation(TABLET_MIN_WIDTH_DP - 1))
    }

    @Test
    fun tabletBoundaryUsesExpandedNavigation() {
        assertTrue(usesExpandedNavigation(TABLET_MIN_WIDTH_DP))
    }

    @Test
    fun widerWindowsKeepExpandedNavigation() {
        assertTrue(usesExpandedNavigation(840))
    }
}
