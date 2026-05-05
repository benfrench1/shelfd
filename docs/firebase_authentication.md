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
- Rules added in Firestore to ensure only authenticated users are grnated access to data:
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

### Firebase Storage

- If enabling the ability for users to upload a profile picture (gallery or camera in the moment) the Storage feature would need to be used which by default doesnt come with the Spark (no-cost) plan.
- Would need the Pay as you go plan with the following details:
    - No-cost up to 5 GB
    - Then $0.10/GB
- For now will use a set of predefined default images whcih can be stored in `assests`





Before Friends:
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

After
```
rules_version = '2';
service cloud.firestore {
  function isValidUsername(username) {
    return username.size() > 0 && username.size() <= 30 && !username.matches("[/]");
  }
  match /databases/{database}/documents {

    // ── User data ──────────────────────────────────────────────────────────────
    // Full read/write access to own profile doc and all subcollections (reviews, wishlist, etc.)
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Any signed-in user can read another user's profile document
    // (avatar, username, privacyLevel, createdAt — does not grant subcollection access)
    match /users/{userId} {
      allow read: if request.auth != null;
    }

    // Any signed-in user can read another user's reviews
    // Privacy level (public / friends only / private) is enforced client-side
    match /users/{userId}/reviews/{reviewId} {
      allow read: if request.auth != null;
    }

    // ── Usernames index ────────────────────────────────────────────────────────
    match /usernames/{username} {
      allow create: if request.auth != null
                    && request.resource.data.uid == request.auth.uid
                    && isValidUsername(username);
      allow read:   if request.auth != null;
      allow delete: if request.auth != null && resource.data.uid == request.auth.uid;
      allow update: if false;
    }

    // ── Friend requests ────────────────────────────────────────────────────────
    match /friendRequests/{docId} {
      // Only the two parties involved can read a request
      allow read: if request.auth != null
                  && (resource.data.fromUid == request.auth.uid
                      || resource.data.toUid == request.auth.uid);
      // Only the sender can create a request
      allow create: if request.auth != null
                    && request.resource.data.fromUid == request.auth.uid;
      // Only the recipient can accept (update status to 'accepted')
      allow update: if request.auth != null
                    && resource.data.toUid == request.auth.uid;
      // Either party can cancel / decline / unfriend
      allow delete: if request.auth != null
                    && (resource.data.fromUid == request.auth.uid
                        || resource.data.toUid == request.auth.uid);
    }
  }
}
```
