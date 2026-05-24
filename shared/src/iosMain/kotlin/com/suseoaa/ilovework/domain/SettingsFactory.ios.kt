package com.suseoaa.ilovework.domain

import com.russhwolf.settings.NSUserDefaultsSettings
import com.russhwolf.settings.Settings
import platform.Foundation.NSUserDefaults

actual fun createSettings(): Settings {
    val delegate = NSUserDefaults(suiteName = "group.com.suseoaa.ilovework")
    return NSUserDefaultsSettings(delegate)
}
