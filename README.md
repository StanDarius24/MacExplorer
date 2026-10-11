# MacExplorer

A dual-pane, Total Commander-style file explorer for macOS, built with SwiftUI. It supports browsing the local filesystem in two side-by-side panes, plus connecting to a remote server over SSH/SFTP to browse remote directories in the right pane.

## Installation

MacExplorer is distributed via GitHub Releases as an ad-hoc signed `.app` bundle (no Apple Developer ID / notarization is configured for this project yet, so builds are not notarized).

Install the latest release with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/StanDarius24/MacExplorer/main/scripts/install.sh | bash
```

This script will:
1. Look up the latest GitHub Release for this repository.
2. Download the release `.zip` and verify its SHA-256 checksum.
3. Unpack it and install `MacExplorer.app` into `/Applications` (replacing any existing copy).
4. Clear the macOS Gatekeeper quarantine flag so the unsigned/ad-hoc build can run without a "can't be opened" warning.
5. Launch the app.

You can also download the release asset manually from the [Releases page](https://github.com/StanDarius24/MacExplorer/releases), unzip it, and drag `MacExplorer.app` into `/Applications` yourself — just run `xattr -cr /Applications/MacExplorer.app` afterward to clear the quarantine flag before launching, since the build isn't notarized.

## Building from source

Open `MacExplorer.xcodeproj` in Xcode (requires a recent Xcode with Swift Package Manager support) and build/run the `MacExplorer` scheme. The project depends on [Citadel](https://github.com/orlandos-nl/Citadel) for SSH/SFTP support, resolved automatically via Swift Package Manager.

## Releasing a new version

Releases are built automatically by [`.github/workflows/release.yml`](.github/workflows/release.yml). To cut a new release:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The workflow builds the app in Release configuration, ad-hoc signs it, zips it, and publishes it as a GitHub Release with a checksum file. The workflow can also be triggered manually from the Actions tab (useful for test builds).
