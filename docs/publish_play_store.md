## Publishing to Play Store

Referencing the following the following: https://docs.flutter.dev/deployment/android

#### Sign the App
- To publish on the Play Store, you must sign your app with a digital certificate.
- Android uses two signing keys: upload and app signing.
  - Developers upload an `.aab` or `.apk` file signed with an upload key to the Play Store.
  - The end-users download the `.apk` file signed with an app signing key.

Process:
1. Run the following command locally to generate an upload keystore
```
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
        -storetype JKS -keysize 2048 -validity 10000 -alias upload
```

This creates a `.jks` file which is stored locally BUT NOT pushed to Git 

2. Create the file `shelfd/android/key.properties` and populate with correct information. Again DO NOT push to Git (ensure with `.gitignore`)
```
storePassword=<password-from-previous-step>
keyPassword=<password-from-previous-step>
keyAlias=upload
storeFile=<keystore-file-location>
```

3. Add reference to key.properties in `shelfd/android/app/build.gradle.kts`

---

#### Build th App

4. Run build of app
```
flutter build appbundle
```

Successful build `✓ Built build/app/outputs/bundle/release/app-release.aab (78.7MB)`

5. Create Developer Google Play account

6. "Create App" in Google Play Console 

7. Finish setting up app (Privacy Policy), sign-in details, Ads, Data safety etc)

8. Internal testing, Closed testing

9. Apply for access to Production (available to public)

