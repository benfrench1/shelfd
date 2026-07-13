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



Run the Build Command: You run a release build command in your terminal (such as flutter build appbundle for Flutter, or ./gradlew bundleRelease for a native Android app).

Automatic Signing: Gradle compiles your code, packages it, and automatically signs it using the keystore specified in your properties file.

Retrieve the Package: Your signed .aab file will be generated and placed in your build output directory (typically build/app/outputs/bundle/release/). This is the file you will upload to the Google Play Console.
