import { GGWaveProtocol, GGWaveConfig } from './index';
export interface ReceivedMessage {
    text: string;
    timestamp: number;
}
interface UseGGWaveConfig extends GGWaveConfig {
}
export declare function useGGWave(config?: UseGGWaveConfig): {
    isInitialized: boolean;
    isListening: boolean;
    receivedMessages: ReceivedMessage[];
    audioLevel: {
        rms: number;
        peak: number;
    };
    transmit: (text: string, protocol?: GGWaveProtocol, volume?: number) => Promise<void>;
    startListening: () => Promise<void>;
    stopListening: () => Promise<void>;
    clearMessages: () => void;
};
export {};
//# sourceMappingURL=useGGWave.d.ts.map