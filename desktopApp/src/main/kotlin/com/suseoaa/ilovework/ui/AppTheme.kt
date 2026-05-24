package com.suseoaa.ilovework.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    background = Color(0xFFFAF9F6),
    surface = Color(0xFFF5F3EE),
    onBackground = Color(0xFF1A1A1A),
    onSurface = Color(0xFF1A1A1A),
    primary = Color(0xFF5B7CFA),
    onPrimary = Color.White,
)

private val DarkColorScheme = darkColorScheme(
    background = Color(0xFF121212),
    surface = Color(0xFF1E1E1E),
    onBackground = Color(0xFFF0EDE8),
    onSurface = Color(0xFFF0EDE8),
    primary = Color(0xFF7B9CFF),
    onPrimary = Color(0xFF121212),
)

@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) DarkColorScheme else LightColorScheme
    MaterialTheme(colorScheme = colors, content = content)
}
