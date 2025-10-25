// lib/models/journal_entry.dart

class JournalEntry {
  final String id; // Unique ID from Firebase
  final String text;
  final DateTime timestamp;
  final double moodScore;
  final String moodTag;

  JournalEntry({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.moodScore,
    required this.moodTag,
  });

  // Factory constructor to create a JournalEntry from a Map
  factory JournalEntry.fromMap(String id, Map<String, dynamic> data) {
    return JournalEntry(
      id: id,
      text: data['text'] ?? '',
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
      moodScore: (data['moodScore'] as num?)?.toDouble() ?? 0.0,
      moodTag: data['moodTag'] ?? 'Neutral',
    );
  }
}
