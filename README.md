# BLE Device Manager

This is a Flutter application for managing Bluetooth Low Energy (BLE) devices. It allows you to scan for nearby devices, connect to them, and view their connection status.

## Features

*   **Scan for BLE devices:** Discover nearby BLE devices.
*   **Connect to devices:** Establish a connection with a selected device.
*   **View connection status:** See which devices are currently connected and which are not.
*   **Save paired devices:** Keep a list of your paired devices for easy reconnection.

## Getting Started

To get started with this project, you'll need to have the Flutter SDK installed.

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

## Dependencies

This project uses the following main dependencies:

*   [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus): For BLE communication.
*   [shared_preferences](https://pub.dev/packages/shared_preferences): For storing paired devices.
*   [permission_handler](https://pub.dev/packages/permission_handler): For handling Bluetooth permissions.