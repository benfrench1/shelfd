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
