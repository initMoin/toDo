package dev.iamshift.todo.android.ui

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.TextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoReminderIntent
import dev.iamshift.todo.android.core.model.NanoDo
import dev.iamshift.todo.android.ui.theme.BrandSecondary
import dev.iamshift.todo.android.ui.theme.ToDoShapes
import dev.iamshift.todo.android.ui.theme.ToDoSpacing
import dev.iamshift.todo.android.ui.theme.ToDoTextStyles
import dev.iamshift.todo.android.ui.theme.ToDoTypography
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val dueFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("EEE, MMM d, yyyy · h:mm a", Locale.getDefault())

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun ToDoDetailDialog(
    toDo: ToDo,
    useBottomSheet: Boolean,
    onDismiss: () -> Unit,
    onUpdate: (ToDo) -> Unit,
    onMoveToTrash: () -> Unit
) {
    var isEditing by rememberSaveable(toDo.id.toString()) { mutableStateOf(false) }

    val content: @Composable () -> Unit = {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .widthIn(max = 960.dp)
                .padding(if (useBottomSheet) 0.dp else 12.dp),
            shape = ToDoShapes.hero,
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 4.dp
        ) {
            if (isEditing) {
                ToDoEditorContent(
                    toDo = toDo,
                    onCancel = { isEditing = false },
                    onSave = { updated ->
                        onUpdate(updated)
                        isEditing = false
                    }
                )
            } else {
                ToDoDetailContent(
                    toDo = toDo,
                    onEdit = { isEditing = true },
                    onDismiss = onDismiss,
                    onUpdate = onUpdate,
                    onMoveToTrash = onMoveToTrash
                )
            }
        }
    }

    if (useBottomSheet) {
        ModalBottomSheet(onDismissRequest = onDismiss) {
            content()
        }
    } else {
        Dialog(
            onDismissRequest = onDismiss,
            properties = DialogProperties(
                usePlatformDefaultWidth = false,
                dismissOnBackPress = true,
                dismissOnClickOutside = true
            )
        ) {
            content()
        }
    }
}

@Composable
private fun ToDoDetailContent(
    toDo: ToDo,
    onEdit: () -> Unit,
    onDismiss: () -> Unit,
    onUpdate: (ToDo) -> Unit,
    onMoveToTrash: () -> Unit
) {
    val isLate = toDo.isLate()

    Column(modifier = Modifier.fillMaxHeight()) {
        DetailHeader(
            title = "toDō",
            onClose = onDismiss,
            action = {
                IconButton(onClick = onEdit) {
                    Icon(Icons.Default.Edit, contentDescription = "Edit toDō")
                }
            }
        )

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(horizontal = ToDoSpacing.screen, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Text(
                    text = toDo.task,
                    style = ToDoTextStyles.detailTitle
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = if (toDo.isDone) "Done" else if (isLate) "Overdue" else "Active",
                    color = when {
                        toDo.isDone -> MaterialTheme.colorScheme.tertiary
                        isLate -> MaterialTheme.colorScheme.error
                        else -> MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    style = ToDoTextStyles.statLabel
                )
            }

            item {
                DetailSectionCard {
                    DetailAttribute(
                        label = "Due",
                        value = toDo.dueAt?.let(::formatDue) ?: "No due date",
                        icon = Icons.Default.DateRange,
                        valueColor = if (isLate) MaterialTheme.colorScheme.error else null
                    )
                    Spacer(Modifier.height(12.dp))
                    DetailAttribute(
                        label = "Reminder",
                        value = reminderLabel(toDo.reminderIntent),
                        icon = Icons.Default.Notifications
                    )
                }
            }

            if (toDo.recurrence != null) {
                item {
                    DetailSectionCard {
                        Text("Recurrence", style = ToDoTextStyles.statLabel)
                        Text(
                            "Every ${toDo.recurrence.interval} ${toDo.recurrence.unit.rawValue}",
                            style = ToDoTextStyles.body
                        )
                    }
                }
            }

            if (toDo.locationReminder != null) {
                item {
                    DetailSectionCard {
                        Text("Location reminder", style = ToDoTextStyles.statLabel)
                        Text(
                            toDo.locationReminder.label ?: "Saved location",
                            style = ToDoTextStyles.body
                        )
                    }
                }
            }

            if (toDo.nanoDos.isNotEmpty()) {
                item {
                    Text("NanoDos", style = ToDoTextStyles.sectionLabel)
                }
                items(toDo.orderedNanoDos, key = { it.id }) { nanoDo ->
                    NanoDoRow(
                        nanoDo = nanoDo,
                        onToggle = { isDone ->
                            val updatedNanoDos = toDo.nanoDos.map { current ->
                                if (current.id == nanoDo.id) {
                                    current.transitionToDone(isDone)
                                } else {
                                    current
                                }
                            }
                            val updated = toDo.withNanoDos(updatedNanoDos)
                                .completeIfAllNanoDosAreDone()
                            onUpdate(updated)
                        }
                    )
                }
            }

            if (toDo.notes.isNotBlank()) {
                item {
                    DetailSectionCard {
                        Text("Notes", style = ToDoTextStyles.statLabel)
                        Text(
                            toDo.notes,
                            style = ToDoTextStyles.body.copy(
                                fontFamily = ToDoTypography.longForm
                            )
                        )
                    }
                }
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = ToDoSpacing.screen, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            FilledTonalButton(
                onClick = { onUpdate(toDo.toggleDone()) },
                shape = ToDoShapes.control
            ) {
                Icon(
                    imageVector = if (toDo.isDone) Icons.Default.Refresh else Icons.Default.Check,
                    contentDescription = null
                )
                Spacer(Modifier.size(8.dp))
                Text(if (toDo.isDone) "Reopen" else "Complete")
            }
            Spacer(Modifier.weight(1f))
            TextButton(onClick = onMoveToTrash) {
                Icon(Icons.Default.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error)
                Spacer(Modifier.size(4.dp))
                Text("Trash", color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun ToDoEditorContent(
    toDo: ToDo,
    onCancel: () -> Unit,
    onSave: (ToDo) -> Unit
) {
    var task by rememberSaveable(toDo.id.toString()) { mutableStateOf(toDo.task) }
    var notes by rememberSaveable(toDo.id.toString()) { mutableStateOf(toDo.notes) }
    var hasDueDate by rememberSaveable(toDo.id.toString()) { mutableStateOf(toDo.dueAt != null) }
    var dueEpochMillis by rememberSaveable(toDo.id.toString()) {
        mutableStateOf(toDo.dueAt?.toEpochMilli() ?: Instant.now().plusSeconds(3_600).toEpochMilli())
    }
    var reminderRaw by rememberSaveable(toDo.id.toString()) {
        mutableStateOf(toDo.reminderIntent.rawValue)
    }
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }

    val reminderIntent = ToDoReminderIntent.fromRawValue(reminderRaw)
        ?: ToDoReminderIntent.SOFT

    Column(modifier = Modifier.fillMaxHeight()) {
        DetailHeader(
            title = "Edit toDō",
            onClose = onCancel,
            action = {
                TextButton(
                    onClick = {
                        val updated = toDo
                            .withTask(task)
                            .withNotes(notes)
                            .withSchedule(
                                dueAt = if (hasDueDate) Instant.ofEpochMilli(dueEpochMillis) else null,
                                dueTimeZone = if (hasDueDate) ZoneId.systemDefault().id else null,
                                reminderIntent = if (hasDueDate) reminderIntent else ToDoReminderIntent.SOFT
                            )
                        onSave(updated)
                    },
                    enabled = task.isNotBlank()
                ) {
                    Text("Save")
                }
            }
        )

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(horizontal = ToDoSpacing.screen, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                TextField(
                    value = task,
                    onValueChange = { task = it },
                    label = { Text("Title") },
                    textStyle = ToDoTextStyles.detailTitle.copy(fontSize = 20.sp, lineHeight = 26.sp),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = ToDoShapes.small,
                    colors = ToDoTextFieldColors()
                )
            }
            item {
                TextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes") },
                    textStyle = ToDoTextStyles.body.copy(fontFamily = ToDoTypography.userEntry),
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 4,
                    shape = ToDoShapes.small,
                    colors = ToDoTextFieldColors()
                )
            }
            item {
                DetailSectionCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text("Due date", style = ToDoTextStyles.statLabel)
                            Text(
                                if (hasDueDate) formatDue(Instant.ofEpochMilli(dueEpochMillis))
                                else "No due date",
                                style = ToDoTextStyles.body,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = hasDueDate,
                            onCheckedChange = { hasDueDate = it }
                        )
                    }

                    if (hasDueDate) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            FilledTonalButton(
                                onClick = { showDatePicker = true },
                                modifier = Modifier.weight(1f),
                                shape = ToDoShapes.control
                            ) {
                                Icon(Icons.Default.DateRange, contentDescription = null)
                                Spacer(Modifier.size(8.dp))
                                Text("Date", maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                            FilledTonalButton(
                                onClick = { showTimePicker = true },
                                modifier = Modifier.weight(1f),
                                shape = ToDoShapes.control
                            ) {
                                Icon(Icons.Default.Notifications, contentDescription = null)
                                Spacer(Modifier.size(8.dp))
                                Text("Time", maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                        }
                    }
                }
            }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Reminder intent", style = ToDoTextStyles.statLabel)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        ToDoReminderIntent.values().forEach { option ->
                            FilterChip(
                                selected = reminderIntent == option,
                                onClick = { reminderRaw = option.rawValue },
                                enabled = hasDueDate,
                                label = {
                                    Text(
                                        reminderLabel(option),
                                        maxLines = 1,
                                        style = ToDoTextStyles.rowMetadata
                                    )
                                },
                                colors = FilterChipDefaults.filterChipColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                    labelColor = MaterialTheme.colorScheme.onSurface,
                                    selectedContainerColor = BrandSecondary,
                                    selectedLabelColor = Color.White
                                ),
                                border = null,
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                    if (!hasDueDate) {
                        Text(
                            "Add a due date before choosing a reminder intent.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            style = ToDoTextStyles.rowMetadata
                        )
                    }
                }
            }
        }
    }

    EditorDatePicker(
        visible = showDatePicker,
        initialEpochMillis = dueEpochMillis,
        onDateSelected = { dueEpochMillis = it; showDatePicker = false },
        onDismiss = { showDatePicker = false }
    )
    EditorTimePicker(
        visible = showTimePicker,
        initialEpochMillis = dueEpochMillis,
        onTimeSelected = { dueEpochMillis = it; showTimePicker = false },
        onDismiss = { showTimePicker = false }
    )
}

@Composable
private fun DetailHeader(
    title: String,
    onClose: () -> Unit,
    action: @Composable () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 8.dp, end = 8.dp, top = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onClose) {
            Icon(Icons.Default.Close, contentDescription = "Close")
        }
        Text(title, style = ToDoTextStyles.viewTitle.copy(fontSize = 24.sp, lineHeight = 28.sp))
        Spacer(Modifier.weight(1f))
        action()
    }
}

@Composable
private fun DetailSectionCard(content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(ToDoSpacing.card),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            content()
        }
    }
}

@Composable
private fun DetailAttribute(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    valueColor: androidx.compose.ui.graphics.Color? = null
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        Spacer(Modifier.size(12.dp))
        Column {
            Text(label, style = ToDoTextStyles.statLabel)
            Text(
                value,
                style = ToDoTextStyles.body,
                color = valueColor ?: MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun NanoDoRow(nanoDo: NanoDo, onToggle: (Boolean) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(checked = nanoDo.isDone, onCheckedChange = onToggle)
            Text(
                text = nanoDo.task,
                modifier = Modifier.weight(1f),
                style = ToDoTextStyles.rowTitle
            )
        }
    }
}

@Composable
private fun EditorDatePicker(
    visible: Boolean,
    initialEpochMillis: Long,
    onDateSelected: (Long) -> Unit,
    onDismiss: () -> Unit
) {
    if (!visible) return

    val context = LocalContext.current
    val initial = Instant.ofEpochMilli(initialEpochMillis)
        .atZone(ZoneId.systemDefault())
        .toLocalDate()

    LaunchedEffect(initialEpochMillis) {
        DatePickerDialog(
            context,
            { _, year, month, day ->
                val currentTime = Instant.ofEpochMilli(initialEpochMillis)
                    .atZone(ZoneId.systemDefault())
                    .toLocalTime()
                val selected = java.time.LocalDate.of(year, month + 1, day)
                    .atTime(currentTime)
                    .atZone(ZoneId.systemDefault())
                    .toInstant()
                onDateSelected(selected.toEpochMilli())
            },
            initial.year,
            initial.monthValue - 1,
            initial.dayOfMonth
        ).also { dialog ->
            dialog.setOnCancelListener { onDismiss() }
            dialog.setOnDismissListener { onDismiss() }
            dialog.show()
        }
    }
}

@Composable
private fun EditorTimePicker(
    visible: Boolean,
    initialEpochMillis: Long,
    onTimeSelected: (Long) -> Unit,
    onDismiss: () -> Unit
) {
    if (!visible) return

    val context = LocalContext.current
    val initial = Instant.ofEpochMilli(initialEpochMillis)
        .atZone(ZoneId.systemDefault())
        .toLocalTime()

    LaunchedEffect(initialEpochMillis) {
        TimePickerDialog(
            context,
            { _, hour, minute ->
                val currentDate = Instant.ofEpochMilli(initialEpochMillis)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
                val selected = currentDate
                    .atTime(hour, minute)
                    .atZone(ZoneId.systemDefault())
                    .toInstant()
                onTimeSelected(selected.toEpochMilli())
            },
            initial.hour,
            initial.minute,
            false
        ).also { dialog ->
            dialog.setOnCancelListener { onDismiss() }
            dialog.setOnDismissListener { onDismiss() }
            dialog.show()
        }
    }
}

private fun formatDue(instant: Instant): String =
    dueFormatter.format(instant.atZone(ZoneId.systemDefault()))

private fun reminderLabel(intent: ToDoReminderIntent): String = when (intent) {
    ToDoReminderIntent.SOFT -> "Quiet"
    ToDoReminderIntent.DUE -> "Due"
    ToDoReminderIntent.TIME_SENSITIVE -> "Time-sensitive"
}
