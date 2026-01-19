import { useState } from 'react';
import { StyleSheet, TextInput, ScrollView, Alert, ActivityIndicator, Keyboard, TouchableWithoutFeedback } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { Colors } from '@/constants/theme';
import { useGGWave, GGWaveProtocol } from '@ddwave/expo-ggwave';

export default function TransmitScreen() {
  const colorScheme = useColorScheme();
  const { isInitialized, transmit } = useGGWave({ sampleRate: 48000 });

  const [text, setText] = useState('Hello world');
  const [protocol, setProtocol] = useState<GGWaveProtocol>(GGWaveProtocol.AUDIBLE_FAST);
  const [volume, setVolume] = useState(50);
  const [isTransmitting, setIsTransmitting] = useState(false);

  const audibleProtocols = [
    { id: GGWaveProtocol.AUDIBLE_NORMAL, name: 'Normal' },
    { id: GGWaveProtocol.AUDIBLE_FAST, name: 'Fast' },
    { id: GGWaveProtocol.AUDIBLE_FASTEST, name: 'Fastest' },
  ];

  const ultrasoundProtocols = [
    { id: GGWaveProtocol.ULTRASOUND_NORMAL, name: 'Normal' },
    { id: GGWaveProtocol.ULTRASOUND_FAST, name: 'Fast' },
    { id: GGWaveProtocol.ULTRASOUND_FASTEST, name: 'Fastest' },
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
    <SafeAreaView style={[styles.safeArea, { backgroundColor: Colors[colorScheme ?? 'light'].background }]} edges={['top']}>
      <ScrollView style={styles.container} contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
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
                  backgroundColor: colorScheme === 'dark' ? '#1E1E1E' : '#f5f5f5',
                  color: colorScheme === 'dark' ? '#fff' : '#000',
                  borderColor: colorScheme === 'dark' ? '#444' : '#ddd',
                }
              ]}
              placeholder="Enter text to transmit..."
              placeholderTextColor={colorScheme === 'dark' ? '#888' : '#999'}
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
            <ThemedView style={styles.protocolColumnsContainer}>
              {/* Left column: Audible */}
              <ThemedView style={styles.protocolColumn}>
                <ThemedText style={styles.protocolColumnTitle}>Audible</ThemedText>
                {audibleProtocols.map((p) => (
                  <ThemedView
                    key={p.id}
                    style={[
                      styles.protocolButton,
                      {
                        backgroundColor: protocol === p.id
                          ? Colors[colorScheme ?? 'light'].tint
                          : (colorScheme === 'dark' ? '#1E1E1E' : '#f5f5f5'),
                        borderColor: protocol === p.id
                          ? Colors[colorScheme ?? 'light'].tint
                          : (colorScheme === 'dark' ? '#444' : '#ddd'),
                      }
                    ]}
                    onTouchEnd={() => setProtocol(p.id)}
                  >
                    <ThemedText
                      style={[
                        styles.protocolName,
                        { color: protocol === p.id ? '#fff' : (colorScheme === 'dark' ? '#FFFFFF' : '#11181C') }
                      ]}
                    >
                      {p.name}
                    </ThemedText>
                  </ThemedView>
                ))}
              </ThemedView>

              {/* Right column: Ultrasound */}
              <ThemedView style={styles.protocolColumn}>
                <ThemedText style={styles.protocolColumnTitle}>Ultrasound</ThemedText>
                {ultrasoundProtocols.map((p) => (
                  <ThemedView
                    key={p.id}
                    style={[
                      styles.protocolButton,
                      {
                        backgroundColor: protocol === p.id
                          ? Colors[colorScheme ?? 'light'].tint
                          : (colorScheme === 'dark' ? '#1E1E1E' : '#f5f5f5'),
                        borderColor: protocol === p.id
                          ? Colors[colorScheme ?? 'light'].tint
                          : (colorScheme === 'dark' ? '#444' : '#ddd'),
                      }
                    ]}
                    onTouchEnd={() => setProtocol(p.id)}
                  >
                    <ThemedText
                      style={[
                        styles.protocolName,
                        { color: protocol === p.id ? '#fff' : (colorScheme === 'dark' ? '#FFFFFF' : '#11181C') }
                      ]}
                    >
                      {p.name}
                    </ThemedText>
                  </ThemedView>
                ))}
              </ThemedView>
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
                        : (colorScheme === 'dark' ? '#1E1E1E' : '#f5f5f5'),
                      borderColor: volume === v
                        ? Colors[colorScheme ?? 'light'].tint
                        : (colorScheme === 'dark' ? '#444' : '#ddd'),
                    }
                  ]}
                  onTouchEnd={() => setVolume(v)}
                >
                  <ThemedText
                    style={{ color: volume === v ? '#fff' : (colorScheme === 'dark' ? '#FFFFFF' : '#11181C') }}
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
        </TouchableWithoutFeedback>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
  },
  container: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
  },
  content: {
    padding: 20,
    paddingTop: 8,
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
  protocolColumnsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  protocolColumn: {
    width: '48%',
    gap: 10,
  },
  protocolColumnTitle: {
    fontSize: 12,
    fontWeight: '600',
    opacity: 0.7,
    marginBottom: 6,
    textAlign: 'center',
  },
  protocolButton: {
    borderWidth: 1,
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 6,
    alignItems: 'center',
  },
  protocolName: {
    fontSize: 13,
    fontWeight: '600',
  },
  volumeContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  volumeButton: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 8,
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
