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

### Firebase Database (Firestore)

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

