First Experiment Notes (Flutter)
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

### Firebase

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


#### Firebase Costs (Spark)

Firestore Spark (free) plan limits:

| Resource | Free allowance | Friend request impact |
|---|---|---|
| Storage | 1 GiB | Negligible — thousands of users wouldn't dent this |
| Document reads | 50,000/day | Moderate — see below |
| Document writes | 20,000/day | Very low — only on send/accept/decline |
| Document deletes | 10,000/day | Very low — only on cancel/unfriend |

Note on _if_ limits were reached:
"The way the Spark plan operates is that if your project exceeds the no-cost quota limit in a calendar month for any specific product (like Firestore reads), your project's usage of that particular product will be shut off for the remainder of that month."

#### Firebase Storage

- If enabling the ability for users to upload a profile picture (gallery or camera in the moment) the Storage feature would need to be used which by default doesnt come with the Spark (no-cost) plan.
- Would need the Pay as you go plan with the following details:
    - No-cost up to 5 GB
    - Then $0.10/GB
- For now will use a set of predefined default images whcih can be stored in `assests`.


### Mobile data usage

When testing previosuly it was found that the book covers would not load and present a `TLS_HandshakeError`. The apps functionality was uneffected but the error in not loading the bok cover caused issues with the screens structure. This was addressed with a placeholder book cover icon to use in the event the book cover cannot be reached (mobile data or no internet/wifi).
The most common cause on mobile data is carrier-level SSL inspection.
