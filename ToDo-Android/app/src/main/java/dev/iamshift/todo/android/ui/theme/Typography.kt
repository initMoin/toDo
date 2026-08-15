package dev.iamshift.todo.android.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import dev.iamshift.todo.android.R

/**
 * Semantic type roles from the shared toDō design contract.
 *
 * These are the licensed font files shared with the Apple implementation. The
 * semantic names keep screen code independent from the physical font assets.
 */
object ToDoTypography {
    val brand = FontFamily(Font(R.font.cal_sans_regular, FontWeight.Normal))
    val viewTitle = FontFamily(Font(R.font.cal_sans_ui, FontWeight.Bold))
    val ui = FontFamily(
        Font(R.font.jura_variable, FontWeight.Normal),
        Font(R.font.jura_variable, FontWeight.Medium),
        Font(R.font.jura_variable, FontWeight.SemiBold),
        Font(R.font.jura_variable, FontWeight.Bold)
    )
    val display = FontFamily(Font(R.font.bebas_neue, FontWeight.Normal))
    val longForm = FontFamily(Font(R.font.aleo_italic, FontWeight.Normal))
    val userEntry = FontFamily(
        Font(R.font.aleo_regular, FontWeight.Normal),
        Font(R.font.aleo_regular, FontWeight.Medium),
        Font(R.font.aleo_regular, FontWeight.SemiBold)
    )

    val material: Typography = Typography().let { defaults ->
        defaults.copy(
            displayLarge = defaults.displayLarge.copy(fontFamily = display),
            displayMedium = defaults.displayMedium.copy(fontFamily = display),
            displaySmall = defaults.displaySmall.copy(fontFamily = display),
            headlineLarge = defaults.headlineLarge.copy(
                fontFamily = viewTitle,
                fontWeight = FontWeight.Bold
            ),
            headlineMedium = defaults.headlineMedium.copy(
                fontFamily = viewTitle,
                fontWeight = FontWeight.Bold
            ),
            headlineSmall = defaults.headlineSmall.copy(
                fontFamily = viewTitle,
                fontWeight = FontWeight.Bold
            ),
            titleLarge = defaults.titleLarge.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Bold
            ),
            titleMedium = defaults.titleMedium.copy(
                fontFamily = ui,
                fontWeight = FontWeight.SemiBold
            ),
            titleSmall = defaults.titleSmall.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Medium
            ),
            bodyLarge = defaults.bodyLarge.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Normal
            ),
            bodyMedium = defaults.bodyMedium.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Normal
            ),
            bodySmall = defaults.bodySmall.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Normal
            ),
            labelLarge = defaults.labelLarge.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Bold
            ),
            labelMedium = defaults.labelMedium.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Medium
            ),
            labelSmall = defaults.labelSmall.copy(
                fontFamily = ui,
                fontWeight = FontWeight.Medium
            )
        )
    }
}
