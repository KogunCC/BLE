# BLE Status - Bluetooth Device Management & Tracking App

## Overview

"BLE Status" is a Flutter application designed to manage the connection status of Bluetooth Low Energy (BLE) devices and prevent their misplacement or loss. In addition to general BLE device tracking, it offers richer information acquisition and advanced tracking capabilities through integration with the dedicated companion device "AreraNaiTag."

## 🚀 Key Features

### General Features (Compatible with all BLE devices)
*   **Device Scanning**: Discovers nearby BLE devices in real-time.
*   **Connection and Management**: Establishes connections to selected devices, displays connection status, and locally saves paired devices.
*   **Location Tracking**:
    *   **Current Location Display for Connected Devices**: Allows users to view the current location of the connected device and the smartphone on a map.
    *   **Location Information Recording on Device Disconnection**: Automatically records the smartphone's location when a device disconnects.
    *   **Last Known Location Display for Disconnected Devices**: Displays the recorded last known location on a map.
    *   **Location Information Deletion on Device Removal**: Cleans up associated location data when a device is removed from the app.

### Extended Features (AreraNaiTag Dedicated Device Integration)
*   **Real-time Battery Voltage Display**: Monitors the battery voltage of AreraNaiTag in real-time.
*   **(Future) Smartphone Call via Button Press**: A feature to call the smartphone by pressing a button on AreraNaiTag.

## 🛠 Development Environment and Setup

### Technology Stack
*   **Framework**: Flutter
*   **Language**: Dart
*   **Key Libraries**:
    *   `flutter_blue_plus`: Core functionality for BLE communication.
    *   `shared_preferences`: Persistent data storage for local data.
    *   `permission_handler`: Manages OS-level permissions.
    *   `geolocator`: Acquires smartphone location information.
    *   `url_launcher`: Launches external applications (e.g., map apps).
    *   **Data Persistence**: For storing location history, `shared_preferences` is used, with consideration for more robust local databases like `sqflite` or `hive`.

### Project Structure
Main source code is located in the `lib/` directory.
*   `lib/main.dart`: Application entry point, main screen.
*   `lib/pairing.dart`: New BLE device scanning and pairing screen.
*   `lib/connect_page.dart`: Screen for interacting with connected devices.
*   `lib/models/paired_device.dart`: Data model for paired devices.
*   `lib/utils/`: Constants and utility functions used throughout the application.

### Development Workflow
1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    ```
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Run the application**:
    ```bash
    flutter run
    ```
4.  **Static code analysis (Lint)**:
    ```bash
    flutter analyze
    ```
5.  **Run tests**:
    ```bash
    flutter test
    ```

> ⚠️ Ensure Flutter SDK is correctly installed and configured. Refer to [flutter.dev](https://flutter.dev/docs/get-started/install) for setup instructions.

## 💡 Technical Insights (Excerpts)

### BLE Device Scanning and Filtering
Utilizes `flutter_blue_plus`'s `startScan` method to discover nearby BLE devices as an asynchronous stream. Logic for duplicate exclusion and filtering by specific service UUIDs is implemented for efficient device discovery.

### Device State Management
Adopts a pattern of subscribing to the device's connection state (`connectionState`) stream to update the UI in real-time. Flutter's `StreamBuilder` or more advanced state management solutions (Provider, Riverpod, etc.) can be used.

### Persistence and Data Structure
`shared_preferences` is used for persisting device information, and the `PairedDevice` class manages device identifiers and display names. Location data is stored linked to each device with a timestamp.

### Asynchronous Processing and Error Handling
BLE operations and location acquisition are asynchronous, so Dart's `async/await` pattern is heavily used, along with robust error handling via `try-catch` blocks. Errors such as disabled location services or denied permissions are handled appropriately with user feedback.

### Background Processing Design
For recording location information upon device disconnection, even when the app is not in the foreground, consideration and implementation of platform-specific background processing (Android Service, iOS Background Modes) are necessary. Efficient acquisition frequency and controlled activation are required to manage battery consumption.

### Platform-Specific Considerations
*   **iOS**: Requires Bluetooth and location permission descriptions in `Info.plist` (`NSBluetoothAlwaysUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, etc.). Background operation has limitations.
*   **Android**: BLE scanning requires location permissions (`ACCESS_FINE_LOCATION`, etc.). Android 10 and later also require `ACCESS_BACKGROUND_LOCATION` for background location acquisition. Verifying that location services are enabled is also crucial.

---

Contributions and issue reports to this project are welcome!