# Gemini Project Context: BLE App

This document provides context for the Gemini agent about the Flutter BLE application.

## Project Overview

This is a Flutter application named `bleapp` designed to scan, connect to, and manage Bluetooth Low Energy (BLE) devices. The core functionality involves discovering devices, maintaining a list of paired devices, and displaying their connection status.

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **Core Dependencies:**
  - `flutter_blue_plus`: For all Bluetooth Low Energy interactions.
  - `shared_preferences`: To persist the list of paired devices locally on the device.
  - `permission_handler`: To request necessary Bluetooth and location permissions from the user.

## Project Structure

- `lib/main.dart`: The main entry point of the application. It displays the lists of connected and disconnected devices.
- `lib/connect_page.dart`: (Assumed) A page to interact with a connected BLE device.
- `lib/pairing.dart`: (Assumed) A page that handles the scanning and pairing process for new devices.
- `pubspec.yaml`: Defines all project dependencies and metadata.
- `analysis_options.yaml`: Contains Dart linting rules, configured to use `flutter_lints`.

## Development Workflow & Commands

- **Install Dependencies:**
  ```bash
  flutter pub get
  ```
- **Run the Application:**
  ```bash
  flutter run
  ```
- **Run Tests:**
  ```bash
  flutter test
  ```
- **Analyze Code (Linting):**
  ```bash
  flutter analyze
  ```

## Coding Conventions

- The project follows standard Flutter and Dart coding conventions.
- All code should adhere to the linting rules defined in `analysis_options.yaml`.
- UI components should maintain a consistent style, using the color scheme and widget structure found in `lib/main.dart` (e.g., `Scaffold`, `Card`, `AppBar` with `Color(0xFF66B2A3)`).
