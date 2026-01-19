#!/bin/bash

# DDWave Setup Verification Script
# Run this before building to ensure everything is configured correctly

echo "🔍 DDWave Setup Verification"
echo "================================"
echo ""

ERRORS=0
WARNINGS=0

# Check Node.js
echo "📦 Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo "   ✅ Node.js installed: $NODE_VERSION"
else
    echo "   ❌ Node.js not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check npm packages
echo "📦 Checking npm dependencies..."
if [ -d "node_modules" ]; then
    echo "   ✅ node_modules exists"
    if [ -d "node_modules/@ddwave/expo-ggwave" ]; then
        echo "   ✅ expo-ggwave module linked"
    else
        echo "   ❌ expo-ggwave module not found in node_modules"
        echo "      Run: npm install"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ node_modules not found"
    echo "      Run: npm install"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check ggwave C++ sources
echo "📦 Checking ggwave C++ sources..."
if [ -f "modules/expo-ggwave/cpp/ggwave.cpp" ]; then
    echo "   ✅ ggwave.cpp found"
else
    echo "   ❌ ggwave.cpp missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -d "modules/expo-ggwave/cpp/reed-solomon" ]; then
    echo "   ✅ reed-solomon directory found"
else
    echo "   ❌ reed-solomon directory missing"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check iOS setup
echo "🍎 Checking iOS setup..."
if [ -d "ios" ]; then
    echo "   ✅ ios/ directory exists"

    if command -v pod &> /dev/null; then
        POD_VERSION=$(pod --version)
        echo "   ✅ CocoaPods installed: $POD_VERSION"
    else
        echo "   ⚠️  CocoaPods not found"
        echo "      Install: sudo gem install cocoapods"
        WARNINGS=$((WARNINGS + 1))
    fi

    if [ -f "modules/expo-ggwave/ios/ExpoGGWave.podspec" ]; then
        echo "   ✅ ExpoGGWave.podspec found"
    else
        echo "   ❌ ExpoGGWave.podspec missing"
        ERRORS=$((ERRORS + 1))
    fi

    if [ -d "ios/Pods" ]; then
        echo "   ✅ Pods installed"
    else
        echo "   ⚠️  Pods not installed yet"
        echo "      Run: cd ios && pod install && cd .."
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ❌ ios/ directory not found"
    echo "      Run: npx expo prebuild --clean"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check Android setup
echo "🤖 Checking Android setup..."
if [ -d "android" ]; then
    echo "   ✅ android/ directory exists"

    if [ -n "$ANDROID_HOME" ]; then
        echo "   ✅ ANDROID_HOME set: $ANDROID_HOME"

        if [ -d "$ANDROID_HOME/ndk" ]; then
            NDK_VERSION=$(ls "$ANDROID_HOME/ndk" | head -1)
            echo "   ✅ NDK found: $NDK_VERSION"
        else
            echo "   ⚠️  NDK not found"
            echo "      Install via Android Studio SDK Manager"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo "   ⚠️  ANDROID_HOME not set"
        echo "      Set in ~/.zshrc or ~/.bash_profile"
        WARNINGS=$((WARNINGS + 1))
    fi

    if [ -f "modules/expo-ggwave/android/CMakeLists.txt" ]; then
        echo "   ✅ CMakeLists.txt found"
    else
        echo "   ❌ CMakeLists.txt missing"
        ERRORS=$((ERRORS + 1))
    fi

    if [ -f "modules/expo-ggwave/android/build.gradle" ]; then
        echo "   ✅ build.gradle found"
    else
        echo "   ❌ build.gradle missing"
        ERRORS=$((ERRORS + 1))
    fi

    if [ -f "modules/expo-ggwave/android/src/main/AndroidManifest.xml" ]; then
        echo "   ✅ AndroidManifest.xml found"
    else
        echo "   ❌ AndroidManifest.xml missing"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ android/ directory not found"
    echo "      Run: npx expo prebuild --clean"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check module files
echo "📱 Checking module files..."
if [ -f "modules/expo-ggwave/src/index.ts" ]; then
    echo "   ✅ index.ts found"
else
    echo "   ❌ index.ts missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "modules/expo-ggwave/src/useGGWave.ts" ]; then
    echo "   ✅ useGGWave.ts found"
else
    echo "   ❌ useGGWave.ts missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "modules/expo-ggwave/expo-module.config.json" ]; then
    echo "   ✅ expo-module.config.json found"
else
    echo "   ❌ expo-module.config.json missing"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check app files
echo "📱 Checking app files..."
if [ -f "app/(tabs)/index.tsx" ]; then
    echo "   ✅ Transmit screen found"
else
    echo "   ❌ Transmit screen missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "app/(tabs)/receive.tsx" ]; then
    echo "   ✅ Receive screen found"
else
    echo "   ❌ Receive screen missing"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Summary
echo "================================"
echo "📊 Summary"
echo "================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed! Ready to build."
    echo ""
    echo "Next steps:"
    echo "  iOS:     npm run ios"
    echo "  Android: npm run android"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  $WARNINGS warning(s) found, but you can proceed."
    echo ""
    echo "Next steps:"
    echo "  iOS:     cd ios && pod install && cd .. && npm run ios"
    echo "  Android: npm run android"
    exit 0
else
    echo "❌ $ERRORS error(s) found. Please fix before building."
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  $WARNINGS warning(s) found."
    fi
    echo ""
    echo "See BUILD_RECIPE.md for detailed instructions."
    exit 1
fi
