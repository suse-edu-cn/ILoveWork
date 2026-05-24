package com.suseoaa.ilovework.ui

import android.content.Context
import android.provider.CalendarContract
import java.text.SimpleDateFormat
import java.util.*

object CalendarHelper {
    fun syncHolidays(context: Context): Pair<Set<String>, Set<String>> {
        val holidays = mutableSetOf<String>()
        val makeupDays = mutableSetOf<String>()

        val projection = arrayOf(
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DTSTART
        )

        // Query events from the beginning of this year to the end of next year
        val now = Calendar.getInstance()
        val currentYear = now.get(Calendar.YEAR)
        val startCal = Calendar.getInstance().apply { set(currentYear, Calendar.JANUARY, 1, 0, 0, 0) }
        val endCal = Calendar.getInstance().apply { set(currentYear + 1, Calendar.DECEMBER, 31, 23, 59, 59) }

        val selection = "${CalendarContract.Events.DTSTART} >= ? AND ${CalendarContract.Events.DTSTART} <= ?"
        val selectionArgs = arrayOf(startCal.timeInMillis.toString(), endCal.timeInMillis.toString())

        try {
            val cursor = context.contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )

            cursor?.use {
                val titleIndex = it.getColumnIndex(CalendarContract.Events.TITLE)
                val dtStartIndex = it.getColumnIndex(CalendarContract.Events.DTSTART)
                val df = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

                while (it.moveToNext()) {
                    val title = it.getString(titleIndex) ?: ""
                    val dtStart = it.getLong(dtStartIndex)
                    
                    if (title.contains("休")) {
                        holidays.add(df.format(Date(dtStart)))
                    } else if (title.contains("班")) {
                        makeupDays.add(df.format(Date(dtStart)))
                    }
                }
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }

        return Pair(holidays, makeupDays)
    }
}
