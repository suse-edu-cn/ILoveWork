package com.suseoaa.ilovework.domain

import com.russhwolf.settings.Settings
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.Properties

class FileSettings : Settings {
    private val groupDir = File(System.getProperty("user.home"), "Library/Group Containers/group.com.suseoaa.ilovework")
    private val file = File(groupDir, "config.properties")
    private val props = Properties()

    init {
        if (!groupDir.exists()) {
            groupDir.mkdirs()
        }
        if (file.exists()) {
            FileInputStream(file).use { props.load(it) }
        }
    }

    private fun save() {
        FileOutputStream(file).use { props.store(it, null) }
    }

    override val keys: Set<String> get() = props.keys.map { it.toString() }.toSet()
    override val size: Int get() = props.size

    override fun clear() { props.clear(); save() }
    override fun hasKey(key: String): Boolean = props.containsKey(key)
    override fun remove(key: String) { props.remove(key); save() }

    override fun getBoolean(key: String, defaultValue: Boolean): Boolean = props.getProperty(key)?.toBoolean() ?: defaultValue
    override fun getBooleanOrNull(key: String): Boolean? = props.getProperty(key)?.toBooleanStrictOrNull()
    override fun getDouble(key: String, defaultValue: Double): Double = props.getProperty(key)?.toDoubleOrNull() ?: defaultValue
    override fun getDoubleOrNull(key: String): Double? = props.getProperty(key)?.toDoubleOrNull()
    override fun getFloat(key: String, defaultValue: Float): Float = props.getProperty(key)?.toFloatOrNull() ?: defaultValue
    override fun getFloatOrNull(key: String): Float? = props.getProperty(key)?.toFloatOrNull()
    override fun getInt(key: String, defaultValue: Int): Int = props.getProperty(key)?.toIntOrNull() ?: defaultValue
    override fun getIntOrNull(key: String): Int? = props.getProperty(key)?.toIntOrNull()
    override fun getLong(key: String, defaultValue: Long): Long = props.getProperty(key)?.toLongOrNull() ?: defaultValue
    override fun getLongOrNull(key: String): Long? = props.getProperty(key)?.toLongOrNull()
    override fun getString(key: String, defaultValue: String): String = props.getProperty(key) ?: defaultValue
    override fun getStringOrNull(key: String): String? = props.getProperty(key)

    override fun putBoolean(key: String, value: Boolean) { props.setProperty(key, value.toString()); save() }
    override fun putDouble(key: String, value: Double) { props.setProperty(key, value.toString()); save() }
    override fun putFloat(key: String, value: Float) { props.setProperty(key, value.toString()); save() }
    override fun putInt(key: String, value: Int) { props.setProperty(key, value.toString()); save() }
    override fun putLong(key: String, value: Long) { props.setProperty(key, value.toString()); save() }
    override fun putString(key: String, value: String) { props.setProperty(key, value); save() }
}

actual fun createSettings(): Settings = FileSettings()
