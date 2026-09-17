# Local build configuration

`Local.xcconfig` contains local WeChat settings and is ignored by Git.
Debug, Release and Production include this file along with their CocoaPods configuration.

On a new checkout:

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Fill in `WECHAT_APP_ID` and `WECHAT_UNIVERSAL_LINK`, then build/archive `yugioh.xcworkspace`.
For HTTPS links use `https:/$()/your-domain.example/wechat/` because `//` starts an xcconfig comment.
The App ID is injected into both the SDK configuration and URL scheme at build time.
The local file is deliberately required so a missing configuration fails at build time.
Universal Link domain association still requires the matching Associated Domains and server configuration.

These values are excluded from future Git commits, but will be present in the built app.
This change does not remove values from existing Git history.
