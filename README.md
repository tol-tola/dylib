# tola.dylib

Minimal iOS dylib starter for authorized IPA testing.

When loaded, it shows a centered dark modal menu titled `TolaiOS` with Telegram,
TikTok, Facebook, and Website buttons. The app stays visible behind the menu.
Closing the menu leaves a floating icon button that opens the menu again.

The menu keeps roughly the same modal size in portrait and landscape. On short
screens, the inside of the modal scrolls instead of becoming full-screen.

## Line ESP

The `Line ESP` toggle now runs a first-pass automatic screen-vision detector.
When enabled, it captures the underlying game window, finds the main green table
area, detects ball-like circles, scans for the current bright aim line, chooses
the likely cue ball, checks clear ball-to-pocket paths, and draws the best
matched prediction.

This is still an approximation. For stronger prediction, the dylib needs one of
these data sources:

- The game's own ball positions, cue angle, and power values from source code or
  authorized debug data.
- A screen-vision detector that reads the rendered table image, detects balls,
  detects cue angle/power, and then runs a local pool-physics simulation.

The current version is strict: it prefers showing nothing over showing a wrong
shot. It follows the detected aim line, finds the first ball on that path, and
only draws a pocket line when the detected path is clear. More exact final
resting spots and shot-power prediction require better cue/power detection and a
fuller physics model.

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

The dylib searches these places:

- The main app bundle root
- The main app resources folder
- The app's `Frameworks` folder
- The same folder as `tola.dylib`

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
