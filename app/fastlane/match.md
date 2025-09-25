# Matchfile for MNGA

The profile of this project is currently configured to be managed by [fastlane match](https://docs.fastlane.tools/actions/match/).

## Initial setup

Upon first use, run the following command to create or fetch the profiles.

```bash
# For development (debug build)
$ fastlane match development

# For distribution (release build), not necessary if we only want to release in CI
$ fastlane match appstore
```

This requires the user to

- enter the passphrase for the [profile repository](https://github.com/BugenZhao/MNGA-Profiles.git)
- enter the password (with 2FA) for the Apple Developer account

## Adding a new device

The development profile is only valid for specific devices, as specified in the Apple Developer Portal.

To add a new device, it seems that we have to open Xcode, select the new device as the destination, and follow the instructions to register the device. After that, run

```bash
$ fastlane match development
```

again to update the profile. Some options for `fastlane match` may also worth trying, e.g. `--force`, `--include_mac_in_profiles` or `--include_all_certificates`.
