# BLE WS2812B LED Controller

A Flutter app to control WS2812B LED strips via Bluetooth Low Energy (BLE) connected to an ESP32-S3.

## Features

- 🎨 **Color Wheel Picker** - Select colors intuitively using a visual color wheel
- 🎚️ **RGB Sliders** - Fine-tune colors with individual Red, Green, and Blue sliders (0-255)
- 📱 **BLE Connectivity** - Connect to ESP32-S3 device wirelessly
- ⚡ **Real-time Updates** - Changes are sent instantly to the LED strip

## How to Use

1. **Upload Arduino Code** to your ESP32-S3 (device name: "ESP32-LED-Controller")
2. **Run the Flutter App** on your phone or tablet
3. **Tap the Bluetooth Icon** in the app bar
4. **Scan for Devices** and connect to "ESP32-LED-Controller"
5. **Pick Colors** using the color wheel or adjust RGB sliders
6. **Watch Your LEDs Change** in real-time!

## Hardware Requirements

- ESP32-S3 board
- WS2812B LED ring/strip
- Android device with Bluetooth 4.0+ (for the app)

## BLE Protocol

The app sends RGB values as comma-separated strings:
```
"R,G,B"
```
Example: `"255,0,0"` for red, `"0,255,0"` for green, `"0,0,255"` for blue

**Service UUID:** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`  
**Characteristic UUID:** `beb5483e-36e1-4688-b7f5-ea07361b26a8`
