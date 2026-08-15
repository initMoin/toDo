package dev.iamshift.todo.android.ui

import android.app.Application
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.snap
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.TextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.sp
import dev.iamshift.todo.android.R
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoState
import dev.iamshift.todo.android.core.auth.SupabaseAuthSessionProvider
import dev.iamshift.todo.android.core.auth.AuthenticatedAccount
import dev.iamshift.todo.android.core.settings.ToDoSettingsStore
import dev.iamshift.todo.android.core.settings.GuidedTourStep
import dev.iamshift.todo.android.core.settings.GuidedTourStore
import dev.iamshift.todo.android.core.sync.SyncWorkScheduler
import dev.iamshift.todo.android.ToDoStore
import dev.iamshift.todo.android.ui.theme.BrandPrimary
import dev.iamshift.todo.android.ui.theme.BrandSecondary
import dev.iamshift.todo.android.ui.theme.BrandTertiary
import dev.iamshift.todo.android.ui.theme.AppSurfaceMutedLight
import dev.iamshift.todo.android.ui.theme.AppSurfaceMutedDark
import dev.iamshift.todo.android.ui.theme.ToDoShapes
import dev.iamshift.todo.android.ui.theme.ToDoSpacing
import dev.iamshift.todo.android.ui.theme.ToDoTextStyles
import dev.iamshift.todo.android.ui.theme.ToDoTypography
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch

private enum class Destination(val label: String) {
    HOME("Home"),
    ALL("toDō"),
    STATS("Stats"),
    PROFILE("Profile"),
    SETTINGS("Settings")
}

private enum class HomeFilter {
    DUE_SOON,
    TIME_SENSITIVE,
    RECENT
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ToDoApp(
    store: ToDoStore,
    authSessionProvider: SupabaseAuthSessionProvider,
    settingsStore: ToDoSettingsStore,
    guidedTourStore: GuidedTourStore
) {
    val toDos by store.toDos.collectAsState()
    val account by authSessionProvider.account.collectAsState()
    val guidedTourActive by guidedTourStore.isActive.collectAsState()
    val guidedTourStep by guidedTourStore.currentStep.collectAsState()
    var destination by remember { mutableStateOf(Destination.HOME) }
    var showCreateDialog by rememberSaveable { mutableStateOf(false) }
    var selectedToDoId by rememberSaveable { mutableStateOf<String?>(null) }
    val beginCreate = {
        if (guidedTourActive && guidedTourStep == GuidedTourStep.HIGHLIGHT_ADD_BUTTON) {
            guidedTourStore.advanceTo(GuidedTourStep.OPEN_ADD_VIEW)
        }
        showCreateDialog = true
    }
    val selectedToDo = selectedToDoId?.let { rawId ->
        toDos.firstOrNull { it.id.toString() == rawId }
    }

    BackHandler(enabled = destination != Destination.HOME) {
        destination = Destination.HOME
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        val expandedNavigation = maxWidth >= TABLET_MIN_WIDTH_DP.dp

        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            floatingActionButton = {
                if (destination == Destination.ALL) {
                    ExtendedFloatingActionButton(
                        onClick = beginCreate,
                        icon = {
                            Icon(
                                Icons.Default.Add,
                                contentDescription = null,
                                modifier = Modifier.size(28.dp)
                            )
                        },
                        text = {
                            Text("New toDō", style = ToDoTextStyles.button)
                        },
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary
                    )
                }
            }
        ) { padding ->
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            ) {
                if (expandedNavigation) {
                    ExpandedNavigationRail(
                        destination = destination,
                        onDestinationSelected = { destination = it }
                    )
                }

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                ) {
                    // A maximum content width preserves readable line lengths on
                    // tablets while leaving room for a future master/detail pane.
                    val contentModifier = Modifier
                        .fillMaxHeight()
                        .widthIn(max = 960.dp)
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)

                    AnimatedContent(
                        targetState = destination,
                        modifier = contentModifier,
                        transitionSpec = {
                            val movingForward = targetState.ordinal > initialState.ordinal
                            val enter = slideInHorizontally(
                                animationSpec = tween(durationMillis = 240)
                            ) { width -> if (movingForward) width / 10 else -width / 10 } +
                                fadeIn(animationSpec = tween(durationMillis = 180))
                            val exit = slideOutHorizontally(
                                animationSpec = tween(durationMillis = 220)
                            ) { width -> if (movingForward) -width / 10 else width / 10 } +
                                fadeOut(animationSpec = tween(durationMillis = 160))
                            (enter togetherWith exit).using(
                                SizeTransform(
                                    clip = false,
                                    sizeAnimationSpec = { _, _ -> snap() }
                                )
                            )
                        },
                        label = "toDō destination transition"
                    ) { screen ->
                        when (screen) {
                            Destination.HOME -> HomeScreen(
                                toDos = toDos,
                                account = account,
                                onCreate = beginCreate,
                                onSeeAll = { destination = Destination.ALL },
                                onOpenProfile = { destination = Destination.PROFILE },
                                onShowSettings = { destination = Destination.SETTINGS },
                                onShowStats = { destination = Destination.STATS },
                                onToggleDone = store::toggleDone,
                                onOpenToDo = { selectedToDoId = it.toString() },
                                modifier = Modifier.fillMaxSize()
                            )
                            Destination.ALL -> AllToDosScreen(
                                toDos = toDos,
                                onToggleDone = store::toggleDone,
                                onMoveToTrash = store::moveToTrash,
                                onOpenToDo = { selectedToDoId = it.toString() },
                                onBack = { destination = Destination.HOME },
                                modifier = Modifier.fillMaxSize()
                            )
                            Destination.STATS -> StatsScreen(
                                toDos = toDos,
                                modifier = Modifier.fillMaxSize(),
                                onBack = { destination = Destination.HOME }
                            )
                            Destination.PROFILE -> ProfileScreen(
                                authSessionProvider = authSessionProvider,
                                modifier = Modifier.fillMaxSize(),
                                onBack = { destination = Destination.HOME }
                            )
                            Destination.SETTINGS -> SettingsScreen(
                                authSessionProvider = authSessionProvider,
                                settingsStore = settingsStore,
                                guidedTourStore = guidedTourStore,
                                toDos = toDos,
                                onUpdateToDo = store::update,
                                onRequestSync = {
                                    SyncWorkScheduler.requestImmediate(store.getApplication<Application>())
                                },
                                onStartGuidedTour = {
                                    destination = Destination.HOME
                                },
                                onBackToHome = { destination = Destination.HOME },
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }
            }
        }

        selectedToDo?.let { toDo ->
            ToDoDetailDialog(
                toDo = toDo,
                useBottomSheet = !expandedNavigation,
                onDismiss = { selectedToDoId = null },
                onUpdate = store::update,
                onMoveToTrash = {
                    store.moveToTrash(toDo.id)
                    selectedToDoId = null
                }
            )
        }

        if (guidedTourActive) {
            GuidedTourOverlay(
                step = guidedTourStep,
                modifier = Modifier.align(Alignment.BottomCenter),
                onPrimaryAction = {
                    when (guidedTourStep) {
                        GuidedTourStep.HIGHLIGHT_SETTINGS -> {
                            guidedTourStore.advanceTo(GuidedTourStep.SIGN_IN_AND_SYNC)
                            destination = Destination.SETTINGS
                        }
                        GuidedTourStep.SIGN_IN_AND_SYNC,
                        GuidedTourStep.NOTIFICATION_PERMISSION,
                        GuidedTourStep.ARCHIVE_VS_DELETE -> {
                            guidedTourStore.advance()
                            destination = Destination.SETTINGS
                        }
                        else -> guidedTourStore.advance()
                    }
                },
                onSkip = guidedTourStore::complete
            )
        }
    }

    if (showCreateDialog) {
        CreateToDoDialog(
            onDismiss = { showCreateDialog = false },
            onCreate = { title, notes ->
                store.create(title, notes)
                if (guidedTourActive && guidedTourStep in setOf(
                        GuidedTourStep.OPEN_ADD_VIEW,
                        GuidedTourStep.ENTER_TODO_TEXT,
                        GuidedTourStep.SAVE_TODO
                    )
                ) {
                    guidedTourStore.advanceTo(GuidedTourStep.CREATION_SUCCESS)
                }
                showCreateDialog = false
            }
        )
    }

}

@Composable
private fun GuidedTourOverlay(
    step: GuidedTourStep,
    onPrimaryAction: () -> Unit,
    onSkip: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .padding(horizontal = ToDoSpacing.screen, vertical = 18.dp)
            .widthIn(max = 560.dp),
        shape = ToDoShapes.hero,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Column(
            modifier = Modifier.padding(ToDoSpacing.card),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Guided Tour", style = ToDoTextStyles.sectionLabel, color = BrandPrimary)
            Text(step.title, style = ToDoTextStyles.detailTitle)
            Text(
                step.message,
                style = ToDoTextStyles.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "${step.ordinal + 1} of ${GuidedTourStep.entries.size - 1}",
                    style = ToDoTextStyles.rowMetadata,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f)
                )
                TextButton(onClick = onSkip) { Text("Skip") }
                Button(onClick = onPrimaryAction) { Text(step.primaryAction) }
            }
        }
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun AndroidDestinationHeader(
    title: String,
    onBack: () -> Unit,
    backContentDescription: String = "Back",
    modifier: Modifier = Modifier
) {
    CenterAlignedTopAppBar(
        modifier = modifier,
        windowInsets = WindowInsets(0, 0, 0, 0),
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = Color.Transparent,
            scrolledContainerColor = Color.Transparent
        ),
        navigationIcon = {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = backContentDescription
                )
            }
        },
        title = { Text(title, style = ToDoTextStyles.viewTitle) }
    )
}

@Composable
private fun ExpandedNavigationRail(
    destination: Destination,
    onDestinationSelected: (Destination) -> Unit
) {
    NavigationRail(modifier = Modifier.fillMaxHeight()) {
        Destination.values()
            .filter { it != Destination.PROFILE }
            .forEach { item ->
            NavigationRailItem(
                selected = destination == item,
                onClick = { onDestinationSelected(item) },
                icon = { DestinationIcon(item) },
                label = { Text(item.label) },
                alwaysShowLabel = true
            )
        }
    }
}

@Composable
private fun DestinationIcon(destination: Destination) {
    Icon(
        imageVector = when (destination) {
            Destination.HOME -> Icons.Default.Home
            Destination.ALL -> Icons.AutoMirrored.Filled.List
            Destination.STATS -> Icons.Default.Check
            Destination.PROFILE -> Icons.Default.Person
            Destination.SETTINGS -> Icons.Default.Settings
        },
        contentDescription = destination.label
    )
}

@Composable
private fun HomeScreen(
    toDos: List<ToDo>,
    account: AuthenticatedAccount?,
    onCreate: () -> Unit,
    onSeeAll: () -> Unit,
    onOpenProfile: () -> Unit,
    onShowSettings: () -> Unit,
    onShowStats: () -> Unit,
    onToggleDone: (java.util.UUID) -> Unit,
    onOpenToDo: (java.util.UUID) -> Unit,
    modifier: Modifier = Modifier
) {
    val active = toDos.filter { it.lifecycleState == ToDoState.ACTIVE }
    val completed = toDos.count { it.lifecycleState == ToDoState.DONE }
    val dueSoon = ToDo.dueSoon(active)
    val overdue = active.count { it.isLate() }
    val timeSensitive = ToDo.timeSensitive(active)
    var selectedFilter by rememberSaveable { mutableStateOf(HomeFilter.RECENT) }
    val filterScrollState = rememberScrollState()
    val filteredToDos = when (selectedFilter) {
        HomeFilter.DUE_SOON -> dueSoon
        HomeFilter.TIME_SENSITIVE -> timeSensitive
        HomeFilter.RECENT -> active
            .sortedWith(compareByDescending<ToDo> { it.createdAt }.thenBy { it.id.toString() })
    }.take(5)

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = ToDoSpacing.screen,
            top = 8.dp,
            end = ToDoSpacing.screen,
            bottom = ToDoSpacing.screen
        ),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier.height(60.dp),
                        contentAlignment = Alignment.CenterStart
                    ) {
                        Text(
                            homeDateLabel(),
                            style = ToDoTextStyles.dateContext,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Row(
                        modifier = Modifier.graphicsLayer {
                            scaleX = 1.15f
                            scaleY = 1.15f
                        },
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        ToDoWordmark(
                            textStyle = MaterialTheme.typography.headlineLarge.copy(
                                fontSize = 58.sp,
                                lineHeight = 62.sp
                            )
                        )
                        Box(
                            modifier = Modifier
                                .size(width = 44.dp, height = 60.dp)
                                .clickable(onClick = onCreate)
                                .semantics {
                                    contentDescription = "Create a new toDō"
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            ToDoBrandPlusGlyph(
                                fontSize = 58.sp,
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }
                Column(
                    horizontalAlignment = Alignment.End,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    ProfileAvatarButton(account = account, onClick = onOpenProfile)
                    SettingsButton(onClick = onShowSettings)
                }
            }
        }
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = ToDoShapes.hero,
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier.padding(ToDoSpacing.card),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Text("What matters now?", style = ToDoTextStyles.homeQuestion)
                    HomeActionButtons(onCreate = onCreate, onSeeAll = onSeeAll)
                }
            }
        }
        item {
            Text(
                "UP NEXT",
                style = ToDoTextStyles.sectionLabel
            )
            Row(
                modifier = Modifier.horizontalScroll(filterScrollState),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf(HomeFilter.RECENT, HomeFilter.DUE_SOON, HomeFilter.TIME_SENSITIVE).forEach { filter ->
                    FilterChip(
                        selected = selectedFilter == filter,
                        onClick = { selectedFilter = filter },
                        label = {
                            Text(
                                homeFilterLabel(filter),
                                maxLines = 1,
                                style = MaterialTheme.typography.labelLarge.copy(
                                    fontFamily = ToDoTypography.ui,
                                    fontSize = 15.sp,
                                    lineHeight = 18.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            )
                        },
                        colors = FilterChipDefaults.filterChipColors(
                            containerColor = if (isSystemInDarkTheme()) {
                                AppSurfaceMutedDark
                            } else {
                                AppSurfaceMutedLight
                            },
                            labelColor = MaterialTheme.colorScheme.onSurface,
                            selectedContainerColor = BrandPrimary,
                            selectedLabelColor = Color.White
                        ),
                        border = null,
                        shape = CircleShape
                    )
                }
            }
        }
        if (filteredToDos.isEmpty()) {
            item {
                Text(
                    homeFilterEmptyMessage(selectedFilter),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            items(filteredToDos, key = { it.id }) { toDo ->
                ToDoRow(
                    toDo = toDo,
                    onToggleDone = onToggleDone,
                    onOpenToDo = { onOpenToDo(toDo.id) }
                )
            }
        }
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "MOMENTUM",
                    style = ToDoTextStyles.sectionLabel
                )
                Spacer(Modifier.weight(1f))
                Button(
                    onClick = onShowStats,
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(50),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BrandTertiary,
                        contentColor = Color.White
                    ),
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 0.dp),
                    modifier = Modifier.height(44.dp)
                ) {
                    Text(
                        "Stats",
                        style = ToDoTextStyles.button.copy(
                            fontSize = 15.sp,
                            lineHeight = 17.sp
                        )
                    )
                    Spacer(Modifier.size(7.dp))
                    Icon(
                        imageVector = Icons.Default.Assessment,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MomentumStatCard(
                    label = "Active",
                    value = active.size.toString(),
                    glyph = MomentumGlyph.ACTIVE,
                    iconTint = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.weight(1f)
                )
                MomentumStatCard(
                    label = "Due soon",
                    value = dueSoon.size.toString(),
                    glyph = MomentumGlyph.DUE_SOON,
                    iconTint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MomentumStatCard(
                    label = "Overdue",
                    value = overdue.toString(),
                    glyph = MomentumGlyph.OVERDUE,
                    iconTint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.weight(1f)
                )
                MomentumStatCard(
                    label = "Time-sensitive",
                    value = timeSensitive.size.toString(),
                    glyph = MomentumGlyph.TIME_SENSITIVE,
                    iconTint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        item {
            MomentumStatCard(
                label = "Completed",
                value = completed.toString(),
                glyph = MomentumGlyph.COMPLETED,
                iconTint = MaterialTheme.colorScheme.tertiary,
                modifier = Modifier.fillMaxWidth(),
                valueAtEnd = true
            )
        }
    }
}

@Composable
private fun HomeActionButtons(
    onCreate: () -> Unit,
    onSeeAll: () -> Unit
) {
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val stacked = maxWidth < 360.dp
        if (stacked) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                NewToDoActionButton(
                    onClick = onCreate,
                    modifier = Modifier.fillMaxWidth()
                )
                SeeAllToDosActionButton(
                    onClick = onSeeAll,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                NewToDoActionButton(
                    onClick = onCreate,
                    modifier = Modifier.weight(1f)
                )
                SeeAllToDosActionButton(
                    onClick = onSeeAll,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun NewToDoActionButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        shape = ToDoShapes.control,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary
        ),
        modifier = modifier.height(56.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Add,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier.size(32.dp)
        )
        Spacer(Modifier.size(8.dp))
        Text("New toDō", style = ToDoTextStyles.button)
    }
}

@Composable
private fun SeeAllToDosActionButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        shape = ToDoShapes.control,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.secondary,
            contentColor = MaterialTheme.colorScheme.onSecondary
        ),
        modifier = modifier.height(56.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Spacer(Modifier.size(24.dp))
            Text(
                "See all toDōs",
                modifier = Modifier.weight(1f),
                textAlign = TextAlign.Center,
                style = ToDoTextStyles.button
            )
            Icon(
                Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
private fun StatsScreen(
    toDos: List<ToDo>,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val active = toDos.filter { it.lifecycleState == ToDoState.ACTIVE }
    val completed = toDos.count { it.lifecycleState == ToDoState.DONE }
    val dueSoon = ToDo.dueSoon(active)
    val overdue = active.count { it.isLate() }
    val timeSensitive = ToDo.timeSensitive(active)
    val today = LocalDate.now()
    val dueToday = active.count { todo ->
        todo.dueAt?.atZone(java.time.ZoneId.systemDefault())?.toLocalDate() == today
    }
    val scheduled = active.count { it.dueAt != null }
    val recurring = active.count { it.isRecurring }
    val nanoTotal = toDos.sumOf { it.nanoDos.size }
    val nanoCompleted = toDos.sumOf { todo -> todo.nanoDos.count { it.isDone } }

    Column(modifier = modifier.fillMaxSize()) {
        AndroidDestinationHeader(title = "Stats", onBack = onBack)
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            contentPadding = PaddingValues(ToDoSpacing.screen),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
        item {
            StatsHeroSummary(active = active.size, completed = completed, overdue = overdue)
        }
        item {
            StatsFocusGrid(
                dueToday = dueToday,
                timeSensitive = timeSensitive.size,
                scheduled = scheduled,
                recurring = recurring
            )
        }
        item {
            Text("Momentum", style = ToDoTextStyles.sectionLabel, color = BrandTertiary)
            Text(
                "A quick view of the work currently moving through toDō.",
                style = ToDoTextStyles.rowMetadata,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MomentumStatCard(
                    label = "Active",
                    value = active.size.toString(),
                    glyph = MomentumGlyph.ACTIVE,
                    iconTint = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.weight(1f)
                )
                MomentumStatCard(
                    label = "Due soon",
                    value = dueSoon.size.toString(),
                    glyph = MomentumGlyph.DUE_SOON,
                    iconTint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MomentumStatCard(
                    label = "Overdue",
                    value = overdue.toString(),
                    glyph = MomentumGlyph.OVERDUE,
                    iconTint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.weight(1f)
                )
                MomentumStatCard(
                    label = "Time-sensitive",
                    value = timeSensitive.size.toString(),
                    glyph = MomentumGlyph.TIME_SENSITIVE,
                    iconTint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        item {
            MomentumStatCard(
                label = "Completed",
                value = completed.toString(),
                glyph = MomentumGlyph.COMPLETED,
                iconTint = MaterialTheme.colorScheme.tertiary,
                modifier = Modifier.fillMaxWidth(),
                valueAtEnd = true
            )
        }
        item {
            StatsBreakdownCard(
                active = active.size,
                completed = completed,
                scheduled = scheduled,
                recurring = recurring,
                nanoCompleted = nanoCompleted,
                nanoTotal = nanoTotal
            )
        }
        }
    }
}

@Composable
private fun StatsHeroSummary(active: Int, completed: Int, overdue: Int) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = ToDoShapes.hero,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier.padding(ToDoSpacing.card),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(BrandSecondary),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Assessment, contentDescription = null, tint = Color.White)
                }
                Spacer(Modifier.size(12.dp))
                Text("Measure what matters", style = ToDoTextStyles.sectionLabel)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatsHeroMetric("Active", active.toString(), BrandSecondary, Modifier.weight(1f))
                StatsHeroMetric("Done", completed.toString(), BrandTertiary, Modifier.weight(1f))
                StatsHeroMetric("Overdue", overdue.toString(), MaterialTheme.colorScheme.error, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun StatsHeroMetric(label: String, value: String, tint: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(ToDoShapes.small)
            .background(tint.copy(alpha = 0.10f))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(value, style = ToDoTextStyles.statNumber, color = tint)
        Text(label, style = ToDoTextStyles.statLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun StatsFocusGrid(
    dueToday: Int,
    timeSensitive: Int,
    scheduled: Int,
    recurring: Int
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatsMetricTile("Due today", dueToday.toString(), Icons.Default.DateRange, BrandTertiary, Modifier.weight(1f))
            StatsMetricTile("Time-sensitive", timeSensitive.toString(), Icons.Default.Bolt, MaterialTheme.colorScheme.error, Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatsMetricTile("Scheduled", scheduled.toString(), Icons.Default.AccessTime, BrandSecondary, Modifier.weight(1f))
            StatsMetricTile("Recurring", recurring.toString(), Icons.Default.Repeat, BrandPrimary, Modifier.weight(1f))
        }
    }
}

@Composable
private fun StatsMetricTile(
    title: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(tint.copy(alpha = 0.14f)),
                    contentAlignment = Alignment.Center
                ) { Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(17.dp)) }
                Text(title, style = ToDoTextStyles.statLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(value, style = ToDoTextStyles.statNumber)
        }
    }
}

@Composable
private fun StatsBreakdownCard(
    active: Int,
    completed: Int,
    scheduled: Int,
    recurring: Int,
    nanoCompleted: Int,
    nanoTotal: Int
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier.padding(ToDoSpacing.card),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Workload shape", style = ToDoTextStyles.sectionLabel, color = BrandSecondary)
            StatsValueRow("Open toDōs", active.toString(), Icons.AutoMirrored.Filled.List, BrandSecondary)
            StatsValueRow("Completed toDōs", completed.toString(), Icons.Default.CheckCircle, BrandTertiary)
            StatsValueRow("Scheduled", scheduled.toString(), Icons.Default.AccessTime, BrandSecondary)
            StatsValueRow("Recurring", recurring.toString(), Icons.Default.Repeat, BrandPrimary)
            StatsValueRow("NanoDo completion", "$nanoCompleted/$nanoTotal", Icons.Default.Check, BrandTertiary)
        }
    }
}

@Composable
private fun StatsValueRow(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            modifier = Modifier
                .size(30.dp)
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) { Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(15.dp)) }
        Text(label, style = ToDoTextStyles.body, modifier = Modifier.weight(1f))
        Text(value, style = ToDoTextStyles.statLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private enum class MomentumGlyph {
    ACTIVE,
    DUE_SOON,
    OVERDUE,
    TIME_SENSITIVE,
    COMPLETED,
    STATS
}

@Composable
private fun MomentumStatCard(
    label: String,
    value: String,
    glyph: MomentumGlyph,
    iconTint: Color,
    modifier: Modifier = Modifier,
    valueAtEnd: Boolean = false
) {
    Card(
        modifier = modifier.semantics {
            contentDescription = "$label: $value"
        },
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp)
        ) {
            if (valueAtEnd) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    MomentumGlyphBadge(glyph = glyph, tint = iconTint)
                    Spacer(Modifier.size(12.dp))
                    Text(
                        label,
                        style = ToDoTextStyles.statLabel,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(Modifier.weight(1f))
                    MomentumValue(value)
                }
            } else {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(9.dp)
                ) {
                    MomentumGlyphBadge(glyph = glyph, tint = iconTint)
                    MomentumValue(value)
                }
                Text(
                    label,
                    style = ToDoTextStyles.statLabel,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun MomentumValue(value: String) {
    Text(
        value,
        style = ToDoTextStyles.statNumber
    )
}

@Composable
private fun MomentumGlyphBadge(glyph: MomentumGlyph, tint: Color) {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(CircleShape)
            .background(
                if (glyph == MomentumGlyph.TIME_SENSITIVE) {
                    mutedSurface()
                } else {
                    tint.copy(alpha = 0.14f)
                }
            ),
        contentAlignment = Alignment.Center
    ) {
        MomentumGlyphIcon(
            glyph = glyph,
            tint = tint,
            modifier = Modifier.size(13.dp)
        )
    }
}

@Composable
private fun MomentumGlyphIcon(
    glyph: MomentumGlyph,
    tint: Color,
    modifier: Modifier = Modifier
) {
    Icon(
        imageVector = when (glyph) {
            MomentumGlyph.ACTIVE -> Icons.Default.Bolt
            MomentumGlyph.DUE_SOON -> Icons.Default.AccessTime
            MomentumGlyph.OVERDUE -> Icons.Default.Warning
            MomentumGlyph.TIME_SENSITIVE -> Icons.Default.Notifications
            MomentumGlyph.COMPLETED -> Icons.Default.CheckCircle
            MomentumGlyph.STATS -> Icons.Default.Assessment
        },
        contentDescription = null,
        tint = tint,
        modifier = modifier
    )
}

private fun homeDateLabel(): String =
    DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.getDefault())
        .format(LocalDate.now())
        .uppercase(Locale.getDefault())

@Composable
private fun ToDoWordmark(
    textStyle: androidx.compose.ui.text.TextStyle = MaterialTheme.typography.headlineMedium
) {
    Row(
        modifier = Modifier.semantics(mergeDescendants = true) {
            contentDescription = "toDō"
        },
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            "toD",
            style = textStyle.copy(
                fontFamily = ToDoTypography.brand,
                fontWeight = FontWeight.Normal
            )
        )
        Text(
            "ō",
            color = BrandPrimary,
            style = textStyle.copy(
                fontFamily = ToDoTypography.brand,
                fontWeight = FontWeight.Normal
            )
        )
//        Image(
//            painter = painterResource(R.drawable.todo_logo_mark),
//            contentDescription = null,
//            contentScale = ContentScale.Fit,
//            modifier = Modifier.size(28.dp)
//        )
    }
}

@Composable
private fun ToDoHeaderWordmark() {
    Row(
        modifier = Modifier.semantics(mergeDescendants = true) {
            contentDescription = "toDō"
        },
        verticalAlignment = Alignment.CenterVertically
    ) {
        val style = MaterialTheme.typography.headlineLarge.copy(
            fontFamily = ToDoTypography.brand,
            fontWeight = FontWeight.Normal,
            fontSize = 64.sp,
            lineHeight = 68.sp
        )
        Text("toD", style = style)
        Text("ō", color = BrandPrimary, style = style)
    }
}

@Composable
private fun ProfileAvatarButton(
    account: AuthenticatedAccount?,
    onClick: () -> Unit
) {
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(60.dp)
            .semantics {
                contentDescription = "Open Profile"
            }
    ) {
        ProfileAvatar(account = account, size = 52.dp)
    }
}

@Composable
private fun SettingsButton(onClick: () -> Unit) {
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(60.dp)
            .semantics {
                contentDescription = "Open Settings"
            }
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(androidx.compose.foundation.shape.CircleShape)
                .background(BrandPrimary),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Settings,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(27.dp)
            )
        }
    }
}

@Composable
private fun AndroidButtonPlusGlyph(
    tint: Color,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        val stroke = (size.minDimension * 0.17f).coerceAtLeast(3.dp.toPx())
        drawLine(
            color = tint,
            start = Offset(size.width / 2f, size.height * 0.15f),
            end = Offset(size.width / 2f, size.height * 0.85f),
            strokeWidth = stroke,
            cap = StrokeCap.Round
        )
        drawLine(
            color = tint,
            start = Offset(size.width * 0.15f, size.height / 2f),
            end = Offset(size.width * 0.85f, size.height / 2f),
            strokeWidth = stroke,
            cap = StrokeCap.Round
        )
    }
}

@Composable
private fun ToDoBrandPlusGlyph(
    fontSize: androidx.compose.ui.unit.TextUnit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier.graphicsLayer {
            compositingStrategy = CompositingStrategy.Offscreen
        },
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "+",
            modifier = Modifier.fillMaxSize(),
            textAlign = TextAlign.Center,
            color = Color.White,
            style = MaterialTheme.typography.titleLarge.copy(
                fontFamily = ToDoTypography.brand,
                fontWeight = FontWeight.Normal,
                fontSize = fontSize,
                lineHeight = fontSize
            )
        )
        Image(
            painter = painterResource(R.drawable.brand_plus_reference),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    blendMode = BlendMode.SrcIn
                }
        )
    }
}

private fun homeFilterLabel(filter: HomeFilter): String = when (filter) {
    HomeFilter.DUE_SOON -> "Due soon"
    HomeFilter.TIME_SENSITIVE -> "Time-sensitive"
    HomeFilter.RECENT -> "Recent"
}

private fun homeFilterEmptyMessage(filter: HomeFilter): String = when (filter) {
    HomeFilter.DUE_SOON -> "Nothing is due soon."
    HomeFilter.TIME_SENSITIVE -> "Nothing is time-sensitive."
    HomeFilter.RECENT -> "Create a toDō to get started."
}

@Composable
private fun mutedSurface(): Color =
    if (isSystemInDarkTheme()) AppSurfaceMutedDark else AppSurfaceMutedLight

@Composable
private fun AllToDosScreen(
    toDos: List<ToDo>,
    onToggleDone: (java.util.UUID) -> Unit,
    onMoveToTrash: (java.util.UUID) -> Unit,
    onOpenToDo: (java.util.UUID) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val visibleToDos = toDos.filter { it.lifecycleState != ToDoState.TRASHED }

    Column(modifier = modifier.fillMaxSize()) {
        AndroidDestinationHeader(title = "toDō", onBack = onBack, backContentDescription = "Back to Home")
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            contentPadding = PaddingValues(ToDoSpacing.screen),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (visibleToDos.isEmpty()) {
                item {
                    EmptyState(
                        onCreate = {},
                        showCreateButton = false,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
            items(visibleToDos, key = { it.id }) { toDo ->
                ToDoRow(
                    toDo = toDo,
                    onToggleDone = onToggleDone,
                    onMoveToTrash = onMoveToTrash,
                    onOpenToDo = { onOpenToDo(toDo.id) }
                )
            }
        }
    }
}

@Composable
private fun EmptyState(
    onCreate: () -> Unit,
    showCreateButton: Boolean = true,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .heightIn(min = 240.dp)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Nothing here yet", style = ToDoTextStyles.homeQuestion)
            Text(
                "Create a toDō and give your attention somewhere useful to go.",
                style = ToDoTextStyles.rowMetadata,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (showCreateButton) {
                androidx.compose.material3.FilledTonalButton(
                    onClick = onCreate,
                    shape = ToDoShapes.control
                ) {
                    Icon(Icons.Default.Add, contentDescription = null)
                    Spacer(Modifier.size(8.dp))
                    Text("Create toDō")
                }
            }
        }
    }
}

@Composable
private fun SummaryCard(label: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(value, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ToDoRow(
    toDo: ToDo,
    onToggleDone: (java.util.UUID) -> Unit,
    onMoveToTrash: ((java.util.UUID) -> Unit)? = null,
    onOpenToDo: (() -> Unit)? = null
) {
    Card(
        modifier = if (onOpenToDo == null) {
            Modifier
        } else {
            Modifier.clickable(onClick = onOpenToDo)
        },
        shape = ToDoShapes.card,
        border = if (toDo.reminderIntent == dev.iamshift.todo.android.core.model.ToDoReminderIntent.TIME_SENSITIVE && !toDo.isDone) {
            androidx.compose.foundation.BorderStroke(1.5.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.55f))
        } else {
            null
        },
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { onToggleDone(toDo.id) }) {
                CompletionGlyph(
                    isDone = toDo.isDone,
                    tint = if (toDo.isDone) {
                        MaterialTheme.colorScheme.tertiary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    modifier = Modifier.size(24.dp)
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = toDo.task,
                    style = ToDoTextStyles.rowTitle,
                    color = if (toDo.isDone) {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    } else {
                        MaterialTheme.colorScheme.onSurface
                    },
                    textDecoration = if (toDo.isDone) TextDecoration.LineThrough else TextDecoration.None
                )
                ToDoMetadataRow(toDo)
                if (toDo.notes.isNotEmpty()) {
                    Text(
                        toDo.notes,
                        style = ToDoTextStyles.rowMetadata.copy(
                            fontFamily = ToDoTypography.longForm
                        ),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            if (onMoveToTrash != null) {
                IconButton(onClick = { onMoveToTrash(toDo.id) }) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "Move to Trash",
                        tint = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
    }
}

@Composable
private fun ToDoMetadataRow(toDo: ToDo) {
    val isLate = toDo.isLate()
    val metadata = buildList {
        toDo.dueAt?.let { dueAt ->
            add(
                MetadataChipData(
                    label = shortDueLabel(dueAt),
                    icon = Icons.Default.DateRange,
                    background = if (isLate) {
                        MaterialTheme.colorScheme.error.copy(alpha = 0.12f)
                    } else {
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.14f)
                    },
                    foreground = if (isLate) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
                )
            )
        }
        if (toDo.nanoDos.isNotEmpty()) {
            val doneCount = toDo.nanoDos.count { it.isDone }
            add(
                MetadataChipData(
                    label = if (doneCount > 0) "$doneCount/${toDo.nanoDos.size}" else toDo.nanoDos.size.toString(),
                    icon = Icons.Default.CheckCircle,
                    background = if (doneCount == toDo.nanoDos.size) {
                        MaterialTheme.colorScheme.tertiary.copy(alpha = 0.20f)
                    } else {
                        mutedSurface()
                    },
                    foreground = MaterialTheme.colorScheme.onSurface
                )
            )
        }
        if (toDo.reminderIntent == dev.iamshift.todo.android.core.model.ToDoReminderIntent.TIME_SENSITIVE) {
            add(
                MetadataChipData(
                    label = "Time-sensitive",
                    icon = Icons.Default.Notifications,
                    background = MaterialTheme.colorScheme.error.copy(alpha = 0.12f),
                    foreground = MaterialTheme.colorScheme.error
                )
            )
        }
        if (toDo.recurrence != null) {
            add(
                MetadataChipData(
                    label = "Repeats",
                    icon = Icons.Default.Repeat,
                    background = MaterialTheme.colorScheme.secondary.copy(alpha = 0.14f),
                    foreground = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    }

    if (metadata.isNotEmpty()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            metadata.forEach { chip ->
                Row(
                    modifier = Modifier
                        .clip(ToDoShapes.small)
                        .background(chip.background)
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(chip.icon, contentDescription = null, tint = chip.foreground, modifier = Modifier.size(12.dp))
                    Text(
                        chip.label,
                        style = ToDoTextStyles.rowMetadata.copy(fontSize = 11.sp, lineHeight = 14.sp),
                        color = chip.foreground,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

private data class MetadataChipData(
    val label: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val background: Color,
    val foreground: Color
)

private fun shortDueLabel(instant: java.time.Instant): String =
    DateTimeFormatter.ofPattern("MMM d · h:mm a", Locale.getDefault())
        .format(instant.atZone(java.time.ZoneId.systemDefault()))

@Composable
private fun CompletionGlyph(
    isDone: Boolean,
    tint: Color,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        val stroke = (size.minDimension * 0.12f).coerceAtLeast(2.dp.toPx())
        val center = Offset(size.width / 2f, size.height / 2f)
        if (isDone) {
            drawLine(
                color = tint,
                start = Offset(size.width * 0.16f, size.height * 0.52f),
                end = Offset(size.width * 0.42f, size.height * 0.76f),
                strokeWidth = stroke,
                cap = StrokeCap.Round
            )
            drawLine(
                color = tint,
                start = Offset(size.width * 0.42f, size.height * 0.76f),
                end = Offset(size.width * 0.84f, size.height * 0.24f),
                strokeWidth = stroke,
                cap = StrokeCap.Round
            )
        } else {
            drawCircle(
                color = tint,
                radius = size.minDimension * 0.34f,
                center = center,
                style = Stroke(width = stroke)
            )
        }
    }
}

@Composable
private fun CreateToDoDialog(
    onDismiss: () -> Unit,
    onCreate: (title: String, notes: String) -> Unit
) {
    var title by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create toDō") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                TextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Title") },
                    textStyle = ToDoTextStyles.rowTitle,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = ToDoShapes.small,
                    colors = ToDoTextFieldColors()
                )
                TextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes") },
                    textStyle = ToDoTextStyles.rowTitle,
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth(),
                    shape = ToDoShapes.small,
                    colors = ToDoTextFieldColors()
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onCreate(title, notes) }, enabled = title.isNotBlank()) {
                Text("Create")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}
