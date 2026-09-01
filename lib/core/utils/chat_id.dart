String generateChatId(String firstUserId, String secondUserId) {
  if (firstUserId.isEmpty || secondUserId.isEmpty) {
    throw ArgumentError('User IDs must not be empty.');
  }
  if (firstUserId == secondUserId) {
    throw ArgumentError('A chat requires two different users.');
  }

  return firstUserId.compareTo(secondUserId) < 0
      ? '${firstUserId}_$secondUserId'
      : '${secondUserId}_$firstUserId';
}
