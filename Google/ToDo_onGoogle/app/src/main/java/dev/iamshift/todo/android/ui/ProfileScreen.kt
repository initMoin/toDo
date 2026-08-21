package dev.iamshift.todo.android.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.iamshift.todo.android.core.auth.AuthenticatedAccount
import dev.iamshift.todo.android.core.auth.SupabaseAuthSessionProvider
import dev.iamshift.todo.android.core.auth.SupabaseOAuthProvider
import dev.iamshift.todo.android.ui.theme.BrandPrimary
import dev.iamshift.todo.android.ui.theme.BrandSecondary
import dev.iamshift.todo.android.ui.theme.BrandTertiary
import dev.iamshift.todo.android.ui.theme.ToDoShapes
import dev.iamshift.todo.android.ui.theme.ToDoSpacing
import dev.iamshift.todo.android.ui.theme.ToDoTextStyles
import dev.iamshift.todo.android.ui.theme.ToDoTypography
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.max
import kotlin.math.roundToInt

@Composable
internal fun ProfileScreen(
    authSessionProvider: SupabaseAuthSessionProvider,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val account by authSessionProvider.account.collectAsState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var isConnecting by remember { mutableStateOf<SupabaseOAuthProvider?>(null) }
    var connectionError by remember { mutableStateOf<String?>(null) }
    var isSavingProfileImage by remember { mutableStateOf(false) }
    var profileImageError by remember { mutableStateOf<String?>(null) }

    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            coroutineScope.launch {
                isSavingProfileImage = true
                profileImageError = null
                val imageData = readProfileImage(context, uri)
                if (imageData == null) {
                    profileImageError = "The profile image could not be read. Try another image."
                } else {
                    runCatching {
                        authSessionProvider.updateProfileImage(imageData)
                    }.onFailure { error ->
                        profileImageError = error.message ?: "Your profile image could not be saved."
                    }.onSuccess { saved ->
                        if (!saved) {
                            profileImageError = "Your profile image could not be saved. Try again."
                        }
                    }
                }
                isSavingProfileImage = false
            }
        }
    }

    Column(modifier = modifier.fillMaxSize()) {
        AndroidDestinationHeader(title = "Profile", onBack = onBack)
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            contentPadding = PaddingValues(ToDoSpacing.screen),
            verticalArrangement = Arrangement.spacedBy(ToDoSpacing.section)
        ) {
        item {
            ProfileIdentityCard(
                account = account,
                isSavingImage = isSavingProfileImage,
                onChangeImage = {
                    profileImageError = null
                    photoPickerLauncher.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                    )
                }
            )
            profileImageError?.let { message ->
                Text(
                    text = message,
                    style = ToDoTextStyles.rowMetadata,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = ToDoSpacing.card)
                )
            }
        }
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = ToDoShapes.card,
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier.padding(ToDoSpacing.card),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("Connected accounts", style = ToDoTextStyles.sectionLabel)
                    Text(
                        "Use either connected sign-in method to return to this toDō account.",
                        style = ToDoTextStyles.rowMetadata,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    ProviderConnectionRow(
                        label = "Apple",
                        provider = SupabaseOAuthProvider.APPLE,
                        isConnected = account?.linkedProviders?.contains("apple") == true,
                        isConnecting = isConnecting == SupabaseOAuthProvider.APPLE,
                        onConnect = {
                            connectionError = null
                            coroutineScope.launch {
                                isConnecting = SupabaseOAuthProvider.APPLE
                                connectionError = runCatching {
                                    authSessionProvider.connectProvider(SupabaseOAuthProvider.APPLE)
                                }.exceptionOrNull()?.message
                                isConnecting = null
                            }
                        }
                    )
                    ProviderConnectionRow(
                        label = "Google",
                        provider = SupabaseOAuthProvider.GOOGLE,
                        isConnected = account?.linkedProviders?.contains("google") == true,
                        isConnecting = isConnecting == SupabaseOAuthProvider.GOOGLE,
                        onConnect = {
                            connectionError = null
                            coroutineScope.launch {
                                isConnecting = SupabaseOAuthProvider.GOOGLE
                                connectionError = runCatching {
                                    authSessionProvider.connectProvider(SupabaseOAuthProvider.GOOGLE)
                                }.exceptionOrNull()?.message
                                isConnecting = null
                            }
                        }
                    )
                    connectionError?.let { message ->
                        Text(message, style = ToDoTextStyles.rowMetadata, color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
        item {
            AccountInformationCard(account = account)
        }
        }
    }
}

@Composable
private fun ProfileIdentityCard(
    account: AuthenticatedAccount?,
    isSavingImage: Boolean,
    onChangeImage: () -> Unit
) {
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
                .padding(ToDoSpacing.card),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(modifier = Modifier.size(82.dp)) {
                ProfileAvatar(
                    account = account,
                    size = 82.dp,
                    modifier = Modifier.semantics {
                        contentDescription = "Profile image"
                    }
                )
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(BrandPrimary)
                        .clickable(enabled = !isSavingImage, onClick = onChangeImage),
                    contentAlignment = Alignment.Center
                ) {
                    if (isSavingImage) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(15.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.Edit,
                            contentDescription = "Change profile image",
                            tint = Color.White,
                            modifier = Modifier.size(15.dp)
                        )
                    }
                }
            }
            Spacer(Modifier.size(16.dp))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    account?.displayName
                        ?.takeIf { it.isNotBlank() }
                        ?: account?.username?.let { "@$it" }
                        ?: "Your toDō account",
                    style = ToDoTextStyles.detailTitle.copy(fontSize = 24.sp, lineHeight = 29.sp)
                )
                account?.username?.let {
                    Text("@$it", style = ToDoTextStyles.rowMetadata, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(
                    if (account?.isResolved == true) "toDō account" else "Account setup in progress",
                    style = ToDoTextStyles.rowMetadata,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun AccountInformationCard(account: AuthenticatedAccount?) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(ToDoSpacing.card),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Account", style = ToDoTextStyles.sectionLabel)
            ProfileInfoLine("Email", account?.email ?: "Not available")
            ProfileInfoLine("Username", account?.username?.let { "@$it" } ?: "Not set")
            ProfileInfoLine("Membership", "toDō")
        }
    }
}

@Composable
private fun ProfileInfoLine(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(label, style = ToDoTextStyles.statLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.weight(1f))
        Text(value, style = ToDoTextStyles.body, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun ProviderConnectionRow(
    label: String,
    provider: SupabaseOAuthProvider,
    isConnected: Boolean,
    isConnecting: Boolean,
    onConnect: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(CircleShape)
                .background(if (provider == SupabaseOAuthProvider.APPLE) Color.Black else BrandSecondary),
            contentAlignment = Alignment.Center
        ) {
            Text(
                if (provider == SupabaseOAuthProvider.APPLE) "A" else "G",
                color = Color.White,
                style = ToDoTypography.display.let {
                    MaterialTheme.typography.titleMedium.copy(fontFamily = it)
                }
            )
        }
        Text(label, style = ToDoTextStyles.body, modifier = Modifier.weight(1f))
        if (isConnected) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = "Connected",
                tint = BrandTertiary,
                modifier = Modifier.size(24.dp)
            )
        } else {
            FilledTonalButton(
                onClick = onConnect,
                enabled = !isConnecting,
                shape = ToDoShapes.control,
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 0.dp)
            ) {
                if (isConnecting) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                } else {
                    Text("Connect", style = ToDoTextStyles.button.copy(fontSize = 15.sp, lineHeight = 17.sp))
                }
            }
        }
    }
}

private suspend fun readProfileImage(context: Context, uri: Uri): ByteArray? =
    withContext(Dispatchers.IO) {
        runCatching {
            val source = ImageDecoder.createSource(context.contentResolver, uri)
            val bitmap = ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                val maximumDimension = max(info.size.width, info.size.height)
                if (maximumDimension > MAX_PROFILE_IMAGE_DIMENSION) {
                    val scale = MAX_PROFILE_IMAGE_DIMENSION.toFloat() / maximumDimension
                    decoder.setTargetSize(
                        (info.size.width * scale).roundToInt(),
                        (info.size.height * scale).roundToInt()
                    )
                }
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }

            var quality = 88
            var compressed: ByteArray
            do {
                compressed = ByteArrayOutputStream().use { output ->
                    check(bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output))
                    output.toByteArray()
                }
                quality -= 8
            } while (compressed.size > MAX_PROFILE_IMAGE_BYTES && quality >= 56)

            bitmap.recycle()
            compressed.takeIf { it.size <= MAX_PROFILE_IMAGE_BYTES }
        }.getOrNull()
    }

private const val MAX_PROFILE_IMAGE_DIMENSION = 2048
private const val MAX_PROFILE_IMAGE_BYTES = 5 * 1024 * 1024
