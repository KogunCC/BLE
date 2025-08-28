# BLE Status - Bluetooth Device Management & Tracking App

**BLE Status** is a Flutter application designed to manage the connection status of Bluetooth Low Energy (BLE) devices and prevent their misplacement or loss. It provides real-time tracking, connection management, and location history for any BLE device.

Additionally, it offers richer information and advanced tracking capabilities when integrated with its dedicated companion device, **"AreraNaiTag."**

## 📸 Screenshots

*(Here you can add screenshots of the application. For example:)*

| Main Screen | Device Connection Screen |
| :---: | :---: |
| ![Main Screen](https://via.placeholder.com/300x600.png?text=Main+Screen) | ![Connection Screen](https://via.placeholder.com/300x600.png?text=Connection+Screen) |

## 🚀 Key Features

### General Features (Compatible with all BLE devices)
- **Device Scanning**: Discovers nearby BLE devices in real-time.
- **Connection & Management**: Establishes connections, displays status, and locally saves paired devices.
- **Real-time Status**: Shows whether a device is connected or disconnected.
- **Location Tracking**:
  - **Current Location**: View the current location of connected devices on a map.
  - **Disconnection Logging**: Automatically records the smartphone's location when a device disconnects.
  - **Last Known Location**: Displays the last recorded location for disconnected devices.

### Extended Features (with AreraNaiTag)
- **Real-time Battery Monitoring**: Displays the battery voltage of the AreraNaiTag.
- **(Future) Smartphone Call**: A planned feature to find your smartphone by pressing a button on the AreraNaiTag.

## 🧩 About AreraNaiTag

**AreraNaiTag** is a concept for a dedicated companion hardware device designed to work seamlessly with the BLE Status app. It is envisioned as a small, battery-powered tag that can be attached to personal belongings.

- **Specification**: Low-power BLE module, button for interaction.
- **Availability**: This is a conceptual device for demonstration purposes and is not commercially available.

## 🛠️ Technology Stack

- **Framework**: Flutter
- **Language**: Dart
- **Core Libraries**:
  - `flutter_blue_plus`: For all BLE communication.
  - `shared_preferences`: For local data persistence (paired devices, location history).
  - `permission_handler`: To manage OS-level permissions (Bluetooth, Location).
  - `geolocator`: To acquire the smartphone's location.
  - `url_launcher`: To launch external map applications.
  - `flutter_foreground_task`: For background processing to monitor connections.

## 📂 Project Structure

The main source code is located in the `lib/` directory.
```
lib/
├── main.dart           # App entry point, main screen
├── pairing.dart        # Screen for scanning and pairing new devices
├── connect_page.dart   # Screen for interacting with a connected device
├── models/
│   └── paired_device.dart # Data model for paired devices
└── utils/
    ├── app_constants.dart
    ├── foreground_service_handler.dart
    ├── location_service.dart
    ├── notification_service.dart
    └── theme_manager.dart
```

## ⚙️ Setup and Usage

### Prerequisites
- Flutter SDK installed ([see official guide](https://flutter.dev/docs/get-started/install)).
- An IDE like VS Code or Android Studio.
- For iOS: Xcode installed.
- For Android: Android Studio and Android SDK installed.

### Installation & Running
1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    ```
2.  **Navigate to the project directory**:
    ```bash
    cd FlutterApp
    ```
3.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
4.  **Run the application**:
    ```bash
    flutter run
    ```

### How to Use
1.  **Pair a New Device**:
    - Tap the "ペアリング画面へ" (Go to Pairing) button on the main screen.
    - The app will scan for nearby BLE devices.
    - Select a device from the list to pair and connect.
2.  **View Connected Devices**:
    - Connected devices are listed under the "接続済み" (Connected) section on the main screen.
    - Tap on a device to view more details, such as RSSI, estimated distance, and battery level (for AreraNaiTag).
3.  **Find a Disconnected Device**:
    - Disconnected devices appear under the "接続が切れたデバイス" (Disconnected) section.
    - Tap the location icon (📍) to view the device's last known location on a map.
    - Tap the device card to attempt reconnection.

## 💡 Future Work

- **Implement Smartphone Call**: Enable the "find my phone" feature using the AreraNaiTag button.
- **Enhanced Location History**: Implement a more robust local database (like `sqflite` or `hive`) to store a history of disconnection locations.
- **Customizable Alerts**: Allow users to configure alerts for connection/disconnection events.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/your-username/your-repository/issues).

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---
*This README was last updated on 2025-08-28.*
