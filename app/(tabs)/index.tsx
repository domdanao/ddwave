import { useState, useEffect } from 'react';
import { StyleSheet, TextInput, ScrollView, Alert, ActivityIndicator } from 'react-native';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { Colors } from '@/constants/theme';
import { useGGWave, GGWaveProtocol } from '@ddwave/expo-ggwave';

export default function TransmitScreen() {
  const colorScheme = useColorScheme();
  const { isInitialized, transmit } = useGGWave({ sampleRate: 48000 });

  const [text, setText] = useState('');
  const [protocol, setProtocol] = useState<GGWaveProtocol>(GGWaveProtocol.AUDIBLE_FAST);
  const [volume, setVolume] = useState(50);
  const [isTransmitting, setIsTransmitting] = useState(false);

  const protocols = [
    { id: GGWaveProtocol.AUDIBLE_NORMAL, name: 'Audible Normal', description: 'Slowest, most reliable' },
    { id: GGWaveProtocol.AUDIBLE_FAST, name: 'Audible Fast', description: 'Balanced speed and reliability' },
    { id: GGWaveProtocol.AUDIBLE_FASTEST, name: 'Audible Fastest', description: 'Fastest, less reliable' },
    { id: GGWaveProtocol.ULTRASOUND_NORMAL, name: 'Ultrasound Normal', description: 'Inaudible, slower' },
    { id: GGWaveProtocol.ULTRASOUND_FAST, name: 'Ultrasound Fast', description: 'Inaudible, balanced' },
    { id: GGWaveProtocol.ULTRASOUND_FASTEST, name: 'Ultrasound Fastest', description: 'Inaudible, fastest' },
  ];

  const handleTransmit = async () => {
    if (!text.trim()) {
      Alert.alert('Error', 'Please enter text to transmit');
      return;
    }

    if (!isInitialized) {
      Alert.alert('Error', 'GGWave not initialized');
      return;
    }

    try {
      setIsTransmitting(true);
      await transmit(text, protocol, volume);
      Alert.alert('Success', 'Message transmitted successfully');
    } catch (error) {
      Alert.alert('Error', `Failed to transmit: ${error}`);
    } finally {
      setIsTransmitting(false);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <ThemedView style={styles.content}>
        <ThemedView style={styles.section}>
          <ThemedText type="title" style={styles.title}>Transmit Data</ThemedText>
          <ThemedText style={styles.subtitle}>
            Send text via sound waves
          </ThemedText>
        </ThemedView>

        <ThemedView style={styles.section}>
          <ThemedText type="subtitle" style={styles.label}>Message</ThemedText>
          <TextInput
            style={[
              styles.input,
              {
                backgroundColor: colorScheme === 'dark' ? '#1a1a1a' : '#f5f5f5',
                color: colorScheme === 'dark' ? '#fff' : '#000',
                borderColor: colorScheme === 'dark' ? '#333' : '#ddd',
              }
            ]}
            placeholder="Enter text to transmit..."
            placeholderTextColor={colorScheme === 'dark' ? '#666' : '#999'}
            value={text}
            onChangeText={setText}
            multiline
            numberOfLines={4}
            maxLength={140}
          />
          <ThemedText style={styles.charCount}>
            {text.length}/140 characters
          </ThemedText>
        </ThemedView>

        <ThemedView style={styles.section}>
          <ThemedText type="subtitle" style={styles.label}>Protocol</ThemedText>
          <ThemedView style={styles.protocolContainer}>
            {protocols.map((p) => (
              <ThemedView
                key={p.id}
                style={[
                  styles.protocolButton,
                  {
                    backgroundColor: protocol === p.id
                      ? Colors[colorScheme ?? 'light'].tint
                      : (colorScheme === 'dark' ? '#1a1a1a' : '#f5f5f5'),
                    borderColor: protocol === p.id
                      ? Colors[colorScheme ?? 'light'].tint
                      : (colorScheme === 'dark' ? '#333' : '#ddd'),
                  }
                ]}
                onTouchEnd={() => setProtocol(p.id)}
              >
                <ThemedText
                  style={[
                    styles.protocolName,
                    { color: protocol === p.id ? '#fff' : undefined }
                  ]}
                >
                  {p.name}
                </ThemedText>
                <ThemedText
                  style={[
                    styles.protocolDesc,
                    { color: protocol === p.id ? '#fff' : '#666' }
                  ]}
                >
                  {p.description}
                </ThemedText>
              </ThemedView>
            ))}
          </ThemedView>
        </ThemedView>

        <ThemedView style={styles.section}>
          <ThemedText type="subtitle" style={styles.label}>Volume: {volume}%</ThemedText>
          <ThemedView style={styles.volumeContainer}>
            {[25, 50, 75, 100].map((v) => (
              <ThemedView
                key={v}
                style={[
                  styles.volumeButton,
                  {
                    backgroundColor: volume === v
                      ? Colors[colorScheme ?? 'light'].tint
                      : (colorScheme === 'dark' ? '#1a1a1a' : '#f5f5f5'),
                    borderColor: volume === v
                      ? Colors[colorScheme ?? 'light'].tint
                      : (colorScheme === 'dark' ? '#333' : '#ddd'),
                  }
                ]}
                onTouchEnd={() => setVolume(v)}
              >
                <ThemedText
                  style={{ color: volume === v ? '#fff' : undefined }}
                >
                  {v}%
                </ThemedText>
              </ThemedView>
            ))}
          </ThemedView>
        </ThemedView>

        <ThemedView
          style={[
            styles.transmitButton,
            {
              backgroundColor: isInitialized && !isTransmitting
                ? Colors[colorScheme ?? 'light'].tint
                : '#666',
            }
          ]}
          onTouchEnd={isInitialized && !isTransmitting ? handleTransmit : undefined}
        >
          {isTransmitting ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <ThemedText style={styles.transmitButtonText}>
              {isInitialized ? 'Transmit' : 'Initializing...'}
            </ThemedText>
          )}
        </ThemedView>
      </ThemedView>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: 20,
    paddingBottom: 40,
  },
  section: {
    marginBottom: 24,
  },
  title: {
    marginBottom: 8,
  },
  subtitle: {
    opacity: 0.7,
  },
  label: {
    marginBottom: 12,
  },
  input: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    minHeight: 100,
    textAlignVertical: 'top',
  },
  charCount: {
    marginTop: 8,
    fontSize: 12,
    opacity: 0.6,
    textAlign: 'right',
  },
  protocolContainer: {
    gap: 8,
  },
  protocolButton: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 16,
  },
  protocolName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  protocolDesc: {
    fontSize: 12,
  },
  volumeContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  volumeButton: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  transmitButton: {
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
    marginTop: 8,
  },
  transmitButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
});
