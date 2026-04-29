/// A single achievement definition.
typedef Achievement = ({int threshold, String label, String emoji});

/// All achievements in threshold order.
/// threshold == 0 means always unlocked (awarded on account creation / first login).
const List<Achievement> kAchievements = [
  (threshold: 0,    label: 'Joined Shelfd!',                                                          emoji: '🎉'),
  (threshold: 1,    label: '1st Book Completed',                                                      emoji: '📖'),
  (threshold: 5,    label: '5th Book Completed',                                                      emoji: '📚'),
  (threshold: 10,   label: '10th Book Completed',                                                     emoji: '🔟'),
  (threshold: 13,   label: '13th Book Completed.\nNot always unlucky :)',                             emoji: '🍀'),
  (threshold: 20,   label: '20th Book Completed',                                                     emoji: '🌟'),
  (threshold: 30,   label: '30th Book Completed',                                                     emoji: '🥉'),
  (threshold: 40,   label: '40th Book Completed',                                                     emoji: '🥈'),
  (threshold: 50,   label: '50th Book Completed',                                                     emoji: '🥇'),
  (threshold: 100,  label: '100th Book Completed',                                                    emoji: '💯'),
  (threshold: 150,  label: '150th Book Completed',                                                    emoji: '🏅'),
  (threshold: 200,  label: '200th Book Completed',                                                    emoji: '🎖️'),
  (threshold: 250,  label: '250th Book Completed',                                                    emoji: '🏆'),
  (threshold: 500,  label: '500th Book Completed',                                                    emoji: '⭐'),
  (threshold: 1000, label: '1000th Books Completed.\nYou achieved it all!\nYou are a LEGEND!',        emoji: '👑'),
];
