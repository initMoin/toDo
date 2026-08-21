package dev.iamshift.todo.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = BrandPrimary,
    onPrimary = AppOnActionLight,
    secondary = BrandSecondary,
    onSecondary = Color.White,
    tertiary = BrandTertiary,
    onTertiary = AppTextLight,
    secondaryContainer = AppSurfaceMutedLight,
    onSecondaryContainer = AppTextLight,
    error = BrandDestructive,
    onError = Color.White,
    background = AppSurfaceLight,
    surface = AppSurfaceLight,
    surfaceVariant = AppSurfaceElevatedLight,
    onBackground = AppTextLight,
    onSurface = AppTextLight,
    onSurfaceVariant = AppTextSecondaryLight,
    outline = AppTextLight.copy(alpha = 0.24f)
)

private val DarkColors = darkColorScheme(
    primary = BrandPrimaryDark,
    onPrimary = AppOnActionDark,
    secondary = BrandSecondaryDark,
    onSecondary = AppOnActionDark,
    tertiary = BrandTertiaryDark,
    onTertiary = AppOnActionDark,
    secondaryContainer = AppSurfaceMutedDark,
    onSecondaryContainer = AppTextDark,
    error = BrandDestructiveDark,
    onError = AppOnActionDark,
    background = AppSurfaceDark,
    surface = AppSurfaceDark,
    surfaceVariant = AppSurfaceElevatedDark,
    onBackground = AppTextDark,
    onSurface = AppTextDark,
    onSurfaceVariant = AppTextSecondaryDark,
    outline = AppTextDark.copy(alpha = 0.28f)
)

@Composable
fun ToDoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = ToDoTypography.material,
        content = content
    )
}
