## Security

#### Firebase Authentication
- Only authenticated users can access the app — unauthenticated users are routed to the login screen and cannot reach any data
- Email verification is required after registration; users who have not verified their email are signed out immediately and cannot proceed
- Re-authentication is enforced before sensitive operations — changing a password or deleting an account requires the user to confirm their current credentials first
- Google Sign-In is supported and handled via Firebase's OAuth flow; no Google credentials are handled or stored directly by the app

#### Firestore Security Rules
- All Firestore data is denied by default — only paths with an explicit rule can be accessed
- A user's data (reviews, wishlist, activity stream, profile) lives under `users/{userId}/...` and is only readable or writable if the authenticated user's uid matches that `userId` — no user can read or write another user's data
- Username entries are stored in a separate `usernames` collection; a user can only create a username that points to their own uid, updates are blocked entirely (preventing username hijacking), and only the owner can delete their own entry
- Friend requests are scoped so only the two parties involved (sender and recipient) can read, modify, or delete the request — no third party can view another user's requests
- Username format is validated at the Firestore rules level (server-side) in addition to client-side checks in the app code, ensuring the constraint cannot be bypassed by a malicious client

#### Privacy
- Profile privacy levels (Public, Friends Only, Private) are respected in the app before any data is fetched from Firestore, so other users' data is not retrieved unnecessarily
- Each user's theme preference is stored in device-local storage (SharedPreferences) keyed by uid, so theme data is never sent to or stored on a server
