import { useState, useEffect, useCallback } from 'react';
import GGWave, { GGWaveProtocol, GGWaveConfig } from './index';
import { requireNativeModule, EventEmitter } from 'expo-modules-core';
import { GGWaveAudioLevelEvent, GGWaveDataReceivedEvent } from './ExpoGGWave.types';

type GGWaveEventMap = {
  onDataReceived: (event: GGWaveDataReceivedEvent) => void;
  onAudioLevel: (event: GGWaveAudioLevelEvent) => void;
};

const ExpoGGWaveModule = requireNativeModule('ExpoGGWave');
const emitter = new EventEmitter<GGWaveEventMap>(ExpoGGWaveModule as any);

export interface ReceivedMessage {
  text: string;
  timestamp: number;
}

interface UseGGWaveConfig extends GGWaveConfig {
  // Additional hook-specific config can go here
}

export function useGGWave(config?: UseGGWaveConfig) {
  const [isInitialized, setIsInitialized] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [receivedMessages, setReceivedMessages] = useState<ReceivedMessage[]>([]);
  const [audioLevel, setAudioLevel] = useState({ rms: 0, peak: 0 });
  const [subscription, setSubscription] = useState<{ remove: () => void } | null>(null);
  const [audioLevelSubscription, setAudioLevelSubscription] = useState<{ remove: () => void } | null>(null);

  useEffect(() => {
    GGWave.initialize(config).then(() => setIsInitialized(true));
  }, []);

  const transmit = useCallback(async (
    text: string,
    protocol?: GGWaveProtocol,
    volume?: number
  ) => {
    await GGWave.transmit(text, protocol, volume);
  }, []);

  const startListening = useCallback(async () => {
    const sub = await GGWave.startListening((text) => {
      setReceivedMessages(prev => [...prev, { text, timestamp: Date.now() }]);
    });
    setSubscription(sub);

    // Subscribe to audio level events for visualization
    const audioSub = emitter.addListener('onAudioLevel', (event: GGWaveAudioLevelEvent) => {
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
