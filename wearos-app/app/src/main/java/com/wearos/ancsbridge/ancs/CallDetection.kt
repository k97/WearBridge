package com.wearos.ancsbridge.ancs

import com.wearos.ancsbridge.ble.AncsConstants

/**
 * Decides whether an ANCS notification is a ringing call. The category is
 * authoritative; VoIP apps (WhatsApp...) sometimes post calls in other
 * categories, recognized by wording, but a chat message mentioning a call
 * ("missed voice call", "video call at 8?", "I'm bringing food") must not
 * open the call screen.
 */
object CallDetection {

    private val ringing = Regex(
        """\bincoming\s+(voice\s+|video\s+|audio\s+)?call\b|\bis\s+calling\b|☎""",
        RegexOption.IGNORE_CASE
    )
    private val missed = Regex("""\bmissed\b|\bmanqu""", RegexOption.IGNORE_CASE)

    fun isIncomingCall(
        categoryId: Int,
        appIdentifier: String,
        title: String,
        message: String,
        hasPositiveAction: Boolean,
        callApps: Set<String>
    ): Boolean {
        if (categoryId == AncsConstants.CATEGORY_INCOMING_CALL) return true
        val text = "$title $message"
        if (missed.containsMatchIn(text) || !ringing.containsMatchIn(text)) return false
        // A ringing call offers an action (Answer), or comes from a known call app.
        return hasPositiveAction || appIdentifier in callApps
    }
}
