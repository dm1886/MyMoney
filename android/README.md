# MyMoney Android

Native Kotlin/Compose port. **Not yet feature-complete with iOS.** Exact scope and missing features: [parity ledger](../docs/ANDROID_PARITY.md).

Open this `android` directory in Android Studio. Use Android Studio's bundled JBR (Java 21), Android SDK 36 and an API 26+ emulator/device.

```sh
# From repository root on the development Mac:
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./android/gradlew -p android :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
# In another terminal, before opening the debug app:
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' firebase emulators:start --config firebase/firebase.json --project demo-mymoney --only auth,firestore
```

Debug builds connect to the emulators at `10.0.2.2`, use disposable accounts, and never connect to the production project. Verify the test email through the local Auth emulator verification link (printed by the emulator); the REST emulator OOB API can be used by automated tests. The first verified login creates a private profile. Financial libraries remain on the device, isolated by UID.

Firebase CLI is already installed and authenticated on the development Mac. Dedicated cloud project: `dm1886-mymoney`. To download public Android configuration:

```sh
firebase apps:sdkconfig ANDROID 1:997771518237:android:b1a9a871c9439b8f37c1f4 --project dm1886-mymoney --out android/app/google-services.json
python3 android/scripts/configure-firebase.py
```

Downloaded cloud configuration is git-ignored. The debug source set overrides it with emulator-only config. Do not distribute a release build yet: account deletion, privacy links, synchronization, full parity, release signing and real-device checks are incomplete.

The `assets/licenses` directory contains the Sora OFL license. Financial values use `BigDecimal` and are stored as exact decimal strings in an atomic app-private file, not floating point.
