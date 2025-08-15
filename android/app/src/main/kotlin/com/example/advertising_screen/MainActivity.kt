package com.example.advertising_screen

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.WindowManager
import android.view.View
import android.util.Log

class MainActivity: FlutterActivity() {

    private val TAG = "RestaurantMainActivity"
    private var menuKeyPressTime: Long = 0
    private var isMenuKeyHeld = false
    private val MENU_HOLD_DURATION = 3000L // 3 seconds
    private var menuHandler: Handler? = null
    private var menuRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d(TAG, "Restaurant app starting...")

        // Setup restaurant kiosk mode
        setupKioskMode()

        // Check if launched from boot
        if (intent.getBooleanExtra("launched_from_boot", false)) {
            Log.d(TAG, "App launched automatically after boot!")
        }

        Log.d(TAG, "Restaurant app ready for customers")
    }

    private fun setupKioskMode() {
        // Keep screen always on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Full-screen immersive mode
        window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )
    }

    override fun onResume() {
        super.onResume()
        setupKioskMode()
    }

    override fun onBackPressed() {
        // Disable back button for restaurant kiosk mode
        Log.d(TAG, "Back button disabled in restaurant mode")
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            setupKioskMode()
        }
    }

    // Handle physical remote button presses - Optimized for H96 MAX TV Box
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        Log.d(TAG, "Key pressed: $keyCode (H96 MAX remote)")

        when (keyCode) {
            // Method 1: Hold MENU button for 3 seconds (Most reliable for H96 MAX)
            KeyEvent.KEYCODE_MENU -> {
                if (!isMenuKeyHeld) {
                    isMenuKeyHeld = true
                    menuKeyPressTime = System.currentTimeMillis()

                    Log.d(TAG, "MENU key pressed - hold for 3 seconds to access launcher")

                    // Start timer for 3-second hold
                    menuHandler = Handler(Looper.getMainLooper())
                    menuRunnable = Runnable {
                        if (isMenuKeyHeld) {
                            Log.d(TAG, "MENU key held for 3 seconds - opening launcher selector")
                            showLauncherSelector()
                        }
                    }
                    menuHandler?.postDelayed(menuRunnable!!, MENU_HOLD_DURATION)
                }
                return true
            }

            // Method 2: HOME button (Common on H96 MAX remotes)
            KeyEvent.KEYCODE_HOME -> {
                Log.d(TAG, "HOME button pressed - opening launcher selector")
                showLauncherSelector()
                return true
            }

            // Method 3: Mouse/OK button (Center button on H96 MAX remote)
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                Log.d(TAG, "CENTER/OK button pressed - opening launcher selector")
                showLauncherSelector()
                return true
            }

            // Method 4: Settings button (If available on H96 MAX remote)
            KeyEvent.KEYCODE_SETTINGS -> {
                Log.d(TAG, "SETTINGS button pressed - opening launcher selector")
                showLauncherSelector()
                return true
            }

            // Method 5: Power button (Some H96 MAX remotes have this)
            KeyEvent.KEYCODE_POWER -> {
                Log.d(TAG, "POWER button pressed - opening launcher selector")
                showLauncherSelector()
                return true
            }

            // Method 6: TV button (Common on H96 MAX remotes)
            KeyEvent.KEYCODE_TV -> {
                Log.d(TAG, "TV button pressed - opening launcher selector")
                showLauncherSelector()
                return true
            }

            // Method 7: Netflix/YouTube buttons (Red/Green colored buttons)
            KeyEvent.KEYCODE_PROG_RED -> {
                Log.d(TAG, "RED button pressed - opening launcher selector")
                showLauncherSelector()
                return true
            }

            KeyEvent.KEYCODE_PROG_GREEN -> {
                Log.d(TAG, "GREEN button pressed - opening launcher selector")
                showLauncherSelector()
                return true
            }

            // Method 8: Triple-press BACK button quickly
            KeyEvent.KEYCODE_BACK -> {
                handleTripleBackPress()
                return true
            }

            // Method 9: Number sequence 0-0-0-0 (Easy to remember)
            KeyEvent.KEYCODE_0, KeyEvent.KEYCODE_1, KeyEvent.KEYCODE_2, KeyEvent.KEYCODE_3, KeyEvent.KEYCODE_4 -> {
                handleNumberSequence(keyCode)
                return true
            }

            // Method 10: Volume buttons combination
            KeyEvent.KEYCODE_VOLUME_UP -> {
                handleVolumeSequence(keyCode)
                return true
            }

            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                handleVolumeSequence(keyCode)
                return true
            }

            // Log unknown keys for debugging H96 MAX specific buttons
            else -> {
                Log.d(TAG, "Unknown key pressed: $keyCode - you can add this to launcher triggers")
                return super.onKeyDown(keyCode, event)
            }
        }
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_MENU -> {
                // Cancel the hold timer when MENU key is released
                isMenuKeyHeld = false
                menuHandler?.removeCallbacks(menuRunnable!!)

                val holdTime = System.currentTimeMillis() - menuKeyPressTime
                Log.d(TAG, "MENU key released after ${holdTime}ms")
                return true
            }
        }
        return super.onKeyUp(keyCode, event)
    }

    // Triple-back press handler
    private var backPressCount = 0
    private var lastBackPressTime: Long = 0
    private val BACK_PRESS_INTERVAL = 1000L // 1 second

    private fun handleTripleBackPress() {
        val currentTime = System.currentTimeMillis()

        if (currentTime - lastBackPressTime > BACK_PRESS_INTERVAL) {
            backPressCount = 1
        } else {
            backPressCount++
        }

        lastBackPressTime = currentTime

        Log.d(TAG, "Back press count: $backPressCount")

        if (backPressCount >= 3) {
            Log.d(TAG, "Triple back press detected - opening launcher selector")
            showLauncherSelector()
            backPressCount = 0
        }
    }

    // Number sequence handler - Changed to 0-0-0-0 for easier use
    private var numberSequence = mutableListOf<Int>()
    private var lastNumberPressTime: Long = 0
    private val NUMBER_PRESS_INTERVAL = 3000L // 3 seconds (more time for TV remote)
    private val SECRET_SEQUENCE = listOf(
        KeyEvent.KEYCODE_0,
        KeyEvent.KEYCODE_0,
        KeyEvent.KEYCODE_0,
        KeyEvent.KEYCODE_0
    )

    private fun handleNumberSequence(keyCode: Int) {
        val currentTime = System.currentTimeMillis()

        if (currentTime - lastNumberPressTime > NUMBER_PRESS_INTERVAL) {
            numberSequence.clear()
        }

        numberSequence.add(keyCode)
        lastNumberPressTime = currentTime

        Log.d(TAG, "Number sequence: ${numberSequence.map { it - KeyEvent.KEYCODE_0 }}")

        if (numberSequence.size >= SECRET_SEQUENCE.size) {
            if (numberSequence.takeLast(SECRET_SEQUENCE.size) == SECRET_SEQUENCE) {
                Log.d(TAG, "Secret sequence 0-0-0-0 detected - opening launcher selector")
                showLauncherSelector()
                numberSequence.clear()
            } else if (numberSequence.size > SECRET_SEQUENCE.size) {
                numberSequence.removeAt(0) // Keep only last 4 presses
            }
        }
    }

    // Volume button sequence handler for H96 MAX
    private var volumeSequence = mutableListOf<Int>()
    private var lastVolumePress: Long = 0
    private val VOLUME_PRESS_INTERVAL = 2000L // 2 seconds

    private fun handleVolumeSequence(keyCode: Int) {
        val currentTime = System.currentTimeMillis()

        if (currentTime - lastVolumePress > VOLUME_PRESS_INTERVAL) {
            volumeSequence.clear()
        }

        volumeSequence.add(keyCode)
        lastVolumePress = currentTime

        Log.d(TAG, "Volume sequence: ${volumeSequence.size} presses")

        // Volume Up + Volume Down + Volume Up + Volume Down
        val volumePattern = listOf(
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN
        )

        if (volumeSequence.size >= volumePattern.size) {
            if (volumeSequence.takeLast(volumePattern.size) == volumePattern) {
                Log.d(TAG, "Volume sequence detected - opening launcher selector")
                showLauncherSelector()
                volumeSequence.clear()
            } else if (volumeSequence.size > volumePattern.size) {
                volumeSequence.removeAt(0)
            }
        }
    }

    // Show launcher selection dialog
    private fun showLauncherSelector() {
        try {
            Log.d(TAG, "Attempting to show launcher selection dialog...")

            // Method 1: Create intent that triggers launcher chooser
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }

            // Create chooser to force selection dialog
            val chooserIntent = Intent.createChooser(homeIntent, "Select Home Launcher").apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }

            startActivity(chooserIntent)
            Log.d(TAG, "Launcher chooser dialog opened successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to open launcher chooser: ${e.message}")

            // Method 2: Alternative approach - clear current default and trigger selection
            try {
                Log.d(TAG, "Trying alternative method...")

                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    addCategory(Intent.CATEGORY_DEFAULT)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                }

                startActivity(homeIntent)
                Log.d(TAG, "Home intent launched successfully")

            } catch (homeException: Exception) {
                Log.e(TAG, "Failed to launch home intent: ${homeException.message}")

                // Method 3: Open Home settings as fallback
                try {
                    val settingsIntent = Intent().apply {
                        action = android.provider.Settings.ACTION_HOME_SETTINGS
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(settingsIntent)
                    Log.d(TAG, "Home settings opened as fallback")

                } catch (settingsException: Exception) {
                    Log.e(TAG, "Failed to open home settings: ${settingsException.message}")

                    // Method 4: Last resort - general settings
                    try {
                        val generalSettingsIntent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(generalSettingsIntent)
                        Log.d(TAG, "General settings opened as last resort")

                    } catch (generalException: Exception) {
                        Log.e(TAG, "All methods failed: ${generalException.message}")
                    }
                }
            }
        }
    }
}