package com.example.advertising_screen

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    private val TAG = "RestaurantBootReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Boot event received: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_REBOOT -> {

                Log.d(TAG, "Starting restaurant app after boot...")

                // IMPORTANT: Add delay for system to fully initialize
                Handler(Looper.getMainLooper()).postDelayed({
                    launchApp(context)
                }, 25000) // 25-second delay for reliable boot

                // Backup launch at 35 seconds
                Handler(Looper.getMainLooper()).postDelayed({
                    launchApp(context)
                }, 35000)
            }
        }
    }

    private fun launchApp(context: Context) {
        try {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                putExtra("launched_from_boot", true)
            }

            context.startActivity(launchIntent)
            Log.d(TAG, "Restaurant app launched successfully!")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch app: ${e.message}")
        }
    }
}