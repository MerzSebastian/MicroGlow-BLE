/*
 * ESP32-S3 Bluetooth WS2812B LED Controller
 * 
 * Controls WS2812B LED ring light via Bluetooth Low Energy (BLE)
 * 
 * Hardware:
 * - ESP32-S3 board
 * - WS2812B LED ring/strip
 * 
 * Connections:
 * - WS2812B Data -> GPIO 8 (configurable)
 * - WS2812B VCC -> 5V
 * - WS2812B GND -> GND
 * 
 * BLE Commands:
 * Send RGB values as comma-separated string: "R,G,B"
 * Example: "255,0,0" for red, "0,255,0" for green, "0,0,255" for blue
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <FastLED.h>
#include <Preferences.h>

// LED Configuration
#define LED_PIN     13       // GPIO pin connected to WS2812B data line
#define NUM_LEDS    16       // Number of LEDs in your ring light (change as needed)
#define LED_TYPE    WS2812B
#define COLOR_ORDER GRB

// BLE UUIDs
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Global variables
CRGB leds[NUM_LEDS];
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

uint8_t currentR = 255;
uint8_t currentG = 255;
uint8_t currentB = 255;

// Preferences object for EEPROM storage
Preferences preferences;

// Forward declarations
void setAllLEDs(uint8_t r, uint8_t g, uint8_t b);
void saveColorToEEPROM();
void loadColorFromEEPROM();

// BLE Server Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected");
    }
};

// BLE Characteristic Callbacks
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String receivedData = String(pCharacteristic->getValue().c_str());

      if (receivedData.length() > 0) {
        Serial.println("Received: " + receivedData);
        
        // Parse RGB values from comma-separated string
        int firstComma = receivedData.indexOf(',');
        int secondComma = receivedData.indexOf(',', firstComma + 1);
        
        if (firstComma > 0 && secondComma > firstComma) {
          int r = receivedData.substring(0, firstComma).toInt();
          int g = receivedData.substring(firstComma + 1, secondComma).toInt();
          int b = receivedData.substring(secondComma + 1).toInt();
          
          // Validate RGB values
          if (r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255) {
            currentR = r;
            currentG = g;
            currentB = b;
            
            Serial.printf("Setting color to R:%d G:%d B:%d\n", r, g, b);
            setAllLEDs(currentR, currentG, currentB);
            saveColorToEEPROM();
          } else {
            Serial.println("Invalid RGB values (must be 0-255)");
          }
        } else {
          Serial.println("Invalid format. Use: R,G,B");
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  delay(1000); // Wait for Serial to initialize
  Serial.println("Starting ESP32-S3 BLE WS2812B Controller...");

  // Load saved color from EEPROM
  loadColorFromEEPROM();

  // Initialize FastLED
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(255);
  
  // Set initial color to saved value
  setAllLEDs(currentR, currentG, currentB);

  // Initialize BLE
  BLEDevice::init("ESP32-LED-Controller");
  
  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCallbacks());
  
  // Set initial value
  String initialValue = String(currentR) + "," + String(currentG) + "," + String(currentB);
  pCharacteristic->setValue(initialValue.c_str());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE device is ready!");
  Serial.println("Device name: ESP32-LED-Controller");
  Serial.println("Waiting for connection...");
}

void loop() {
  // Handle disconnection and reconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Start advertising again");
    oldDeviceConnected = deviceConnected;
  }
  
  // Handle new connection
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("Client connected");
  }
  
  delay(20);
}

// Function to set all LEDs to the same color
void setAllLEDs(uint8_t r, uint8_t g, uint8_t b) {
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = CRGB(r, g, b);
  }
  FastLED.show();
}

// Save current color to EEPROM
void saveColorToEEPROM() {
  preferences.begin("led-colors", false);
  preferences.putUChar("red", currentR);
  preferences.putUChar("green", currentG);
  preferences.putUChar("blue", currentB);
  preferences.end();
  Serial.println("Color saved to EEPROM");
}

// Load saved color from EEPROM
void loadColorFromEEPROM() {
  preferences.begin("led-colors", true);
  currentR = preferences.getUChar("red", 255);    // Default to white if not saved
  currentG = preferences.getUChar("green", 255);
  currentB = preferences.getUChar("blue", 255);
  preferences.end();
  Serial.printf("Loaded color from EEPROM - R:%d G:%d B:%d\n", currentR, currentG, currentB);
}
