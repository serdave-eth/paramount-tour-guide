# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VisionClaw is a real-time AI assistant for Meta Ray-Ban smart glasses. It connects glasses camera/microphone to the Gemini Live API over WebSocket for voice + vision conversations, with optional OpenClaw integration for agentic actions (messaging, web search, smart home). Dual-platform: iOS (Swift/SwiftUI) and Android (Kotlin/Jetpack Compose).

## Build Commands

### iOS
```bash
open samples/CameraAccess/CameraAccess.xcodeproj   # Open in Xcode, then Cmd+R
```
No CLI build — Xcode-only workflow. Requires iOS 17.0+, Xcode 15.0+.

### Android
```bash
cd samples/CameraAccessAndroid
./gradlew assembleDebug      # Build debug APK
./gradlew assembleRelease    # Build release APK
./gradlew installDebug       # Build and install on device
```
Requires a GitHub token with `read:packages` scope in `local.properties` (for Meta DAT SDK from GitHub Packages).

### WebRTC Signaling Server
```bash
cd samples/CameraAccess/server
npm install && npm start     # Port 8080
```

## Secrets Setup (Required Before Building)

**iOS:** `cp samples/CameraAccess/CameraAccess/Secrets.swift.example samples/CameraAccess/CameraAccess/Secrets.swift`
**Android:** `cp samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/Secrets.kt.example` → same path without `.example`

At minimum, set `geminiAPIKey`. OpenClaw and WebRTC config are optional. All secrets can be overridden at runtime via the in-app Settings screen.

## Architecture

### Data Flow
```
Glasses/Phone Camera → App → JPEG ~1fps + PCM 16kHz audio → Gemini Live WebSocket
Gemini → PCM 24kHz audio response → App → Speaker
Gemini → toolCall(execute) → App → OpenClaw HTTP gateway → 56+ skills → toolResponse back to Gemini
```

### Module Structure (mirrored across iOS and Android)

| Module | Purpose |
|--------|---------|
| `Gemini/` | WebSocket client (`GeminiLiveService`), audio I/O (`AudioManager`), session orchestration (`GeminiSessionViewModel`), config |
| `OpenClaw/` | HTTP bridge to OpenClaw gateway (`OpenClawBridge`), tool call routing (`ToolCallRouter`), tool data models |
| `WebRTC/` | Live POV streaming via WebRTC peer connection + signaling server |
| `iPhone/` (iOS) / `phone/` (Android) | Phone camera mode using AVCaptureSession / CameraX |
| `Settings/` | Persistent settings with fallback to Secrets values |
| `Views/` (iOS) / `ui/` (Android) | UI layer |

### iOS Source Root
`samples/CameraAccess/CameraAccess/`

### Android Source Root
`samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/`

## Key Parameters

- **Gemini model:** `models/gemini-2.5-flash-native-audio-preview-12-2025`
- **Audio in:** PCM Int16, 16kHz mono, 100ms chunks
- **Audio out:** PCM Int16, 24kHz mono
- **Video:** JPEG 50% quality, throttled to ~1fps (DAT SDK streams 24fps)
- **OpenClaw:** HTTP POST to `/v1/chat/completions` on port 18789, Bearer token auth, `x-openclaw-session-key` header, conversation history capped at 10 turns

## Code Conventions

### iOS (Swift)
- `@MainActor` on all ViewModels and service classes
- `ObservableObject` + `@Published` for reactive state
- Async/await throughout; callbacks (`var onAudioReceived: ((Data) -> Void)?`) for service→viewmodel communication
- `NSLog()` for logging (not `print`)
- Secrets/Config are `enum` with `static` properties

### Android (Kotlin)
- `StateFlow` / `MutableStateFlow` for reactive state (not LiveData)
- `ViewModel` + `viewModelScope` for coroutine lifecycle
- `withContext(Dispatchers.IO)` for network calls
- `OkHttp` for all HTTP and WebSocket communication
- `Log.d/e(TAG, ...)` for logging
- `data class` for UI state, `sealed class` for connection state enums
- Secrets is an `object` with `const val` properties

### Shared Patterns
- Single tool declaration: Gemini gets one function (`execute`) that routes everything through OpenClaw
- Settings layer wraps UserDefaults (iOS) / SharedPreferences (Android) with fallback to Secrets values
- Echo prevention: mic muted during AI speech in phone mode (co-located speaker); glasses mode unaffected
- Session key format: `agent:main:glass:<ISO8601 timestamp>`

## Dependencies

### iOS (Swift Package Manager)
- `MWDATCore`, `MWDATCamera`, `MWDATMockDevice` — Meta Wearables DAT SDK
- `WebRTC` — Google WebRTC framework

### Android (Gradle version catalog: `gradle/libs.versions.toml`)
- `mwdat-*` 0.4.0 — Meta DAT SDK (GitHub Packages)
- `okhttp` 4.12.0 — HTTP/WebSocket
- `stream-webrtc-android` 1.1.3 — WebRTC
- CameraX 1.4.1 — Phone camera
- Compose BOM 2024.04.01 — Jetpack Compose
- `gson` 2.11.0 — JSON serialization
