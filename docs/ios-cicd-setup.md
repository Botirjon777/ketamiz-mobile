# iOS CI/CD setup (Fastlane Match + GitHub Actions)

This guide documents how the `ketamiz` app is built for iOS and uploaded to
**TestFlight** automatically. Code signing is handled by **Fastlane Match**.

Project details:
- Bundle ID: `uz.ketamiz.app`
- Apple Team ID: `DJ6Z29BM4D`
- Build environment: GitHub Actions `macos-latest` runner (Xcode 26)

> ⚠️ **Order matters:** the first App Store submission should be done manually
> (so App Store Connect metadata is filled in and Apple's initial review
> passes). The Match setup is used both for the manual build and for CI.

---

## 0. Prerequisites

- Apple Developer Program membership — Team `DJ6Z29BM4D`
- The `uz.ketamiz.app` app created in App Store Connect
- A **separate private git repo** to store the Match certificates
  (e.g. `AbbosbekBotirjonovich/ketamiz-ios-certs`)

---

## 1. Install fastlane locally

Installed via the `Gemfile` (for version stability):

```bash
cd ios
bundle install
```

The Gemfile approach guarantees the same fastlane version as CI.

---

## 2. Fastlane files

Under `ios/`:

- `ios/Gemfile` — fastlane version
- `ios/fastlane/Appfile` — bundle id and team
- `ios/fastlane/Fastfile` — build/upload lanes
- `ios/fastlane/Matchfile` — Match configuration

---

## 3. Create an App Store Connect API key

CI uses an API key instead of an Apple ID + password (avoids 2FA issues).

1. https://appstoreconnect.apple.com → **Users and Access → Integrations → App Store Connect API**
2. **"Generate API Key"** → name: `github-ci`, Access: **App Manager**
3. Download the key once: `AuthKey_XXXXXXXXXX.p8` (**downloadable only once!**)
4. Note down:
   - **Key ID** (e.g. `Y4ZWNJF593`)
   - **Issuer ID** (shown at the top of the page, as a UUID)

---

## 4. Run Fastlane Match for the first time (locally)

Match encrypts the certificate/profiles and stores them in the private repo.

```bash
cd ios

# Creates the certificate + profile and pushes them to the certs repo.
# Temporarily set readonly(false) in Matchfile before the first run.
bundle exec fastlane match appstore
```

- Match asks for a **passphrase** (`MATCH_PASSWORD`) used for encryption — remember it.
- Set `readonly(true)` back in `Matchfile` afterwards.

---

## 5. GitHub Secrets (iOS)

Repo: `AbbosbekBotirjonovich/ketamiz-mobile`
→ Settings → Secrets and variables → Actions

| Secret name | Value |
|-------------|-------|
| `MATCH_PASSWORD` | Match encryption passphrase (from step 4) |
| `MATCH_GIT_URL` | `git@github.com:AbbosbekBotirjonovich/ketamiz-ios-certs.git` (standard github.com host for CI) |
| `MATCH_SSH_PRIVATE_KEY` | PRIVATE part of the certs-repo read-only deploy key (full BEGIN…END) |
| `APP_STORE_CONNECT_KEY_ID` | API Key ID (step 3) |
| `APP_STORE_CONNECT_ISSUER_ID` | API Issuer ID (step 3) |
| `APP_STORE_CONNECT_KEY_P8` | Full contents of the `.p8` file |

> **CI access to the certs repo — SSH deploy key:**
> 1. Generate a key pair locally (`ssh-keygen -t ed25519`).
> 2. Add the PUBLIC part to the certs repo → Settings → Deploy keys → "Add deploy key"
>    (read-only, do NOT check "Allow write access").
> 3. The PRIVATE part becomes the `MATCH_SSH_PRIVATE_KEY` secret.
> 4. The workflow loads it into the runner via the `webfactory/ssh-agent` action.

---

## 6. GitHub Actions workflow

`.github/workflows/ios-release.yml`. On an `ios-v*` tag push:
1. Selects Xcode 26 on the macOS runner (Apple requires the iOS 26 SDK)
2. Installs Flutter + CocoaPods (`flutter build ios --config-only`)
3. Restores the certificate/profile via Match (temporary keychain on CI)
4. Switches to manual signing (`update_code_signing_settings`) and builds the IPA
5. Uploads to **TestFlight** via the App Store Connect API (`fastlane ios beta`)

---

## 7. Moving from TestFlight to the App Store (future)

CI currently uploads to **TestFlight** (the `beta` lane). A `release` lane for
automatic App Store releases already exists in `Fastfile` but is **intentionally
not wired into CI**.

### Before enabling (manually, in App Store Connect)
- **Metadata**: name, subtitle, description, keywords, category
- **Privacy policy URL** (a web page is required)
- **Screenshots** (for every required device size: 6.7", 6.5", 5.5"...)
- **App Privacy** questionnaire (what data is collected)
- **Age rating**, **Export Compliance**
- **Submit the first version manually at least once** and let it pass review.
  Automatic submission is only reliable after that.

### Enabling
In `.github/workflows/ios-release.yml` change the last step:
```yaml
run: bundle exec fastlane ios beta      # current (TestFlight)
run: bundle exec fastlane ios release   # new (App Store + review)
```
The `release` lane uses `submit_for_review: true` and `automatic_release: true`,
so the app is released publicly once review passes.

> ⚠️ `upload_to_app_store` fails if metadata is incomplete. Make sure everything
> is configured manually first.

---

## Notes

- **macOS runners are costlier:** free on public repos, but count ~10x the
  minutes of Linux. Watch the budget on private repos.
- **Build number:** the iOS build number must increase on every upload. The
  `+N` part of the `pubspec.yaml` version maps to the iOS build number.
- **First TestFlight build:** once App Store Connect is fully configured, CI
  runs smoothly.
