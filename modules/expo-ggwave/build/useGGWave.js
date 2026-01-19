import { useState, useEffect, useCallback } from 'react';
import GGWave from './index';
import { requireNativeModule, EventEmitter } from 'expo-modules-core';
const ExpoGGWaveModule = requireNativeModule('ExpoGGWave');
const emitter = new EventEmitter(ExpoGGWaveModule);
export function useGGWave(config) {
    const [isInitialized, setIsInitialized] = useState(false);
    const [isListening, setIsListening] = useState(false);
    const [receivedMessages, setReceivedMessages] = useState([]);
    const [audioLevel, setAudioLevel] = useState({ rms: 0, peak: 0 });
    const [subscription, setSubscription] = useState(null);
    const [audioLevelSubscription, setAudioLevelSubscription] = useState(null);
    useEffect(() => {
        GGWave.initialize(config).then(() => setIsInitialized(true));
    }, []);
    const transmit = useCallback(async (text, protocol, volume) => {
        await GGWave.transmit(text, protocol, volume);
    }, []);
    const startListening = useCallback(async () => {
        const sub = await GGWave.startListening((text) => {
            setReceivedMessages(prev => [...prev, { text, timestamp: Date.now() }]);
        });
        setSubscription(sub);
        // Subscribe to audio level events for visualization
        const audioSub = emitter.addListener('onAudioLevel', (event) => {
            setAudioLevel({ rms: event.rms, peak: event.peak });
        });
        setAudioLevelSubscription(audioSub);
        setIsListening(true);
    }, []);
    const stopListening = useCallback(async () => {
        if (subscription) {
            subscription.remove();
            setSubscription(null);
        }
        if (audioLevelSubscription) {
            audioLevelSubscription.remove();
            setAudioLevelSubscription(null);
        }
        await GGWave.stopListening();
        setIsListening(false);
        setAudioLevel({ rms: 0, peak: 0 });
    }, [subscription, audioLevelSubscription]);
    const clearMessages = useCallback(() => {
        setReceivedMessages([]);
    }, []);
    return {
        isInitialized,
        isListening,
        receivedMessages,
        audioLevel,
        transmit,
        startListening,
        stopListening,
        clearMessages,
    };
}
//# sourceMappingURL=useGGWave.js.map