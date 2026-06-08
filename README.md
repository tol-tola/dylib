# tola.dylib

Minimal iOS dylib starter for authorized IPA testing.

When loaded, it shows a welcome menu titled `TolaiOs` with Telegram, TikTok,
Facebook, Website, and Close buttons. Closing the menu leaves a floating `T`
button that opens the menu again.

Edit these values at the top of `TolaDylib/Tola.m` before building:

```objc
static NSString * const TolaTelegramURL = @"https://t.me/your_username";
static NSString * const TolaTikTokURL = @"https://www.tiktok.com/@your_username";
static NSString * const TolaFacebookURL = @"https://www.facebook.com/your_username";
static NSString * const TolaWebsiteURL = @"https://example.com";
```

## Change Floating Icon

Add a PNG named:

```text
tola_icon.png
```

Put it in the app bundle when you inject/sign the IPA. If `tola_icon.png` is
found, the floating button uses it. If not, it falls back to the letter `T`.

Recommended image size: `112x112` or `180x180` PNG with a transparent
background.

## Build

This must be built on macOS with Xcode command line tools installed:

```bash
chmod +x build_macos.sh
./build_macos.sh
```

The output will be:

```text
build/tola.dylib
```

## Build Without A Mac

You can build it with GitHub Actions:

1. Create a GitHub repository and upload these files.
2. Open the repository on GitHub.
3. Go to `Actions`.
4. Choose `Build tola.dylib`.
5. Click `Run workflow`.
6. When the build finishes, open the run and download the `tola-dylib`
   artifact.

Inside the downloaded artifact will be:

```text
tola.dylib
```

An Ubuntu VPS is not recommended for this because iOS dylibs need Apple's
iPhoneOS SDK. GitHub's macOS runner already has Xcode and the iOS SDK installed.

## Notes

- Target architecture: `arm64`
- Minimum iOS version: `12.0`
- Install name: `@rpath/tola.dylib`
- Use only with apps you own or have permission to test.
