## Accessibility

The app has been built and tested with accessibility for all considered.

- The app has been tested on iOS with VoiceOver in addition to Android TalkBack to verify cross-platform screen reader compatibility with suitable labelling of elements.
- Semantic labels have been applied to interactive elements (buttons, icons, avatars, book covers, emoji reactions) via a shared accessibility labels file, ensuring screen readers announce meaningful descriptions rather than raw asset names.
- Decorative images that carry no informational value are explicitly excluded from the accessibility tree so screen readers skip them and reduce noise for visually impaired users.
- Tooltips have been added to icon buttons throughout the app, providing an additional text hint surfaced by screen readers and long-press on Android/iOS.
- The app supports dynamic text scaling — icon sizes and UI elements scale in response to the device's display size setting, not just the font size setting, preventing truncation or clipping at larger scales.
- Scrollable bottom sheets and modal dialogs have been configured to expand and scroll when the system font/display scale is increased, preventing content from being cut off.
- Layout components have been updated to reflow rather than overflow when large text sizes are active; fixed-width rows have been replaced with flexible or wrapping alternatives across all major screens.
- The theme "High Contrast" was developed to ensure all elements of the screen are at a suitable contrast ratio.

