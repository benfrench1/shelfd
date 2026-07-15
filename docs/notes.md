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

#### Note on configuring a static web page for outlining the Deletion of accounts

As part of the Google Play checklist of requirements if an app captures personal information a user must have the ability to delete this themselves or request its deletion. This information is hosted as a static web page leveraging **Firebase Hosting**

Followed steps in UI and the following was added to the `firebase.json` file

```
  "hosting": {
    "public": "docs/public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ]
  }
```

Added the `user_account_data_deletion_request.html` file to host this information

Running the following command `firebase deploy --only hosting` is a one-time command. Once you run it, Firebase Hosting serves the page permanently — 24/7, for free — without you needing to do anything else or keep a terminal running.

Firebase Hosting is Google's CDN-backed static hosting service. Your page stays live until you explicitly take it down or redeploy. It's not like a local server that needs to stay running.

The only time you'd run the command again is if you update the HTML file and want to publish the changes.

Hosting URL: https://shelfd-41c13.web.app/user_account_data_deletion_request.html

#### Note on Google Sign in issue with initial Closed Testig release

- Google Sign-In only works if Firebase knows about the certificate that signed the app. Testing up until the closed release were using the registered the debug SHA-1. 

```
Protect with Play → Play Store Protection → Protect app signing key → Manage Play app signing → App signing key certificate → SHA-1 certificate fingerprint
```

This SHA-1 was added to the `FireBase Project Settings → SHA certificate fingerprints (add fingerprint)`

- Google authentication handshake now succeeds
