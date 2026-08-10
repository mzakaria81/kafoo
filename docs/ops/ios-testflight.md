# Getting Kafoo onto an iPhone

**Who this is for: the founder, testing Kafoo on his own phone, with no Mac.** Every step below is
a web page or a phone. Nothing here needs a computer running macOS, and nothing here needs a cable.

**Status on 2026-08-10: the code is ready and waiting for one purchase.** `deploy.yml` builds,
signs and uploads. It switches itself off until the four secrets in step 5 exist, so nothing here
has ever run. The first run will be the first time any of it executes — expect to fix something.

## What this costs

$99 a year, to Apple, for the Developer Program. That is the whole bill. The Mac that builds the
app is GitHub's and is free, because `mzakaria81/kafoo` is a public repository and GitHub gives
public repositories unlimited build minutes on every machine type.

There is a free alternative and it does not apply to us: a Mac you own can install an app onto an
iPhone over a USB cable at no cost. It needs a Mac and a cable, and a cloud Mac has neither a body
nor a cable. Building and delivering are different problems; the cloud Mac only solves building.

## What you get

The TestFlight app on your phone, with Kafoo inside it, updating like any other app. Builds arrive
minutes after you ask for one — internal testing needs no Apple review. A build stops working 90
days after upload, and asking for a new one is one button.

---

## Step 1 — join the Apple Developer Program

Go to **developer.apple.com/programs/enroll**.

- Sign in with an Apple ID **created for Kafoo**, not your personal one. `docs/ops/release-custody.md`
  decided this: a trustee needs break-glass access to this account one day, and a personal Apple ID
  would put your mail, photos and backups inside the same envelope.
- Choose **Individual**, not Organization. Organization needs a D-U-N-S number and takes weeks;
  Individual usually clears in a day or two. The cost of Individual is written down in the custody
  document — the short version is that your legal name shows as the seller on a public listing, and
  that only matters when Kafoo is on the App Store, not while you are the only tester.
- Two-factor authentication is required. Do **not** enable an Apple Recovery Key: it turns off
  Apple's ability to help you recover the account, which is the recovery route the custody document
  depends on.
- Pay the $99.

Wait for Apple's confirmation email before step 2.

## Step 2 — create the app's record

Go to **appstoreconnect.apple.com** → **Apps** → **+** → **New App**.

| Field | Value |
|---|---|
| Platform | iOS |
| Name | Kafoo |
| Primary language | Arabic (Egypt) |
| Bundle ID | `com.kafoo.kafooMobile` |
| SKU | `kafoo-mobile` |

The Bundle ID must match exactly — it is what ties the upload to this record, and it is already set
in the code. If it does not appear in the dropdown, click the link to register it first.

You do not fill in screenshots, descriptions or pricing. Those are for publishing, and you are not
publishing.

## Step 3 — find your Team ID

**appstoreconnect.apple.com** → **Users and Access** → **Integrations** tab. The Team ID is a
ten-character code like `A1B2C3D4E5`. Copy it.

## Step 4 — create an API key

Same page: **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** →
**+**.

- Name: `Kafoo CI`
- Access: **App Manager**

Click Generate. You now have three things:

- the **Key ID**, shown in the table
- the **Issuer ID**, shown above the table
- a **`.p8` file**, which downloads when you click Download

**The `.p8` file can be downloaded exactly once.** Apple will not give it to you again. If you lose
it, revoke the key and make another — that is a two-minute annoyance, not a disaster, so do not
treat this as high drama. Do not email it to yourself and do not put it in the repository.

## Step 5 — put four values into GitHub

**github.com/mzakaria81/kafoo** → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**, four times.

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | the ten-character code from step 3 |
| `APP_STORE_CONNECT_KEY_ID` | the Key ID from step 4 |
| `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID from step 4 |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | the `.p8` file, converted — see below |

The last one is a file, and a GitHub secret holds text, so it has to be converted to one long line
first. On Windows, open PowerShell in the folder holding the downloaded file and run:

```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8")) | Set-Clipboard
```

Replace `AuthKey_XXXX.p8` with the real filename. The converted value is now on your clipboard —
paste it straight into the secret. It is one long line with no spaces.

**Do not paste the file's contents into a chat with me or any other assistant, and do not email it
to yourself.** It is a private key. The clipboard, going directly into GitHub's secret box, is the
shortest path it can take.

## Step 6 — add yourself as a tester

**appstoreconnect.apple.com** → **Apps** → **Kafoo** → **TestFlight** tab → **Internal Testing** →
**+** → create a group called `Founder` → add yourself.

Do this once. An uploaded build does not appear on your phone by itself — it appears to the people
in a testing group, and until you are in one there is nobody to show it to. Internal testers need
no Apple review, which is what makes this route minutes rather than days.

## Step 7 — ask for a build

**Actions** → **Deploy** → **Run workflow** → branch **main** → **Run workflow**.

It must be `main` and it must be this manual button. A merge to `main` builds the app to check that
it still compiles, but deliberately does not sign it and sends nothing to Apple — pushing to your
phone is something you ask for, never something that happens because a change landed.

Ten to twenty minutes later the run finishes, and its summary says the build was sent.

## Step 8 — install it

On your iPhone, install **TestFlight** from the App Store. Sign in with the same Apple ID from
step 1. Kafoo appears. Tap Install.

The first build asks you to accept a testing agreement. After that, new builds appear as updates.

---

## When something goes wrong

**The `ios` job did not run at all.** One of the four secrets is missing or misspelled. The
`preflight` job prints `App Store Connect credentials present: false`, and the whole iOS job is
skipped rather than failed — deliberately, so that a repository with no Apple account is not
permanently red.

**"No profiles found" or a signing error in "Sign and export the app".** The app record in step 2
does not exist, or its Bundle ID is not exactly `com.kafoo.kafooMobile`, or the API key's access
level is below App Manager.

**"Maximum number of certificates generated" — and this one is expected, not a fault.** Apple lets
three signing certificates exist at once. Every signed build asks for a new one, because the
machine that builds is destroyed afterwards and keeps nothing. So the fourth build fails.

The fix takes a minute: **developer.apple.com** → **Certificates, IDs & Profiles** → **Certificates**
→ delete the older **Apple Distribution** entries → dispatch again. Deleting one does not break
builds already in TestFlight or on the App Store; it only stops that certificate signing anything
new.

Only signed builds spend a slot. Ordinary merges build without signing, so normal development
never touches this — three *TestFlight* builds, not three merges.

**The build uploaded but nothing appears in TestFlight on your phone.** Either Apple is still
processing it — five to fifteen minutes is normal, and App Store Connect shows the state — or you
skipped step 6 and are not in a testing group.

**"altool is not available" or an upload tool error.** `altool` is Apple's older upload command and
Apple has been steering people towards Transporter. It works today; if a future Xcode on GitHub's
machines drops it, this is the symptom, and the workflow's upload step is the thing to change.

**Apple asks for privacy details before the build can be distributed.** The three permissions Kafoo
declares — microphone, speech recognition, photo library — may need matching entries in App Store
Connect's privacy questionnaire. Internal testing usually does not require it; publishing always
does. Fill it in when asked.

**The upload is rejected for a duplicate build number.** Each run uses the GitHub run number, which
never repeats, so this means the same run was uploaded twice. Dispatch a new run.

**Kafoo installs and then closes immediately when opened.** The build was made without the Supabase
address and key. `deploy.yml` passes both; if this happens, that is the thing to check first.

**Kafoo closes when you tap the microphone or pick a photo.** iOS terminates an app that asks for a
protected resource without declaring why. The three declarations live in
`apps/mobile/ios/Runner/Info.plist` and were added on 2026-08-10 — if one is removed, this is the
symptom, and it is a crash rather than a refusal.

## What this does not cover

Publishing to the App Store. That needs Apple review, screenshots, a description in Egyptian
Arabic, and the pre-submission checklist in `.claude/agents/release-engineer.md`. Nothing in this
document puts Kafoo in front of a Customer.
