package dev.pleyground.hello

import ai.pleos.playground.vehicle.Vehicle
import ai.pleos.playground.vehicle.api.Door
import ai.pleos.playground.vehicle.api.model.area.DoorArea
import ai.pleos.playground.vehicle.constant.area.DoorValue
import ai.pleos.playground.vehicle.listener.DoorPositionListener
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class MainActivity : ComponentActivity() {

    private val vehicle by lazy { Vehicle(applicationContext) }
    private var door: Door? = null
    private val driverDoor = DoorArea(DoorValue.ROW_1_LEFT)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var connection by mutableStateOf<Connection>(Connection.Connecting)
    private var doorPosition by mutableStateOf<Int?>(null)

    private val doorListener = object : DoorPositionListener {
        override fun onPositionUpdated(pos: Int?) = runOnUiThread { doorPosition = pos }
        override fun onFailed(e: Exception) = report("Door updates failed", e)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { HelloScreen(connection, doorPosition) }
        connect()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        door?.unregisterDoorPosition(driverDoor, doorListener)
        vehicle.release()
        super.onDestroy()
    }

    private fun connect() {
        try {
            vehicle.initialize()
            door = vehicle.getDoor().also { it.registerDoorPosition(driverDoor, doorListener) }
            readDoor()
        } catch (e: Exception) {
            report("Vehicle SDK init failed", e)
        }
    }

    // initialize() binds to the vehicle service asynchronously and calls made before the bind
    // completes never call back, so keep reading until the first result lands.
    private fun readDoor(attempt: Int = 1) {
        if (connection == Connection.Connected || isDestroyed) return
        door?.getCurrentDoorPosition(
            area = driverDoor,
            onComplete = { pos -> runOnUiThread { doorPosition = pos; connection = Connection.Connected } },
            onFailed = { report("Door read failed", it) },
        )
        if (attempt < MAX_READ_ATTEMPTS) mainHandler.postDelayed({ readDoor(attempt + 1) }, 1_000)
    }

    private fun report(message: String, e: Exception) {
        Log.w(TAG, message, e)
        runOnUiThread { connection = Connection.Failed("$message: ${e.message}") }
    }

    private companion object {
        const val TAG = "Pleyground"
        const val MAX_READ_ATTEMPTS = 10
    }
}
