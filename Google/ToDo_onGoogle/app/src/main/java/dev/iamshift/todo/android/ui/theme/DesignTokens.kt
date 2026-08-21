package dev.iamshift.todo.android.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Shared Android spacing and shape decisions from the toDō design contract. */
object ToDoSpacing {
    val screen = 20.dp
    val compactScreen = 16.dp
    val section = 24.dp
    val card = 20.dp
    val control = 12.dp
    val icon = 8.dp
}

object ToDoShapes {
    val hero = RoundedCornerShape(30.dp)
    val card = RoundedCornerShape(20.dp)
    val control = RoundedCornerShape(18.dp)
    val small = RoundedCornerShape(14.dp)
}

/** Component roles keep each screen from inventing one-off typography. */
object ToDoTextStyles {
    val viewTitle = TextStyle(
        fontFamily = ToDoTypography.viewTitle,
        fontWeight = FontWeight.Bold,
        fontSize = 28.sp,
        lineHeight = 32.sp
    )

    val homeQuestion = TextStyle(
        fontFamily = ToDoTypography.ui,
        fontWeight = FontWeight.SemiBold,
        fontSize = 25.sp,
        lineHeight = 30.sp
    )

    val sectionLabel = TextStyle(
        fontFamily = ToDoTypography.display,
        fontWeight = FontWeight.Normal,
        fontSize = 22.sp,
        lineHeight = 26.sp
    )

    val button = TextStyle(
        fontFamily = ToDoTypography.display,
        fontWeight = FontWeight.Normal,
        fontSize = 18.sp,
        lineHeight = 20.sp
    )

    val dateContext = TextStyle(
        fontFamily = ToDoTypography.display,
        fontWeight = FontWeight.Normal,
        fontSize = 18.sp,
        lineHeight = 22.sp
    )

    val rowTitle = TextStyle(
        fontFamily = ToDoTypography.userEntry,
        fontWeight = FontWeight.Medium,
        fontSize = 17.sp,
        lineHeight = 22.sp
    )

    val detailTitle = TextStyle(
        fontFamily = ToDoTypography.userEntry,
        fontWeight = FontWeight.Medium,
        fontSize = 26.sp,
        lineHeight = 32.sp
    )

    val body = TextStyle(
        fontFamily = ToDoTypography.ui,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 22.sp
    )

    val rowMetadata = TextStyle(
        fontFamily = ToDoTypography.ui,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 18.sp
    )

    val statNumber = TextStyle(
        fontFamily = ToDoTypography.display,
        fontWeight = FontWeight.Normal,
        fontSize = 28.sp,
        lineHeight = 32.sp
    )

    val statLabel = TextStyle(
        fontFamily = ToDoTypography.ui,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 18.sp
    )
}
