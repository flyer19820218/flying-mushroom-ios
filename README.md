# Flying Mushroom iOS (飛菇)

An open-source iPhone location-simulation app with a map, single locations, saved locations, multi-point routes, walking routes, GPX import, and Wi-Fi / cellular-start modes. This is an experimental sideloaded app, not an App Store release. iOS behavior can change; no particular device or network configuration is guaranteed.

**重要：**本公開版不附帶任何人的 Apple 帳號、Team ID、裝置識別碼、配對檔、座標書籤或私人 GPX 路線。安裝者需準備自己的資料，且不要把配對檔或簽署資料上傳到 GitHub。

## Start here / 從這裡開始

1. You need a Mac with a current Xcode, an iPhone running iOS 17.4 or later, a USB cable for the first installation, your own Apple ID for signing, [LocalDevVPN](https://apps.apple.com/us/app/localdevvpn/id6755608044), and a pairing file made for **your** iPhone. Do not use somebody else's pairing file.
2. Clone/download this repository and open `TLocation.xcodeproj` in Xcode.
3. Select the `TLocation` project → `TLocation` app target → **Signing & Capabilities**. Enable **Automatically manage signing**, select your own Team, and replace the example bundle identifier `com.example.FlyingMushroom` with a unique identifier you control (for example `com.yourname.FlyingMushroom`). Do not commit that change to a public fork if it reveals your identity.
4. Connect and unlock your iPhone. Trust the computer if prompted, enable Developer Mode if iOS requests it, select the iPhone as the run destination, then press **Run** (▶) in Xcode. If signing fails, resolve Xcode's signing message before troubleshooting the VPN.
5. On iPhone, import your own pairing file into 飛菇. The [StikDebug pairing-file guide](https://github.com/StikDebug/StikDebug-Guide/blob/main/pairing_file.md) describes how to create one. Pairing files are sensitive: keep them on your own device and out of Git.
6. Install and enable LocalDevVPN. For the first test, join a working Wi-Fi network, open 飛菇, and choose **Wi-Fi 快速啟動**. Wait until pairing, tunnel and DDI are ready. The first DDI download needs working internet.
7. Test a harmless single location, then tap **恢復真實定位**. Restoring the real location can take tens of seconds. Check the actual location in another app before relying on it.

For an AI assistant to guide each step and diagnose errors, give it [AI_SETUP.md](AI_SETUP.md) (or point it at this repository). It is written to work with free AI tools too; no ChatGPT subscription is required to run the installed app.

## Cellular-only start / 無 Wi-Fi 啟動

This was observed to work in one setup, but is more fragile than Wi-Fi and may differ by iOS version. In the app choose **4G 離線啟動** and follow the on-screen guide: turn Wi-Fi off while cellular remains on; wait for LocalDevVPN to connect; while staying in LocalDevVPN, enable Airplane Mode; return manually to 飛菇; wait for pairing/tunnel/DDI; start a location or route **before** turning Airplane Mode off; after the green “定位已建立” message, turn Airplane Mode off to restore cellular. Keep 飛菇 running. If this fails, retry on Wi-Fi and record the exact error; the cellular procedure is not a universal bypass for iOS restrictions.

## Privacy and safety

- All routes, bookmarks, pairing files, device IDs, signing identities, and local configuration are personal data. This repository ships without them. The ignore rules are a backstop, not a guarantee: review `git diff --cached` before pushing a fork.
- Simulated location can affect maps, safety features and other apps. Use only on devices/accounts you control and respect applicable app rules and laws.
- The bundled `idevice` static library is arm64 iPhone-only and large (about 85 MB); simulator builds are not supported by this package.
- A free Apple development signing profile may need renewal after about seven days. Xcode can rebuild and reinstall with your own account. Avoid deleting the app before a renewal if you need its local data.

## Build check

Unsigned compile check on a Mac with Xcode:

```sh
xcodebuild -project TLocation.xcodeproj -scheme TLocation -configuration Debug \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

To deploy to a phone, use Xcode's Run button and your own Team/bundle identifier as above. There is no pre-signed IPA in this repository.

## Credit and license

This is a derivative of [StikDebug](https://github.com/StikDebug/StikDebug) by Stephen Bove (Stik) and contributors, not an original device-communication implementation. The StikDebug core handles pairing, the loopback tunnel, DDI mounting and location simulation; this fork adds the mobile location/route interface. AGPL-3.0 applies to this derivative; see [LICENSE](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the bundled `idevice` MIT notice.
