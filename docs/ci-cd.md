# CI/CD — Developer Guide

This is the single reference for how `ketamiz-mobile` is built, tested and
released for **Android** and **iOS**. Read this before pushing tags or touching
the release pipeline.

- App: `ketamiz` (Bundle/Package ID `uz.ketamiz.app`)
- Flutter: `3.41.9` (pinned in every workflow)
- CI/CD: GitHub Actions
- Related docs: [iOS setup details](ios-cicd-setup.md) · [Ownership transfer](handover-transfer.md)

---

## 1. The big picture

There are **three** workflows under `.github/workflows/`:

| Workflow | File | Trigger | What it does |
|----------|------|---------|--------------|
| **CI** | `ci.yml` | every push / PR to `main` | format check, analyze, tests |
| **Android release** | `release.yml` | push a `v*` tag | build signed AAB → Google Play (production) |
| **iOS release** | `ios-release.yml` | push an `ios-v*` tag | build signed IPA → TestFlight |

Key idea: **pushing code never releases anything.** Releases happen only when
you push a **tag**. Android and iOS use *different* tag prefixes so you can
release them independently.

```
git push                → CI only (analyze + test)
git tag v1.0.3          → Android → Google Play
git tag ios-v1.0.3      → iOS → TestFlight
```

---

## 2. CI (every push / PR)

`ci.yml` runs on every push and PR to `main`. It needs **no secrets**.

Steps:
1. `flutter pub get`
2. `dart format` check — **warning only**, never fails the build
3. `flutter analyze --no-fatal-infos` — fails on errors/warnings, not on infos
4. `flutter test`

You can also run it manually from the **Actions** tab (`workflow_dispatch`).

---

## 3. Android release flow

**Trigger:** a tag matching `v*` (e.g. `v1.0.3`).

What `release.yml` does on a macOS-free Ubuntu runner:
1. Sets up Java 17 + Flutter
2. Restores the signing keystore from secrets (see §5)
3. Recreates `android/key.properties` from secrets
4. `flutter build appbundle --release`
5. Uploads the AAB to **Google Play, production track**, as a **staged rollout
   to 20% of users** (`track: production`, `status: inProgress`,
   `userFraction: 0.2`). It goes to Google review automatically.
6. Also stores the AAB as a GitHub artifact (backup).

> The signing keystore (`upload-keystore.jks`) and `key.properties` are **never
> committed** — they live only in secrets and are reconstructed at build time.

### How to cut an Android release
```bash
# 1. Bump the version in pubspec.yaml, e.g. 1.0.2+3 -> 1.0.3+4
#    The number after '+' (versionCode) MUST be higher than the last one
#    already on Play, or Google rejects the upload.
# 2. Commit and push to main.
# 3. Tag and push:
git tag v1.0.3
git push origin v1.0.3
```

---

## 4. iOS release flow

**Trigger:** a tag matching `ios-v*` (e.g. `ios-v1.0.3`).

iOS needs a **macOS runner** and is more involved. Signing uses **Fastlane
Match** (certificates stored encrypted in a separate private repo,
`ketamiz-ios-certs`). See [ios-cicd-setup.md](ios-cicd-setup.md) for the full
setup.

What `ios-release.yml` does:
1. Selects **Xcode 26** (Apple requires the iOS 26 SDK for uploads)
2. Sets up Flutter + Ruby/fastlane
3. `flutter build ios --config-only` (generates Flutter's Xcode config + pods)
4. Loads the read-only SSH deploy key so Match can read the certs repo
5. `fastlane ios beta`:
   - Match restores the distribution certificate + provisioning profile
     (into a temporary keychain on CI)
   - switches the Runner target to manual signing
   - builds the signed IPA
   - uploads it to **TestFlight**

> Currently iOS goes to **TestFlight only**. A dormant `release` lane for
> automatic App Store submission exists in `Fastfile` — see §7.

### How to cut an iOS (TestFlight) release
```bash
# 1. Bump the version in pubspec.yaml (the '+N' build number must increase).
# 2. Commit and push to main.
# 3. Tag and push:
git tag ios-v1.0.3
git push origin ios-v1.0.3
```

---

## 5. Secrets — what each one is for

Configured in **Settings → Secrets and variables → Actions**. CI needs none;
releases need these. (Transferring the repo keeps secrets; see
[handover-transfer.md](handover-transfer.md).)

### Android (5) — used by `release.yml`
| Secret | Purpose |
|--------|---------|
| `KEYSTORE_BASE64` | The Android signing keystore (`upload-keystore.jks`), base64-encoded. Decoded at build time to sign the AAB. **Losing this means you can never update the app on Play.** |
| `STORE_PASSWORD` | Password for the keystore file. |
| `KEY_PASSWORD` | Password for the signing key inside the keystore. |
| `KEY_ALIAS` | Alias of the signing key (`upload`). |
| `SERVICE_ACCOUNT_JSON` | Google Play service account JSON. Lets the workflow upload to Play Console on your behalf (no manual login). Tied to the Play account that owns the app. |

### iOS (6) — used by `ios-release.yml`
| Secret | Purpose |
|--------|---------|
| `MATCH_PASSWORD` | Passphrase that encrypts/decrypts the Match certificates. Without it the certs can't be read. |
| `MATCH_GIT_URL` | SSH URL of the certs repo (`git@github.com:.../ketamiz-ios-certs.git`). Match clones it to fetch signing material. |
| `MATCH_SSH_PRIVATE_KEY` | Private half of a **read-only deploy key** for the certs repo. The runner has no access to your personal SSH keys, so this is how it reads the certs. |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID. Used for upload + signing API calls. |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID (one per account). |
| `APP_STORE_CONNECT_KEY_P8` | The `.p8` API private key contents. Replaces Apple ID + 2FA login on CI. |

---

## 6. Versioning rules

`pubspec.yaml` version is `<name>+<build>`, e.g. `1.0.2+3`:
- `1.0.2` = **versionName / marketing version** (what users see)
- `3` = **build number / versionCode** (internal)

**The build number must always increase** on every release, on both stores.
Android (Play) and iOS (App Store) each track their own last-used number, so
keep bumping `+N` and you're safe for both.

---

## 7. iOS: TestFlight → App Store (not enabled yet)

CI uploads iOS to **TestFlight**. To release to the public App Store there's a
ready-but-dormant `release` lane in `ios/fastlane/Fastfile`.

Before enabling it, App Store Connect must be fully set up **manually**:
metadata, screenshots, the App Privacy questionnaire, age rating, export
compliance — and the first version submitted manually once.

To enable, change the last step of `ios-release.yml`:
```yaml
run: bundle exec fastlane ios beta      # current (TestFlight)
run: bundle exec fastlane ios release   # App Store + auto submit for review
```

Full details in [ios-cicd-setup.md §7](ios-cicd-setup.md).

---

## 8. When something fails

- **Open the Actions tab**, click the red run, open the failed step.
- Common causes:
  - **Android "version code already used"** → bump `+N` in `pubspec.yaml`.
  - **iOS "build with iOS 26 SDK"** → the Xcode-26 selection step handles this;
    if it fails, the runner image may have changed Xcode paths.
  - **iOS Match / signing errors** → check `MATCH_PASSWORD`, the deploy key, and
    that the certs repo is reachable.
  - **`Secrets.xcconfig` not found** → it's gitignored and optional
    (`#include?`); don't make it a hard include.
- To re-run without new code: **Actions → the run → "Re-run jobs"**, or push the
  tag again (delete + recreate it).

---

## 9. File map

```
.github/workflows/
  ci.yml             # analyze + test on push/PR
  release.yml        # Android → Google Play on v* tags
  ios-release.yml    # iOS → TestFlight on ios-v* tags
ios/
  Gemfile            # pins fastlane
  fastlane/
    Appfile          # bundle id + team
    Fastfile         # beta (TestFlight) + release (App Store) lanes
    Matchfile        # Match config (certs repo, appstore type)
android/
  key.properties     # gitignored; rebuilt from secrets on CI
  upload-keystore.jks# gitignored; rebuilt from KEYSTORE_BASE64 on CI
docs/
  ci-cd.md           # this file
  ios-cicd-setup.md  # detailed iOS / Match setup
  handover-transfer.md # transferring the repo to a new owner
```
