import { requireNativeModule, EventEmitter } from 'expo-modules-core';
import { GGWaveProtocol } from './ExpoGGWave.types';
// Import the native module
const ExpoGGWaveModule = requireNativeModule('ExpoGGWave');
const emitter = new EventEmitter(ExpoGGWaveModule);
class GGWave {
    initialized = false;
    config = {
        sampleRate: 48000,
        protocol: GGWaveProtocol.AUDIBLE_FAST,
        volume: 50,
    };
    async initialize(config) {
        if (config) {
            this.config = { ...this.config, ...config };
        }
        await ExpoGGWaveModule.initialize(this.config.sampleRate);
        this.initialized = true;
    }
    async transmit(text, protocol, volume) {
        if (!this.initialized) {
            throw new Error('GGWave not initialized. Call initialize() first.');
        }
        const useProtocol = protocol ?? this.config.protocol;
        const useVolume = volume ?? this.config.volume;
        const waveform = await ExpoGGWaveModule.encode(text, useProtocol, useVolume);
        await ExpoGGWaveModule.playWaveform(waveform, this.config.sampleRate);
    }
    async startListening(callback) {
        console.log('[GGWave JS] startListening called');
        if (!this.initialized) {
            console.log('[GGWave JS] ERROR: Not initialized');
            throw new Error('GGWave not initialized. Call initialize() first.');
        }
        console.log('[GGWave JS] Setting up event listener...');
        const subscription = emitter.addListener('onDataReceived', (event) => {
            console.log('[GGWave JS] Received event:', event);
            callback(event.text);
        });
        console.log('[GGWave JS] Calling native startListening...');
        await ExpoGGWaveModule.startListening();
        console.log('[GGWave JS] Native startListening completed');
        return subscription;
    }
    async stopListening() {
        await ExpoGGWaveModule.stopListening();
    }
}
export default new GGWave();
export { GGWaveProtocol };
export * from './useGGWave';
//# sourceMappingURL=index.js.map