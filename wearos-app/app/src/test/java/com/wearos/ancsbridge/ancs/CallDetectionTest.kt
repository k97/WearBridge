package com.wearos.ancsbridge.ancs

import com.wearos.ancsbridge.ble.AncsConstants
import org.junit.Assert.*
import org.junit.Test

class CallDetectionTest {

    private val callApps = setOf("net.whatsapp.WhatsApp", "com.apple.mobilephone")

    private fun detect(
        title: String,
        message: String,
        app: String = "net.whatsapp.WhatsApp",
        category: Int = AncsConstants.CATEGORY_SOCIAL,
        positive: Boolean = false
    ) = CallDetection.isIncomingCall(category, app, title, message, positive, callApps)

    @Test
    fun `the incoming call category always counts`() {
        assertTrue(detect("Marie", "", app = "com.apple.mobilephone", category = AncsConstants.CATEGORY_INCOMING_CALL))
    }

    @Test
    fun `VoIP call wording counts`() {
        assertTrue(detect("Marie", "☎ Incoming voice call"))
        assertTrue(detect("Marie", "Incoming video call"))
        assertTrue(detect("Paul is calling", "", app = "com.example.voip", positive = true))
    }

    @Test
    fun `chat messages about calls don't`() {
        assertFalse(detect("Marie", "Missed voice call"))
        assertFalse(detect("Marie", "video call at 8?"))
        assertFalse(detect("Marie", "I'm bringing food"))
        assertFalse(detect("Marie", "Appel vocal manqué ☎"))
        assertFalse(detect("Marie", "Incoming call", app = "com.example.chat", positive = false))
    }
}
