package dev.pleyground.hello

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

sealed interface Connection {
    data object Connecting : Connection
    data object Connected : Connection
    data class Failed(val reason: String) : Connection
}

private val Night = Color(0xFF0A0F1C)
private val Deep = Color(0xFF0B2B3C)
private val CardColor = Color(0xFF121C2E)
private val Teal = Color(0xFF38E1C6)
private val Blue = Color(0xFF5B8CFF)
private val Muted = Color(0xFF9FB3C8)
private val Danger = Color(0xFFFF6B6B)
private val Amber = Color(0xFFFFC857)

@Composable
fun HelloScreen(connection: Connection, doorPosition: Int?) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(listOf(Night, Deep))),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Text("Pleyground", color = Color.White, fontSize = 72.sp, fontWeight = FontWeight.ExtraBold)
            Text(
                "Pleos Connect + Playground",
                style = TextStyle(brush = Brush.horizontalGradient(listOf(Teal, Blue))),
                fontSize = 28.sp,
                fontWeight = FontWeight.SemiBold,
            )
            DoorCard(doorPosition, Modifier.padding(top = 40.dp))
            StatusChip(connection)
        }
    }
}

@Composable
private fun DoorCard(doorPosition: Int?, modifier: Modifier = Modifier) {
    Column(
        modifier
            .width(520.dp)
            .background(CardColor, RoundedCornerShape(32.dp))
            .padding(horizontal = 40.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text("DRIVER DOOR", color = Muted, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 3.sp)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            Text(doorPosition?.toString() ?: "–", color = Color.White, fontSize = 96.sp, fontWeight = FontWeight.Bold)
            Text(
                when (doorPosition) {
                    null -> "Waiting"
                    0 -> "Closed"
                    else -> "Open"
                },
                color = if (doorPosition == null || doorPosition == 0) Teal else Amber,
                fontSize = 32.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(bottom = 20.dp),
            )
        }
        Text("Vehicle SDK · DoorArea ROW_1_LEFT", color = Muted, fontSize = 16.sp)
    }
}

@Composable
private fun StatusChip(connection: Connection) {
    val (color, label) = when (connection) {
        Connection.Connecting -> Amber to "Connecting to vehicle service…"
        Connection.Connected -> Teal to "Connected to vehicle service"
        is Connection.Failed -> Danger to connection.reason
    }
    Row(
        Modifier
            .background(CardColor, RoundedCornerShape(50))
            .padding(horizontal = 24.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(12.dp).background(color, CircleShape))
        Text(label, color = Muted, fontSize = 18.sp)
    }
}
