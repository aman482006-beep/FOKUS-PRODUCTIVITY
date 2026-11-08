# Fokus ⚡

> A cross-platform productivity workspace built around focused work, ambient environments, and lightweight personal systems.

Fokus is a Flutter productivity application designed to make deep work easier to start and easier to sustain. It combines focus sessions with ambient audio, visual scenes, reminders, local persistence, and desktop-oriented controls in one application.

This is a deliberately practical build: the goal is not another static timer, but a small productivity system with real application architecture, state management, persistence, and platform integration.

## What it does

- ⏱️ **Focus sessions** for structured deep-work blocks.
- 🌧️ **Ambient environments** with sounds and visual scenes for different work modes.
- 🔔 **Notifications & reminders** for session boundaries and routines.
- 🎧 **Audio playback** for rain, ocean, forest, and other background environments.
- 📊 **Productivity analytics** using chart-based visualisation.
- 📄 **File/PDF workflows** with local file picking and text recognition support.
- 🖥️ **Desktop support** including fullscreen/window management and Windows packaging.
- 🔗 **Deep links** for application-level navigation and authentication flows.
- 💾 **Local persistence** for preferences and session-related state.

## Install on Windows

Prefer installing the packaged Windows version? **Fokus is available directly through the Microsoft Store.**

👉 **[Install Fokus from the Microsoft Store](https://apps.microsoft.com/detail/9P7NJLDQ8GKK?hl=en-us&gl=IN&ocid=pdpshare)**

The Store version is the easiest option for users who simply want to install and use the application without setting up the Flutter development environment.

## Architecture

The application uses a service-oriented Flutter structure with dependency injection and Riverpod for state management.

```text
lib/
├── core/          # App composition, configuration and dependency injection
├── services/      # Storage, audio, notifications, deep links and integrations
├── features/      # Product functionality and UI flows
└── main.dart      # Application bootstrap and error handling
```

The bootstrap layer initializes services through a dependency-injection container, isolates non-fatal platform failures, and keeps the application startup resilient across supported platforms.

## Tech stack

| Area | Technology |
|---|---|
| Application | Flutter / Dart |
| State management | Riverpod |
| Dependency injection | GetIt |
| Persistence | SharedPreferences |
| Audio | just_audio |
| Notifications | flutter_local_notifications |
| Analytics | fl_chart |
| Files & PDFs | file_picker, Syncfusion PDF |
| Text recognition | Google ML Kit |
| Desktop | window_manager, Win32 / FFI |
| Deep links | app_links |

## Run locally

```bash
git clone https://github.com/aman482006-beep/FOKUS-PRODUCTIVITY.git
cd FOKUS-PRODUCTIVITY
flutter pub get
flutter run
```

For Windows packaging:

```bash
flutter build windows
```

## Engineering highlights

**Resilient startup:** service initialization is guarded so a platform-specific failure does not unnecessarily prevent the app from launching.

**Stateful product architecture:** application state is separated from UI through Riverpod rather than being coupled to individual screens.

**Local-first behaviour:** preferences and core user state can persist without making the basic focus experience dependent on a remote backend.

**Platform awareness:** the project accounts for differences between web and desktop runtimes instead of treating Flutter as a single identical target.

## Status

🚧 Personal project under active development. The current codebase is being used as a foundation for a more complete cross-platform productivity product.
