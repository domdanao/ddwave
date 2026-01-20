# GGWave Decode Debugging Plan

## Current Status
- ✅ Audio capture works (WAV files decode successfully in Waver)
- ✅ Audio callbacks flowing with good levels
- ❌ No start/end markers ever detected
- ❌ No messages decoded in real-time
- ❌ `rxReceiving()` and `rxAnalyzing()` always return false

## Root Cause Hypothesis
The audio is captured correctly, but ggwave's `decode()` function isn't detecting the protocol markers. This suggests:
1. **Sample rate mismatch** between transmitter and receiver
2. **Audio format issue** in how we pass samples to ggwave
3. **Missing ggwave initialization** step
4. **Protocol mismatch** between transmitter and receiver

---

## Phase 1: Enhanced Diagnostics (DO THIS FIRST)

### Step 1.1: Run the App with New Logging
The code now has enhanced logging. Run the app and:

1. **Start listening** in ddwave
2. **Transmit from Waver** (use "test" with AUDIBLE_NORMAL protocol - the slowest, most robust)
3. **Watch the Xcode console** for these logs:

Look for:
```
🔍 DECODE STATUS #50: decode=OK, rxReceiving=no, rxAnalyzing=no, samples=4096, rms=0.XXXXXX
```

**Expected outcome:**
- `decode=OK` means decode() is working
- `rxReceiving=YES` should appear when Waver starts transmitting
- RMS should spike during transmission

**If rxReceiving NEVER becomes YES:** This means ggwave isn't detecting the protocol header at all.

---

## Phase 2: Protocol Verification

### Step 2.1: Verify Waver Settings
In Waver app:
- Protocol: **AUDIBLE_NORMAL** (most robust, slowest)
- Volume: **Maximum**
- Message: **"test"** (short and simple)

### Step 2.2: Try Different Protocols
Test each protocol systematically:
1. AUDIBLE_NORMAL (1-2 kHz, slowest)
2. AUDIBLE_FAST
3. AUDIBLE_FASTEST

Note which (if any) shows `rxReceiving=YES` in logs.

---

## Phase 3: Sample Rate Investigation

### Step 3.1: Check Device Sample Rate
Look for this log at app start:
```
[ExpoGGWaveModule] Device actual sample rate: XXXXX Hz
```

Common rates:
- iPhone: Usually **48000 Hz**
- iPad: Usually **48000 Hz**
- Older devices: Sometimes **44100 Hz**

### Step 3.2: Verify GGWave Configuration
Look for:
```
[GGWave] Creating ggwave instance with:
[GGWave]   - sampleRateInp: XXXXX Hz (device rate - will be resampled internally)
```

These should match!

---

## Phase 4: Audio Quality Check During Transmission

### Step 4.1: Record During Transmission
1. Start listening
2. Start Waver transmission
3. **Immediately save audio** (while still transmitting or just after)
4. Play back the recording - does it sound like Waver?

### Step 4.2: Check RMS Levels
During transmission, RMS should be > 0.001 (preferably > 0.01).
If RMS is too low, increase Waver volume or move devices closer.

---

## Phase 5: Loopback Test (CRITICAL)

This tests if ddwave's TX -> RX path works at all.

### Setup:
- Device A: ddwave (transmit tab)
- Device B: ddwave (receive tab)
- Place devices 6-12 inches apart

### Test:
1. Device B: Start listening
2. Device A: Transmit "hello" with AUDIBLE_NORMAL
3. Check Device B logs for `📡 START MARKER DETECTED`

**If this works:** Problem is with Waver compatibility
**If this fails:** Problem is in our ggwave setup

---

## Phase 6: Deep Inspection

If all above fails, we need to check the C++ integration.

### Step 6.1: Verify Operating Mode
Check logs for:
```
[GGWave]   - operatingMode: RX_AND_TX
```

If this says anything else, that's the problem!

### Step 6.2: Check Samples Per Frame
```
[GGWave]   samplesPerFrame: 1024
```

This is ggwave's internal buffer size. Should be 1024.

### Step 6.3: Verify We're Not In TX Mode
After starting listening, ggwave should be in RX mode.
If `decode()` returns false, it might think we're transmitting.

---

## Phase 7: Compare with Working Implementation

### Find ggwave-objc
1. Search GitHub for "ggwave-objc" or "ggwave ios"
2. Find the example receiver code
3. Compare our `decodeAudio` with theirs line-by-line

Key things to check:
- How they call `decode()`
- How they check for markers
- How they extract decoded data
- Buffer handling

---

## What to Report Back

After Phase 1 (Enhanced Diagnostics), report:

1. **Sample rate:** What Hz is your device using?
2. **Decode status logs:** Copy/paste the `🔍 DECODE STATUS` lines
3. **During transmission:** Does `rxReceiving` EVER become YES?
4. **RMS values:** What are they during transmission vs silence?
5. **Any errors:** Especially "decode() returned false"

This will tell us exactly where the problem is!

---

## Emergency Workaround

If nothing works, we can implement a **post-processing decode** approach:
1. Record audio continuously
2. Every 5 seconds, try to decode the entire buffer
3. This is how some ggwave examples work

But let's try to fix real-time decode first!
