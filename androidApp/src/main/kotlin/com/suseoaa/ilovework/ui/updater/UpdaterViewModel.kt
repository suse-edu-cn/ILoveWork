package com.suseoaa.ilovework.ui.updater

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

data class GitHubRelease(
    val id: Int,
    val tagName: String,
    val name: String,
    val body: String,
    val publishedAt: String,
    val downloadUrl: String?
)

class UpdaterViewModel : ViewModel() {
    private val _releases = MutableStateFlow<List<GitHubRelease>>(emptyList())
    val releases: StateFlow<List<GitHubRelease>> = _releases.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun fetchReleases() {
        if (_isLoading.value) return
        _isLoading.value = true
        _errorMessage.value = null

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val url = URL("https://api.github.com/repos/suse-edu-cn/ILoveWork/releases")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("Accept", "application/vnd.github.v3+json")
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                if (connection.responseCode == 200) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonArray = JSONArray(response)
                    val releaseList = mutableListOf<GitHubRelease>()

                    for (i in 0 until jsonArray.length()) {
                        val obj = jsonArray.getJSONObject(i)
                        val id = obj.getInt("id")
                        val tagName = obj.getString("tag_name")
                        val name = obj.optString("name", tagName)
                        val body = obj.optString("body", "")
                        val publishedAt = obj.optString("published_at", "")
                        
                        var downloadUrl: String? = null
                        if (obj.has("assets")) {
                            val assets = obj.getJSONArray("assets")
                            for (j in 0 until assets.length()) {
                                val asset = assets.getJSONObject(j)
                                val assetName = asset.getString("name")
                                if (assetName.endsWith(".apk", ignoreCase = true)) {
                                    downloadUrl = asset.getString("browser_download_url")
                                    break
                                }
                            }
                        }
                        
                        releaseList.add(
                            GitHubRelease(
                                id = id,
                                tagName = tagName,
                                name = name,
                                body = body,
                                publishedAt = publishedAt,
                                downloadUrl = downloadUrl
                            )
                        )
                    }
                    _releases.value = releaseList
                } else {
                    _errorMessage.value = "请求失败，状态码: ${connection.responseCode}"
                }
            } catch (e: Exception) {
                _errorMessage.value = "网络请求失败: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
}

fun formatDateString(isoString: String): String {
    if (isoString.isEmpty()) return ""
    return try {
        val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        parser.timeZone = TimeZone.getTimeZone("UTC")
        val date = parser.parse(isoString) ?: return isoString
        val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())
        formatter.format(date)
    } catch (e: Exception) {
        isoString
    }
}
