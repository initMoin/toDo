package dev.iamshift.todo.android.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import dev.iamshift.todo.android.ui.theme.BrandSecondary

/** Filled Android text fields keep editor surfaces calm while retaining a native focus cue. */
@Composable
internal fun ToDoTextFieldColors() = TextFieldDefaults.colors(
    focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
    disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant,
    focusedIndicatorColor = BrandSecondary,
    unfocusedIndicatorColor = Color.Transparent,
    disabledIndicatorColor = Color.Transparent
)
