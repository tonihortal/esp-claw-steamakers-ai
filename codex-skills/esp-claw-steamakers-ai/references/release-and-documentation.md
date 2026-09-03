# Release and documentation workflow

## Canonical locations

- GitHub: `https://github.com/tonihortal/esp-claw-steamakers-ai`
- Releases: `https://github.com/tonihortal/esp-claw-steamakers-ai/releases`
- Installation guide: `https://docs.google.com/document/d/1fyoyVnxgtrt9Z7oN93ku5jboIVacALTbkpS2LxLj0Vg/edit`
- Board README: `application/edge_agent/boards/steamakers/esp32_steamakers_ai/README.md`

The Google Doc is an existing user document. Use the Google Docs connector and
its required trusted-read/edit-preservation workflow; do not rebuild it from a
local document or use browser typing as a substitute.

## Publish a firmware release

1. Ensure the relevant source and SYSTEM image were built and tested on the
   target board.
2. Choose a new semantic patch version; never replace an already published
   release merely to hide a regression.
3. Update the default in `tools/steamakers/package_release.sh` and run it with
   the explicit version after exporting ESP-IDF.
4. Confirm that the merged image contains bootloader, partition table, initial
   OTA data, application, SYSTEM, and storage at the partition-table offsets.
5. Calculate SHA-256 locally, create the GitHub release, and upload both the
   merged `.bin` and `SHA256SUMS.txt`.
6. Download the public asset to a separate temporary path and calculate its
   SHA-256 again. A successful upload alone is not sufficient verification.
7. Update the board README and Google Docs guide with the verified version,
   direct asset link, filename, command example, and checksum.
8. Re-read the public release and edited documentation before reporting
   completion.

The historical verified baseline is release `v0.1.2`, commit `7a8fabb`, with
merged-image SHA-256
`b4ef74fc751e6ff49c92519b82675a0d7598abaab1c723bc56c8b63d910978bc`.
Always query the current latest release rather than presenting this historical
value as current.

## Installation-guide content to preserve

The guide targets Windows 11, GNU/Linux, and macOS and should retain:

- project purpose, supported components and features;
- limitations, especially empty microSD, PSRAM conflict, PROG/CH340 use, and
  3.3 V signal versus 5 V header power;
- clean-install warning and post-flash Wi-Fi/token reconfiguration;
- verified download and SHA-256 instructions;
- use of the numeric IP displayed on the TFT when mDNS does not work;
- Telegram and free-cloud-provider limitations without promising unlimited
  quotas;
- local UART and complete-hardware-test guidance.

Do not publish SSIDs, private IPs as universal values, bot tokens, provider
keys, GitHub device-login codes, or other conversation-specific secrets.
