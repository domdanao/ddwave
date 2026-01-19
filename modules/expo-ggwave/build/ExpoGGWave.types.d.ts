export declare enum GGWaveProtocol {
    AUDIBLE_NORMAL = 0,
    AUDIBLE_FAST = 1,
    AUDIBLE_FASTEST = 2,
    ULTRASOUND_NORMAL = 3,
    ULTRASOUND_FAST = 4,
    ULTRASOUND_FASTEST = 5
}
export interface GGWaveConfig {
    sampleRate?: number;
    protocol?: GGWaveProtocol;
    volume?: number;
}
export interface GGWaveDataReceivedEvent {
    text: string;
}
export interface GGWaveAudioLevelEvent {
    rms: number;
    peak: number;
}
export interface ExpoGGWaveModuleEvents {
    onDataReceived(event: GGWaveDataReceivedEvent): void;
    onAudioLevel(event: GGWaveAudioLevelEvent): void;
}
//# sourceMappingURL=ExpoGGWave.types.d.ts.map