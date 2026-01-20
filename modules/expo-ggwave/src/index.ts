import { requireNativeModule, EventEmitter } from 'expo-modules-core';

import { GGWaveProtocol, GGWaveConfig, GGWaveDataReceivedEvent, GGWaveAudioLevelEvent } from './ExpoGGWave.types';

// Define the event map for our module
type GGWaveEventMap = {
  onDataReceived: (event: GGWaveDataReceivedEvent) => void;
  onAudioLevel: (event: GGWaveAudioLevelEvent) => void;
};

// Import the native module
const ExpoGGWaveModule = requireNativeModule('ExpoGGWave');

const emitter = new EventEmitter<GGWaveEventMap>(ExpoGGWaveModule as any);

class GGWave {
  private initialized = false;
  private config: Required<GGWaveConfig> = {
    sampleRate: 48000,
    protocol: GGWaveProtocol.AUDIBLE_FAST,
    volume: 50,
  };

  async initialize(config?: GGWaveConfig): Promise<void> {
    if (config) {
      this.config = { ...this.config, ...config };
    }

    await ExpoGGWaveModule.initialize(this.config.sampleRate);
    this.initialized = true;
  }

  async transmit(text: string, protocol?: GGWaveProtocol, volume?: number): Promise<void> {
    if (!this.initialized) {
      throw new Error('GGWave not initialized. Call initialize() first.');
    }

    const useProtocol = protocol ?? this.config.protocol;
    const useVolume = volume ?? this.config.volume;

    const waveform = await ExpoGGWaveModule.encode(text, useProtocol, useVolume);
    await ExpoGGWaveModule.playWaveform(waveform, this.config.sampleRate);
  }

  async startListening(callback: (text: string) => void): Promise<{ remove: () => void }> {
    console.log('[GGWave JS] startListening called');

    if (!this.initialized) {
      console.log('[GGWave JS] ERROR: Not initialized');
      throw new Error('GGWave not initialized. Call initialize() first.');
    }

    console.log('[GGWave JS] Setting up event listener...');
    const subscription = emitter.addListener(
      'onDataReceived',
      (event) => {
        console.log('🎉🎉🎉 [GGWave JS] DECODED DATA RECEIVED:', event);
        console.log('🎉🎉🎉 [GGWave JS] Message text:', event.text);
        callback(event.text);
      }
    );

    console.log('[GGWave JS] Calling native startListening...');
    await ExpoGGWaveModule.startListening();
    console.log('[GGWave JS] Native startListening completed');
    console.log('[GGWave JS] ✓ Listening for transmissions...');

    return subscription;
  }

  async stopListening(): Promise<void> {
    await ExpoGGWaveModule.stopListening();
  }
}

export default new GGWave();
export { GGWaveProtocol, GGWaveConfig, GGWaveDataReceivedEvent, GGWaveDecodeEvent } from './ExpoGGWave.types';
export * from './useGGWave';
