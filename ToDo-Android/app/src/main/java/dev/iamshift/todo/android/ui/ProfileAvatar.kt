package dev.iamshift.todo.android.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import dev.iamshift.todo.android.core.auth.AuthenticatedAccount
import dev.iamshift.todo.android.ui.theme.ToDoTypography
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Shared avatar rendering keeps Home and Profile on the same account image path. */
@Composable
internal fun ProfileAvatar(
    account: AuthenticatedAccount?,
    size: Dp,
    modifier: Modifier = Modifier
) {
    val bitmap by produceState<androidx.compose.ui.graphics.ImageBitmap?>(
        initialValue = null,
        key1 = account?.avatarUrl
    ) {
        value = account?.avatarUrl
            ?.takeIf { it.startsWith("https://", ignoreCase = true) }
            ?.let { url ->
                withContext(Dispatchers.IO) {
                    runCatching {
                        URL(url).openStream().use { input ->
                            BitmapFactory.decodeStream(input)?.asImageBitmap()
                        }
                    }.getOrNull()
                }
            }
    }

    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.secondary),
        contentAlignment = Alignment.Center
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap!!,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        } else if (account?.username != null) {
            Text(
                account.username.first().uppercase(),
                color = MaterialTheme.colorScheme.onSecondary,
                style = MaterialTheme.typography.displaySmall.copy(fontFamily = ToDoTypography.display)
            )
        } else {
            Icon(
                Icons.Default.Person,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSecondary,
                modifier = Modifier.size(size * 0.44f)
            )
        }
    }
}
