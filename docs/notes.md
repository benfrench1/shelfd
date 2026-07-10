## First Experiment Notes (Flutter)
- Installed via brew `brew install --cask flutter`
- First command ran this to create basic files:

```
flutter create --platforms=ios,android first_app
```

- Execute the following to run the app locally. `first_app/lib/main.dart`

```
cd first_app/lib
flutter run
```

---

#### Mobile data usage

When testing previosuly it was found that the book covers would not load and present a `TLS_HandshakeError`. The apps functionality was uneffected but the error in not loading the bok cover caused issues with the screens structure. This was addressed with a placeholder book cover icon to use in the event the book cover cannot be reached (mobile data or no internet/wifi).
The most common cause on mobile data is carrier-level SSL inspection.

#### Note on loading of data for user experience

The Reading Log and Future Reads screen present a scrollable screen. 

<ins>How data is loaded:</ins>

Both screens call a single Firestore .get() with no .limit() — all documents are fetched in one go when the screen opens. There is no pagination.

<ins>How items are rendered:</ins>

Both use ListView.builder, which is lazy — it only builds the widgets currently visible on screen, regardless of how many items are in the list. Scrolling through 200 items is just as smooth as scrolling through 20.

- The current implementation is perfectly appropriate for a personal reading app. Pagination would only be a consideration if users logged thousands of books (very unlikely).

