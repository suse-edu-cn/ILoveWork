package com.suseoaa.ilovework.ui.updater

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.widget.Toast
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpdateHistoryScreen(onBack: () -> Unit) {
    val viewModel = remember { UpdaterViewModel() }
    val releases by viewModel.releases.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    
    val context = LocalContext.current
    val currentVersion = try {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0.0"
    } catch (e: Exception) {
        "1.0.0"
    }

    LaunchedEffect(Unit) {
        viewModel.fetchReleases()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("版本历史与更新") },
                navigationIcon = {
                    TextButton(onClick = onBack) {
                        Text("← 返回")
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                isLoading && releases.isEmpty() -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
                errorMessage != null -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(text = errorMessage ?: "Unknown Error", color = MaterialTheme.colorScheme.error)
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.fetchReleases() }) {
                            Text("重试")
                        }
                    }
                }
                releases.isNotEmpty() -> {
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        item {
                            val latest = releases.first()
                            val isNewer = isVersionNewer(latest.tagName, currentVersion)
                            if (isNewer) {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text("⭐", style = MaterialTheme.typography.titleMedium)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(
                                                "发现新版本: ${latest.tagName}",
                                                style = MaterialTheme.typography.titleMedium,
                                                color = MaterialTheme.colorScheme.primary
                                            )
                                        }
                                        Spacer(modifier = Modifier.height(8.dp))
                                        if (latest.downloadUrl != null) {
                                            Button(
                                                onClick = {
                                                    try {
                                                        val downloadManager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                                                        val request = DownloadManager.Request(Uri.parse(latest.downloadUrl))
                                                        val filename = "ILoveWork_${latest.tagName}.apk"
                                                        request.setTitle("我爱上班 更新下载")
                                                        request.setDescription("正在下载最新版本...")
                                                        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                                                        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
                                                        downloadManager.enqueue(request)
                                                        Toast.makeText(context, "已开始在后台下载，请拉下通知栏查看进度", Toast.LENGTH_LONG).show()
                                                    } catch (e: Exception) {
                                                        Toast.makeText(context, "下载失败: ${e.message}", Toast.LENGTH_SHORT).show()
                                                    }
                                                },
                                                modifier = Modifier.fillMaxWidth()
                                            ) {
                                                Text("应用内下载 Android 版")
                                            }
                                        } else {
                                            Text("暂未提供 APK 下载", style = MaterialTheme.typography.bodySmall)
                                        }
                                    }
                                }
                            } else {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFE8F5E9)),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        modifier = Modifier.padding(16.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text("✅", style = MaterialTheme.typography.titleMedium)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            "当前已是最新版本 ($currentVersion)",
                                            color = Color(0xFF2E7D32)
                                        )
                                    }
                                }
                            }
                        }

                        items(releases) { release ->
                            ReleaseItem(release)
                            Divider(modifier = Modifier.padding(top = 16.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ReleaseItem(release: GitHubRelease) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = release.name.ifEmpty { release.tagName },
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                text = formatDateString(release.publishedAt),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (release.body.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = release.body,
                style = MaterialTheme.typography.bodyMedium
            )
        }
        val context = LocalContext.current
        if (release.downloadUrl != null) {
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedButton(onClick = {
                try {
                    val downloadManager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                    val request = DownloadManager.Request(Uri.parse(release.downloadUrl))
                    val filename = "ILoveWork_${release.tagName}.apk"
                    request.setTitle("我爱上班 更新下载")
                    request.setDescription("正在下载版本 ${release.tagName}...")
                    request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                    request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
                    downloadManager.enqueue(request)
                    Toast.makeText(context, "已开始在后台下载，请拉下通知栏查看进度", Toast.LENGTH_LONG).show()
                } catch (e: Exception) {
                    Toast.makeText(context, "下载失败: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }) {
                Text("应用内下载此版本")
            }
        }
    }
}

fun isVersionNewer(latest: String, current: String): Boolean {
    val l = latest.replace("v", "")
    val c = current.replace("v", "")
    
    val lParts = l.split(".").mapNotNull { it.toIntOrNull() }
    val cParts = c.split(".").mapNotNull { it.toIntOrNull() }
    
    val length = maxOf(lParts.size, cParts.size)
    for (i in 0 until length) {
        val lP = lParts.getOrElse(i) { 0 }
        val cP = cParts.getOrElse(i) { 0 }
        if (lP > cP) return true
        if (lP < cP) return false
    }
    return false
}
