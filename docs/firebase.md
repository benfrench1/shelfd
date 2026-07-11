## FireBase

After research the best platforms to integrate and leverage for the application it was decided that Firebase would be the best approach. It is widely used and accepted, provides services such as database, authentication and analytics. All at a financially viable plan structure.

---

- Create a project `shelfd` (linked to Google account)
- Install Firebase CLI
- Activate packages (in any directory)
```
dart pub global activate flutterfire_cli
```


- Add path to `~/.zshrc`

```
Paste export PATH="$PATH":"$HOME/.pub-cache/bin"
```

- Then at root directory of app
```
flutterfire configure --project=shelfd-41c13
```

```
flutterfire configure
i Found 1 Firebase projects.
✔ Select a Firebase project to configure your Flutter application with · shelfd-41c13 (shelfd)
✔ Which platforms should your configuration support (use arrow keys & space to select)? · android, ios, macos, web
i Firebase android app com.example.first_app registered.
i Firebase ios app com.example.firstApp registered.
i Firebase macos app com.example.firstApp registered.
i Firebase web app first_app (web) registered.

Firebase configuration file lib/firebase_options.dart generated successfully with the following Firebase apps:

Platform  Firebase App Id
web       1:12345678987654321:web:xyzabc123
android   1:12345678987654321:android:xyzabc123
ios       1:12345678987654321:ios:xyzabc123
macos     1:12345678987654321:ios:xyzabc123

Learn more about using this file and next steps from the documentation:
 > https://firebase.google.com/docs/flutter/setup
```

---

### Firebase Authentication steps

1. Navigate to the Firebase console  and select your project and in the left-hand navigation, find and select "Authentication."

2. Add providers (i.e. Google, email etc)

3. Generate a SHA-1 Fingerprint locally and take the `SHA1` value. This can then be added to the project console
```
~ cd android && ./gradlew signingReport
Variant: debug
Config: debug
Store: /Users/benfrench/.android/debug.keystore
Alias: AndroidDebugKey
MD5:  XX:XX:...
SHA1: AA:BB:CC:DD:EE:FF:...   <-- this one
SHA-256: ...
```

---

### Firestore (Database)

- A database was created in Firestore
- Rules added in Firestore to ensure only authenticated users are granted access to data:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
- The `request.auth != null` condition ensures that only users who are signed in (authenticated) can attempt to access any data within this path. Unauthenticated users will be denied access to everything covered by these rules.
- The `request.auth.uid == userId` condition means that the unique ID of the currently authenticated user (request.auth.uid) must exactly match the userId segment in the document's path. This effectively "silos" each user's data, preventing one authenticated user from reading or writing to another user's userId path.
- The match `/users/{userId}/{document=**}` clause specifies that these rules apply to any document or subcollection located directly under a userId document within the users collection. The {document=**} is a wildcard that allows the rule to apply to any nested documents or collections under that userId path.

###### FireStore Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
---
Allows Users to modify their username
```
rules_version = '2;
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /usernames/{username} {
      allow create: if request.auth != null && request.resource.data.uid == request.auth.uid;
      allow read: if request.auth != null;
      allow delete: if request.auth != null && resource.data.uid == request.auth.uid;
      allow update: if false;
    }
  }
}
```
---
Enforces server-side format validation on username as well as client-side (in codebase)
```
rules_version = '2';
service cloud.firestore {
  function isValidUsername(username) {
    return username.size() > 0 && username.size() <= 30 && !username.matches("[/]");
  }
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /usernames/{username} {
      allow create: if request.auth != null && request.resource.data.uid == request.auth.uid && isValidUsername(username);
      allow read: if request.auth != null;
      allow delete: if request.auth != null && resource.data.uid == request.auth.uid;
      allow update: if false;
    }
  }
}
```

##### Breakdown of rule conditions:
- `/users/{userId}/...` (profiles, reviews, wishlist)
    - A user can only write their own data — request.auth.uid == userId blocks any attempt to edit another user's profile, reviews, or wishlist.
    - Any signed-in user can read another user's top-level profile doc (username, avatar, privacy level) — needed for search/friend profile display.
    Any signed-in user can read another user's reviews — but privacy level enforcement (public/friends-only/private) is applied in the app before any data is fetched

- `/usernames/{username}` (username index)
    - A user can only create a username entry that points to their own UID.
    - Update is blocked entirely (allow update: if false) — prevents anyone hijacking an existing username.
    - Only the owner can delete their own username entry

- `/friendRequests/{docId}`
    - Only the sender (fromUid) can create a request.
    - Only the recipient (toUid) can accept it (update).
    - Only the two parties involved can read a request — no third party can see your requests.
    - Either party can delete (cancel/decline/unfriend)

### Firebase Crashlytics Integration

Crashlyitcs integration ensures comprehensive crash reports are shipped and visibe in the Firebase console. Useful docs on setup: https://firebase.google.com/docs/crashlytics/flutter/get-started

- Firebase Crashlytics is a **completely no-cost** product with no charge to enable or use it (even with the Spark plan). 
- Can be used with millions of users without needing to upgrade the billing plan.
- Crashlytics does limit custom logging to 64kB per session.
  - In Firebase Crashlytics, custom logs are diagnostic text messages you write in your code to track the exact steps a user took leading up to a crash (for example, "User opened cart" or "Payment API returned 200").
  - A **session** starts when a user opens he app and ends when the app is either closed by the user or terminates due to a crash. All the custom logs generated during this single run are grouped together.
  - How much is 64kB? In terms of plain text, 64 kilobytes (kB) is roughly equivalent to 64,000 characters. For a typical app session, this is a very generous amount of space—allowing you to write thousands of log entries before hitting the limit.
  - If the 64kB limit is exceeded Crashlytics uses a rolling log buffer (First-In, First-Out). If your app generates more than 64kB of logs during a single session, the oldest log entries are deleted to make room for the newest ones.
- All core Crashlytics features (such as realtime crash reporting, tracking non-fatal errors, and receiving alerts) are fully available on the Spark plan. However, if you eventually want to export your raw crash data to BigQuery for advanced custom analysis, you would need to upgrade to the pay-as-you-go Blaze plan, as BigQuery is a paid Google Cloud service.

One time configuration and commands:
1. `flutter pub add firebase_crashlytics && flutter pub add firebase_analytics`
2. `flutterfire configure`
3. `flutter run`
4. Amend the `lib/main.dart` file as stated in the docs with the crashlytics error handlers

Integration with Crashlytics should now be completed successfully. Final steps are to add a dummy temporary button which when pressed will initiate an exception e.g.

```
TextButton(
    onPressed: () => throw Exception(),
    child: const Text("Throw Test Exception"),
),
```

Process to tet dummy button:
1. Run in release/profile mode e.g. `flutter run --release`
2. Tap the test button → app crashes
3. Reopen the app
4. Check the Firebase Console (can take a minute or two to appear)


---

#### Firebase Costs (Spark)

Firestore Spark (free) plan limits:

| Resource | Free allowance | Friend request impact |
|---|---|---|
| Storage | 1 GiB | Negligible — thousands of users wouldn't dent this |
| Document reads | 50,000/day | Moderate — see below |
| Document writes | 20,000/day | Very low — only on send/accept/decline |
| Document deletes | 20,000/day | Very low — only on cancel/unfriend |

> [!NOTE]
> _if_ limits were reached: "*The way the Spark plan operates is that if your project exceeds the no-cost quota limit in a calendar month for any specific product (like Firestore reads), your project's usage of that particular product will be shut off for the remainder of that month.*"

#### Firebase Storage

- If enabling the ability for users to upload a profile picture (gallery or camera in the moment) the Storage feature would need to be used which by default doesnt come with the Spark (no-cost) plan.
- Would need the Pay as you go plan with the following details:
    - No-cost up to 5 GB
    - Then $0.10/GB
- For now will use a set of predefined default images whcih can be stored in `assests`.


