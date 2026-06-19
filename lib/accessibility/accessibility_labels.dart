String avatarSemanticLabel({String? name, bool isCurrentUser = false}) {
  if (isCurrentUser) {
    return 'Your profile';
  }
  if (name != null && name.trim().isNotEmpty) {
    return '$name profile picture';
  }
  return 'Profile picture';
}

String bookSemanticLabel({
  required String title,
  required String author,
  int? year,
  double? rating,
  bool isFavourite = false,
}) {
  final parts = <String>['$title by $author'];
  if (year != null && year > 0) {
    parts.add('Published in $year');
  }
  if (rating != null) {
    final ratingText = rating % 1 == 0
        ? rating.toInt().toString()
        : rating.toStringAsFixed(1);
    parts.add('Rated $ratingText out of 10');
  }
  if (isFavourite) {
    parts.add('Marked as favourite');
  }
  return parts.join('. ');
}

String emojiSemanticLabel(String emoji) {
  switch (emoji) {
    case '❤️':
      return 'heart';
    case '🔥':
      return 'fire';
    case '😂':
      return 'laughing';
    case '🥹':
      return 'teary smile';
    case '🤙':
      return 'call me hand';
    case '🫶':
      return 'heart hands';
    case '👥':
      return 'friends';
    case '🔒':
      return 'private';
    case '🌐':
      return 'public';
    default:
      return 'emoji $emoji';
  }
}