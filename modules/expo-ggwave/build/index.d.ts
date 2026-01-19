import { GGWaveProtocol, GGWaveConfig, GGWaveDataReceivedEvent } from './ExpoGGWave.types';
declare class GGWave {
    private initialized;
    private config;
    initialize(config?: GGWaveConfig): Promise<void>;
    transmit(text: string, protocol?: GGWaveProtocol, volume?: number): Promise<void>;
    startListening(callback: (text: string) => void): Promise<{
        remove: () => void;
    }>;
    stopListening(): Promise<void>;
}
declare const _default: GGWave;
export default _default;
export { GGWaveProtocol, GGWaveConfig, GGWaveDataReceivedEvent };
export * from './useGGWave';
//# sourceMappingURL=index.d.ts.map