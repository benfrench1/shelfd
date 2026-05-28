/// A single achievement definition.
/// [hidden] achievements are not shown on the profile screen until unlocked.
typedef Achievement = ({int threshold, String label, String emoji, bool hidden});

/// All achievements in threshold order.
/// threshold == 0 means always unlocked (awarded on account creation / first login).
const List<Achievement> kAchievements = [
  (threshold: 0,    label: 'Joined Shelfd!',                                                          emoji: '🎉', hidden: false),
  (threshold: 1,    label: '1st Book Completed',                                                      emoji: '📖', hidden: false),
  (threshold: 5,    label: '5th Book Completed',                                                      emoji: '📚', hidden: false),
  (threshold: 10,   label: '10th Book Completed',                                                     emoji: '🔟', hidden: false),
  (threshold: 13,   label: '13th Book Completed.\nNot always unlucky :)',                             emoji: '🍀', hidden: true),
  (threshold: 20,   label: '20th Book Completed',                                                     emoji: '🌟', hidden: false),
  (threshold: 30,   label: '30th Book Completed',                                                     emoji: '🥉', hidden: false),
  (threshold: 40,   label: '40th Book Completed',                                                     emoji: '🥈', hidden: false),
  (threshold: 50,   label: '50th Book Completed',                                                     emoji: '🥇', hidden: false),
  (threshold: 100,  label: '100th Book Completed',                                                    emoji: '💯', hidden: false),
  (threshold: 150,  label: '150th Book Completed',                                                    emoji: '🏅', hidden: false),
  (threshold: 200,  label: '200th Book Completed',                                                    emoji: '🎖️', hidden: false),
  (threshold: 250,  label: '250th Book Completed',                                                    emoji: '🏆', hidden: false),
  (threshold: 500,  label: '500th Book Completed',                                                    emoji: '⭐', hidden: false),
  (threshold: 1000, label: '1000 Books Completed.\nYou achieved it all!\nYou are a LEGEND!',        emoji: '👑', hidden: false),
];
