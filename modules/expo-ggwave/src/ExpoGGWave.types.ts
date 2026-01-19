export enum GGWaveProtocol {
  AUDIBLE_NORMAL = 0,
  AUDIBLE_FAST = 1,
  AUDIBLE_FASTEST = 2,
  ULTRASOUND_NORMAL = 3,
  ULTRASOUND_FAST = 4,
  ULTRASOUND_FASTEST = 5,
}

export interface GGWaveConfig {
  sampleRate?: number; // Default: 48000
  protocol?: GGWaveProtocol;
  volume?: number; // 0-100, default: 50
}

export interface GGWaveDataReceivedEvent {
  text: string;
}

export interface GGWaveAudioLevelEvent {
  rms: number;  // Root mean square (average volume)
  peak: number; // Peak volume
}

export interface ExpoGGWaveModuleEvents {
  onDataReceived(event: GGWaveDataReceivedEvent): void;
  onAudioLevel(event: GGWaveAudioLevelEvent): void;
}
