# Telegram X FOSS

An unofficial FOSS-friendly fork of Telegram X, an alternative Telegram client based on TDLib.

This work was impired by [Telegram FOSS](https://github.com/Telegram-FOSS-Team/Telegram-FOSS).

## Changes

* Removed all proprietary/privacy-unfriendly binary blobs
* Permanently disabled invasive device attestation checks like Play Integrity and reCAPTCHA
* Replaced Google Maps with OpenStreetMap (OSMDroid)
* Replaced FCM with Telegram X's native push service
* Replaced prebuilt JNI libraries with upstream source code built at compile time

## Build

Building Telegram X mainly requires Java 21, the Android SDK tools, and NDK r27d. Additionally, you will need to install the following dependencies:

```bash
apt-get install --update --assume-yes gperf build-essential cmake libssl-dev zlib1g-dev automake
```

Once everything is installed, run:

```bash
./scripts/setup.sh --skip-sdk-setup
./gradlew assembleLatestUniversalRelease
```

## Releases

You can download releases from either [F-Droid](https://f-droid.org/packages/org.thunderdog.challegram) or [GitHub](https://github.com/AmanoTeam/Telegram-X-FOSS/releases/latest).

Both are mostly the same, except that F-Droid releases are built using Clang and require Android 6+, while GitHub releases are built using [GCC](https://github.com/AmanoTeam/android-gcc-cross) and require Android 4+.

## Bugs

Please note that this project is not endorsed by the original Telegram X developers. If you are using this version, please avoid reporting bugs through their official channels.

If you want to report an upstream issue (i.e., you are certain that the bug is not caused by one of our changes), first install the official version from [Telegram X's releases](https://github.com/TGX-Android/Telegram-X/releases), verify that the issue still occurs there, and then follow the instructions [here](https://github.com/TGX-Android/Telegram-X/blob/main/README.md#contributions) for getting help.

Otherwise, feel free to open an issue in this repository.

