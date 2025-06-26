# BlueTaggers（ブルータッガーズ）

This is a Flutter application for managing Bluetooth Low Energy (BLE) devices. It allows you to scan for nearby devices, connect to them, and view their connection status.

## Features

*   **Scan for BLE devices:** Discover nearby BLE devices.
*   **Connect to devices:** Establish a connection with a selected device.
*   **View connection status:** See which devices are currently connected and which are not.
*   **Save paired devices:** Keep a list of your paired devices for easy reconnection.

## Getting Started

To get started with this project, you'll need to have the Flutter SDK installed.

## 🛠 Getting Started

To run this app on your local machine:

This application can be run on both Android and iOS devices. Make sure to configure your environment for the appropriate platform. You may need Xcode for iOS and Android Studio for Android builds.

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the app:**
    ```bash
    flutter run
    ```

## 📱 What This App Does

BLE Device Manager allows users to interact with Bluetooth Low Energy devices through a streamlined interface. Here's what it does:

- Scans for available BLE devices in the vicinity
- Lets users initiate a connection to a selected device
- Displays current connection status (connected / disconnected)
- Saves the paired device list locally for quick reconnections
- Requests and manages the necessary runtime permissions on the device

## Dependencies

This project uses the following main dependencies:

*   [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus): For BLE communication.
*   [shared_preferences](https://pub.dev/packages/shared_preferences): For storing paired devices.
*   [permission_handler](https://pub.dev/packages/permission_handler): For handling Bluetooth permissions.
# BLE Device Manager

A Flutter application for managing Bluetooth Low Energy (BLE) devices. With this app, you can easily scan for nearby devices, connect to them, and monitor their connection status.

## 🚀 Features

- **Device Scanning**  
  Discover nearby BLE devices in real time.

- **Connect to Devices**  
  Select and establish connections with BLE devices.

- **Connection Status**  
  View which devices are connected and track their status.

- **Pairing Memory**  
  Save paired devices for quick and easy reconnection.

## 🛠 Getting Started

To run this app on your local machine:

1. **Clone the Repository**
    ```bash
    git clone <repository-url>
    ```

2. **Install Dependencies**
    ```bash
    flutter pub get
    ```

3. **Launch the App**
    ```bash
    flutter run
    ```

> ⚠️ Make sure you have Flutter installed and set up correctly. Visit [flutter.dev](https://flutter.dev/docs/get-started/install) for setup instructions.

## 📦 Dependencies

This app makes use of the following packages:

- [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) — For managing BLE communication
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) — For persisting paired device info
- [`permission_handler`](https://pub.dev/packages/permission_handler) — For managing runtime permissions

---

Feel free to contribute or raise issues to help improve this project!