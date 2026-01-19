import { useEffect } from 'react';
import { StyleSheet, ScrollView, FlatList, Alert } from 'react-native';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { Colors } from '@/constants/theme';
import { useGGWave } from '@ddwave/expo-ggwave';

export default function ReceiveScreen() {
  const colorScheme = useColorScheme();
  const {
    isInitialized,
    isListening,
    receivedMessages,
    audioLevel,
    startListening,
    stopListening,
    clearMessages,
  } = useGGWave({ sampleRate: 48000 });

  const handleToggleListening = async () => {
    try {
      if (isListening) {
        await stopListening();
      } else {
        await startListening();
      }
    } catch (error) {
      Alert.alert('Error', `Failed to ${isListening ? 'stop' : 'start'} listening: ${error}`);
    }
  };

  const handleClearMessages = () => {
    Alert.alert(
      'Clear Messages',
      'Are you sure you want to clear all received messages?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Clear', style: 'destructive', onPress: clearMessages },
      ]
    );
  };

  const formatTimestamp = (timestamp: number) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString();
  };

  return (
    <ThemedView style={styles.container}>
      <ThemedView style={styles.header}>
        <ThemedView style={styles.titleContainer}>
          <ThemedText type="title">Receive Data</ThemedText>
          <ThemedView
            style={[
              styles.statusIndicator,
              { backgroundColor: isListening ? '#4CAF50' : '#666' }
            ]}
          />
        </ThemedView>
        <ThemedText style={styles.subtitle}>
          {isListening ? 'Listening for sound waves...' : 'Tap below to start listening'}
        </ThemedText>
      </ThemedView>

      <ThemedView style={styles.controls}>
        <ThemedView
          style={[
            styles.listenButton,
            {
              backgroundColor: isInitialized
                ? (isListening ? '#f44336' : Colors[colorScheme ?? 'light'].tint)
                : '#666',
            }
          ]}
          onTouchEnd={isInitialized ? handleToggleListening : undefined}
        >
          <ThemedText style={styles.listenButtonText}>
            {!isInitialized
              ? 'Initializing...'
              : isListening
              ? 'Stop Listening'
              : 'Start Listening'}
          </ThemedText>
        </ThemedView>

        {isListening && audioLevel && (
          <ThemedView style={[
            styles.audioLevelContainer,
            {
              backgroundColor: colorScheme === 'dark' ? '#1a1a1a' : '#f5f5f5',
              borderColor: colorScheme === 'dark' ? '#333' : '#ddd',
            }
          ]}>
            <ThemedText style={styles.audioLevelLabel}>Audio Level</ThemedText>
            <ThemedView style={styles.audioLevelBars}>
              {/* RMS (average) level */}
              <ThemedView style={styles.levelBarContainer}>
                <ThemedText style={styles.levelLabel}>AVG</ThemedText>
                <ThemedView style={[
                  styles.levelBarBackground,
                  { backgroundColor: colorScheme === 'dark' ? '#333' : '#e0e0e0' }
                ]}>
                  <ThemedView style={[
                    styles.levelBarFill,
                    {
                      width: `${Math.min(100, (audioLevel?.rms || 0) * 1000)}%`,
                      backgroundColor: (audioLevel?.rms || 0) > 0.01 ? '#4CAF50' : '#666',
                    }
                  ]} />
                </ThemedView>
              </ThemedView>
              {/* Peak level */}
              <ThemedView style={styles.levelBarContainer}>
                <ThemedText style={styles.levelLabel}>PEAK</ThemedText>
                <ThemedView style={[
                  styles.levelBarBackground,
                  { backgroundColor: colorScheme === 'dark' ? '#333' : '#e0e0e0' }
                ]}>
                  <ThemedView style={[
                    styles.levelBarFill,
                    {
                      width: `${Math.min(100, (audioLevel?.peak || 0) * 100)}%`,
                      backgroundColor: (audioLevel?.peak || 0) > 0.1 ? '#FF9800' : '#666',
                    }
                  ]} />
                </ThemedView>
              </ThemedView>
            </ThemedView>
            <ThemedText style={styles.audioLevelHint}>
              {(audioLevel?.rms || 0) < 0.001 ? '⚠️ No audio detected - check microphone' : '✓ Audio detected'}
            </ThemedText>
          </ThemedView>
        )}

        {receivedMessages.length > 0 && (
          <ThemedView
            style={[
              styles.clearButton,
              {
                backgroundColor: colorScheme === 'dark' ? '#1a1a1a' : '#f5f5f5',
                borderColor: colorScheme === 'dark' ? '#333' : '#ddd',
              }
            ]}
            onTouchEnd={handleClearMessages}
          >
            <ThemedText style={styles.clearButtonText}>
              Clear Messages
            </ThemedText>
          </ThemedView>
        )}
      </ThemedView>

      <ThemedView style={styles.messagesContainer}>
        <ThemedView style={styles.messagesHeader}>
          <ThemedText type="subtitle">
            Received Messages ({receivedMessages.length})
          </ThemedText>
        </ThemedView>

        {receivedMessages.length === 0 ? (
          <ThemedView style={styles.emptyState}>
            <ThemedText style={styles.emptyStateText}>
              No messages received yet
            </ThemedText>
            <ThemedText style={styles.emptyStateSubtext}>
              Start listening to receive data via sound waves
            </ThemedText>
          </ThemedView>
        ) : (
          <FlatList
            data={[...receivedMessages].reverse()}
            keyExtractor={(item) => item.timestamp.toString()}
            renderItem={({ item }) => (
              <ThemedView
                style={[
                  styles.messageCard,
                  {
                    backgroundColor: colorScheme === 'dark' ? '#1a1a1a' : '#f5f5f5',
                    borderColor: colorScheme === 'dark' ? '#333' : '#ddd',
                  }
                ]}
              >
                <ThemedView style={styles.messageHeader}>
                  <ThemedText style={styles.messageTime}>
                    {formatTimestamp(item.timestamp)}
                  </ThemedText>
                </ThemedView>
                <ThemedText style={styles.messageText}>
                  {item.text}
                </ThemedText>
              </ThemedView>
            )}
            contentContainerStyle={styles.messagesList}
            showsVerticalScrollIndicator={true}
          />
        )}
      </ThemedView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    padding: 20,
    paddingBottom: 16,
  },
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 8,
  },
  statusIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  subtitle: {
    opacity: 0.7,
  },
  controls: {
    paddingHorizontal: 20,
    gap: 12,
    marginBottom: 16,
  },
  listenButton: {
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
  },
  listenButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  clearButton: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  clearButtonText: {
    fontSize: 16,
    fontWeight: '500',
  },
  messagesContainer: {
    flex: 1,
    paddingHorizontal: 20,
  },
  messagesHeader: {
    marginBottom: 16,
  },
  messagesList: {
    paddingBottom: 20,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 60,
    gap: 8,
  },
  emptyStateText: {
    fontSize: 16,
    opacity: 0.7,
  },
  emptyStateSubtext: {
    fontSize: 14,
    opacity: 0.5,
    textAlign: 'center',
  },
  messageCard: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  messageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  messageTime: {
    fontSize: 12,
    opacity: 0.6,
  },
  messageText: {
    fontSize: 16,
    lineHeight: 24,
  },
  audioLevelContainer: {
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
    gap: 12,
  },
  audioLevelLabel: {
    fontSize: 14,
    fontWeight: '600',
    opacity: 0.8,
  },
  audioLevelBars: {
    gap: 12,
  },
  levelBarContainer: {
    gap: 8,
  },
  levelLabel: {
    fontSize: 12,
    opacity: 0.6,
    fontWeight: '600',
  },
  levelBarBackground: {
    height: 8,
    borderRadius: 4,
    overflow: 'hidden',
  },
  levelBarFill: {
    height: '100%',
    borderRadius: 4,
  },
  audioLevelHint: {
    fontSize: 12,
    opacity: 0.7,
    textAlign: 'center',
  },
});
