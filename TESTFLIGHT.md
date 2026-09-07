# Getting AMS PARA onto the iPhone through TestFlight

Once this is set up, every new version reaches the phone by itself. No cable, no Xcode,
no seven-day expiry. Everything below happens in a web browser; none of it needs the Mac.

## What you do, once

### 1. Join the Apple Developer Program

<https://developer.apple.com/programs/enroll/> · about 830 SEK a year.

Sign in with your Apple ID, choose **Individual**, pay. Apple usually approves within a
day, sometimes two. You get an email when you are in.

### 2. Make an access key

<https://appstoreconnect.apple.com> › **Users and Access** › **Integrations** › **App Store Connect API**

- Press **+** to add a key.
- Name it `AMS PARA build server`.
- Access: **App Manager**.
- Press Generate.

Now note down three things:

| What | Where it is |
| --- | --- |
| **Issuer ID** | at the top of that page, a long code with dashes |
| **Key ID** | in the row of the key you just made, ten characters |
| **The key file** | press **Download** in that row. It is a file called `AuthKey_XXXXXXXXXX.p8` |

Apple lets you download the key file **once**. Keep it somewhere safe.

### 3. Create the app record

<https://appstoreconnect.apple.com> › **Apps** › **+** › **New App**

- Platform: **iOS**
- Name: `AMS PARA`
- Primary language: English
- Bundle ID: pick `com.schabbauer.AMSPara` from the list. If it is not there yet, run the
  build once (step 5); it registers the identifier, then come back here.
- SKU: `ams-para`
- User access: Full Access

### 4. Give the build server the key

<https://github.com/marsch124/AMS-PARA/settings/secrets/actions> › **New repository secret**

Make three secrets, exactly these names:

| Name | Value |
| --- | --- |
| `ASC_ISSUER_ID` | the Issuer ID from step 2 |
| `ASC_KEY_ID` | the Key ID from step 2 |
| `ASC_KEY_P8` | open the `.p8` file in TextEdit and paste **everything**, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `ASC_TEAM_ID` | the Team ID, ten characters. App Store Connect › **Users and Access** › your name › **Membership Details**, or <https://developer.apple.com/account> under Membership |

The Team ID is what tells the build server which Apple account signs the app. Without it the
build stops with "Signing requires a development team".

### 5. Send the first build

<https://github.com/marsch124/AMS-PARA/actions/workflows/testflight.yml> › **Run workflow**

It takes about ten minutes. When it is green, Apple processes the build for a few more
minutes and then emails you.

### 6. Install TestFlight on the phone

Get **TestFlight** from the App Store, sign in with the same Apple ID, and AMS PARA is
waiting there. Tap Install.

## After that

Every time there is something new, the build server sends it and TestFlight tells the
phone. You tap Update. A build stays usable for 90 days, and there will be new ones long
before that.

## Sharing the vault with the Mac

On the phone, when the app asks for a folder, browse to **iCloud Drive** and pick the same
folder the Mac uses. Both then read and write the same notes.
