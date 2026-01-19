# DDWave Build & Test Recipe

Complete step-by-step guide to build and test the ddwave app with ggwave integration.

## Prerequisites

### Required Tools
- **Node.js** (v18+) ✓ Already installed
- **Xcode** (15+) with Command Line Tools (for iOS)
- **Android Studio** (latest) with NDK (for Android)
- **CocoaPods** (for iOS dependencies)

### Physical Devices Required
⚠️ **Important**: Simulators/emulators won't work for audio testing. You need:
- iOS device (iPhone/iPad with microphone & speaker), OR
- Android device (with microphone & speaker)

---

## Build for iOS

### Step 1: Clean Previous Build
```bash
cd /Users/dominickdanao/Projects/ddwave
rm -rf ios/Pods ios/build
```

### Step 2: Install CocoaPods Dependencies
```bash
cd ios
pod install
cd ..
```

**Expected Output:**
- Should see "Installing ExpoGGWave" in the pod install output
- Should compile ggwave C++ sources (ggwave.cpp, reed-solomon/*.cpp)
- Creates `ios/Pods/` directory

**If pod install fails:**
```bash
# Update CocoaPods
sudo gem install cocoapods

# Clear cache and retry
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
```

### Step 3: Build iOS App
```bash
npm run ios
```

**This will:**
1. Start Metro bundler
2. Compile native code (Objective-C++, Swift, C++)
3. Build the app bundle
4. Deploy to connected iOS device (or simulator, but audio won't work)

**Expected build time:** 3-5 minutes (first build)

**If build fails with "No devices found":**
- Connect your iPhone/iPad via USB
- Trust the computer on your device
- Run `xcrun xctrace list devices` to verify device is detected

**If build fails with signing errors:**
- Open `ios/ddwave.xcworkspace` in Xcode
- Select your development team under Signing & Capabilities
- Close Xcode and retry `npm run ios`

### Step 4: Grant Permissions
When the app first launches:
1. You'll see a permission prompt for **Microphone Access**
2. Tap **Allow** (required for receiving audio data)

---

## Build for Android

### Step 1: Verify Android SDK & NDK
```bash
# Check if Android SDK is installed
echo $ANDROID_HOME

# Check if NDK is installed
ls $ANDROID_HOME/ndk/
```

**If not installed:**
1. Open Android Studio
2. Go to **Settings > Appearance & Behavior > System Settings > Android SDK**
3. Install:
   - Latest Android SDK Platform
   - NDK (Side by side) version 25 or higher
   - CMake (from SDK Tools tab)

### Step 2: Set Environment Variables (if needed)
Add to your `~/.zshrc` or `~/.bash_profile`:
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

Then reload:
```bash
source ~/.zshrc  # or source ~/.bash_profile
```

### Step 3: Clean Previous Build
```bash
cd /Users/dominickdanao/Projects/ddwave
rm -rf android/app/build android/.gradle
```

### Step 4: Build Android App
```bash
npm run android
```

**This will:**
1. Start Metro bundler
2. Run Gradle build
3. Compile C++ code via CMake (ggwave.cpp, ggwave-jni.cpp)
4. Compile Kotlin code
5. Deploy to connected Android device

**Expected build time:** 5-10 minutes (first build with C++ compilation)

**If build fails with "CMake not found":**
```bash
# Install CMake via Android Studio SDK Manager
# Or via Homebrew:
brew install cmake
```

**If build fails with "NDK not found":**
```bash
# Set NDK path explicitly
export ANDROID_NDK=$ANDROID_HOME/ndk/25.2.9519653  # adjust version

# Or install via SDK Manager in Android Studio
```

**If build fails with "No devices found":**
- Connect your Android device via USB
- Enable **Developer Options** on your device:
  - Go to Settings > About Phone
  - Tap "Build Number" 7 times
  - Go back to Settings > Developer Options
  - Enable "USB Debugging"
- Run `adb devices` to verify device is detected

### Step 5: Grant Permissions
When the app first launches:
1. You'll see a permission prompt for **Microphone** and **Modify Audio Settings**
2. Tap **Allow** for both (required for audio I/O)

---

## Testing the App

### Test 1: Basic Transmission

**On Device 1 (Transmitter):**
1. Open the app
2. Go to **Transmit** tab
3. Enter text: `Hello`
4. Select protocol: **Audible Fast** (default)
5. Volume: **50%**
6. Tap **Transmit**
7. You should hear a short audio tone (chirp sound)

**On Device 2 (Receiver):**
1. Open the app
2. Go to **Receive** tab
3. Tap **Start Listening**
4. Green indicator should appear
5. When Device 1 transmits, you should see "Hello" appear in the message list

### Test 2: Ultrasound Mode

**Repeat Test 1 but:**
- Use protocol: **Ultrasound Fast**
- You should NOT hear any sound (above human hearing range)
- Message should still be received successfully

### Test 3: Cross-Platform

**Test iOS ↔ Android:**
- Transmit from iOS, receive on Android
- Transmit from Android, receive on iOS
- Both directions should work identically

### Test 4: Distance & Volume

**Experiment with:**
- Different distances (10cm to 5m)
- Different volume levels (25%, 50%, 75%, 100%)
- Background noise environments
- Different protocols (Normal, Fast, Fastest)

### Test 5: Web Interoperability

**Use the official ggwave web demo:**
1. Go to https://waver.ggerganov.com on your laptop
2. Transmit from laptop, receive on your mobile app
3. Transmit from mobile app, receive on laptop
4. Should work seamlessly

---

## Troubleshooting

### "GGWave not initialized" Error
- This means the native module failed to load
- Check Metro logs for red errors
- Try: Stop app, run `npm install`, rebuild

### "Failed to encode text" Error
- Text might be too long (limit: 140 characters)
- Protocol might not support the payload size
- Try shorter text or different protocol

### No Sound Playing
- Check device volume (must be > 0)
- Check silent mode switch (iOS)
- Verify app has audio permissions
- Try restarting the app

### Not Receiving Messages
- Verify microphone permissions granted
- Check "Start Listening" is enabled (green indicator)
- Ensure transmitter volume is sufficient
- Try moving devices closer together
- Check for background noise interference

### Build Errors: "ggwave.h not found"
**iOS:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

**Android:**
```bash
cd android
./gradlew clean
cd ..
npm run android
```

### Metro Bundler Errors
```bash
# Clear Metro cache
npm start -- --reset-cache

# Or manually:
rm -rf node_modules/.cache
```

---

## Expected Performance

### Transmission Times (Audible Fast protocol)
- 10 characters: ~1 second
- 50 characters: ~3 seconds
- 140 characters: ~7 seconds

### Range
- Indoors, quiet: up to 5 meters
- Outdoors: up to 10 meters
- Noisy environment: 1-2 meters

### Reliability
- **Audible Normal**: 95%+ success rate
- **Audible Fast**: 90%+ success rate
- **Audible Fastest**: 80%+ success rate
- **Ultrasound**: 85%+ (depends on device speaker quality)

---

## Quick Command Reference

```bash
# iOS
cd ios && pod install && cd ..
npm run ios

# Android
npm run android

# Clean everything
rm -rf ios/Pods ios/build android/app/build android/.gradle
npm install
cd ios && pod install && cd ..

# Check logs
# iOS: Xcode > Window > Devices and Simulators > Open Console
# Android: adb logcat | grep -E "GGWave|AudioManager|ggwave"
```

---

## Success Checklist

Before reporting issues, verify:
- [ ] Physical device connected (not simulator/emulator)
- [ ] Microphone permission granted
- [ ] Device volume > 50%
- [ ] App built successfully without errors
- [ ] Metro bundler running
- [ ] "Initialized" message appears (not "Initializing...")
- [ ] Can hear sound when transmitting (audible modes)
- [ ] Green indicator when listening

---

## Next Steps After Successful Build

1. **Optimize protocols** for your use case
2. **Add error handling** for network unreliability
3. **Implement history** persistence (AsyncStorage)
4. **Add QR code** as fallback transmission method
5. **Implement encryption** for secure transmission
6. **Add file transmission** support (base64 encode)

---

## Support

If you encounter issues:
1. Check Metro logs for JavaScript errors
2. Check native logs (Xcode Console / adb logcat)
3. Verify ggwave C++ files are in `modules/expo-ggwave/cpp/`
4. Ensure all permissions are granted
5. Try on different devices to isolate hardware issues
