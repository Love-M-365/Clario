/// Represents the data structure for a user in the Clario app.
class ClarioUser {
  final String uid;
  final String name;
  final int age;
  final String? selectedAvatarId; // You might keep this for other purposes
  final Map<String, String>?
      avatarUrls; // Stores {'happy': 'url', 'sad': 'url', ...}

  ClarioUser({
    required this.uid,
    required this.name,
    required this.age,
    this.selectedAvatarId,
    this.avatarUrls, // Make sure this is included
  });

  /// Creates a [ClarioUser] instance from a map (e.g., data from Firebase).
  factory ClarioUser.fromMap(String uid, Map<String, dynamic> map) {
    return ClarioUser(
      uid: uid,
      name: map['name'] as String? ?? 'No Name', // Handle potential nulls
      age: map['age'] as int? ?? 18, // Handle potential nulls
      selectedAvatarId: map['selectedAvatarId'] as String?,
      // Safely parse the avatarUrls map
      avatarUrls: map.containsKey('avatarUrls') && map['avatarUrls'] is Map
          ? Map<String, String>.from(map['avatarUrls'] as Map)
          : null, // Default to null if not present or not a map
    );
  }

  /// Converts this [ClarioUser] instance back into a map.
  /// Useful if you need to save the entire user object somewhere.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'selectedAvatarId': selectedAvatarId,
      'avatarUrls': avatarUrls,
    };
    // Note: uid is usually the document ID, so not typically stored inside the map itself.
  }
}
