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

### Firebase Storage

- If enabling the ability for users to upload a profile picture (gallery or camera in the moment) the Storage feature would need to be used which by default doesnt come with the Spark (no-cost) plan.
- Would need the Pay as you go plan with the following details:
    - No-cost up to 5 GB
    - Then $0.10/GB
- For now will use a set of predefined default images whcih can be stored in `assests`
