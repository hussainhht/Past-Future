# The Other Me — macOS Installation

**Build:** `The_Other_Me_macOS_Universal.zip` — one app for Intel (x86_64) and Apple Silicon (arm64).
**Requires:** macOS 11 or newer on Intel, macOS 13 or newer on Apple Silicon.

> **This is an unsigned test build.** It is not signed with an Apple Developer ID and is not notarized by Apple,
> so macOS will warn you the first time you open it. The steps below open this one app only; you do not need
> to change any system-wide security setting.

## 1. Download
Download `The_Other_Me_macOS_Universal.zip` from the game's itch.io page
(<https://hussainhht.itch.io/the-other-me>).

## 2. Extract
Double-click the ZIP in Finder (or Safari does it automatically). You will get **The Other Me.app**.

## 3. Move to Applications
Drag **The Other Me.app** into your **Applications** folder. (You can run it from anywhere, but
Applications avoids macOS running it from a temporary, read-only "translocated" location.)

## 4. Open the game
Because the build is unsigned, a double-click may show *"The Other Me cannot be opened because the developer cannot be verified"* (or *"is damaged"* on some systems).

**Option A — System Settings (recommended)**
1. Double-click **The Other Me.app** once and dismiss the warning.
2. Open **System Settings → Privacy & Security**, scroll to **Security**.
3. Click **Open Anyway** next to *"The Other Me" was blocked…*, then confirm with your password and click **Open**.

On macOS 14 and earlier you can instead **right-click (or Control-click) the app → Open → Open**.

**Option B — Terminal (only if Option A fails or you see "is damaged")**
This removes the download-quarantine flag from this one app only:

```sh
xattr -dr com.apple.quarantine "/Applications/The Other Me.app"
```

Then open the app normally. Only do this for a copy you downloaded from the official itch.io page.

## 5. Play with another person (LAN co-op)
Two players are needed: **Student (Past)** hosts, **Professor (Future)** joins. Windows and Mac players use
the same network protocol and can play together, as long as both run the same game version.

1. Both computers must be on the **same Wi-Fi / local network**.
2. **Host:** open the game → **HOST ON WI-FI**. The menu lists your IP address(es); tell the other player one.
3. **Guest:** open the game → **JOIN ON WI-FI**, type the host's IP address, and connect.
4. When both players are ready, the host starts the game.

Notes:
- The game uses **UDP port 7000**.
- On first host/join, macOS may ask *"The Other Me would like to find and connect to devices on your local network"* —
  click **Allow**. If you clicked *Don't Allow*, re-enable it in **System Settings → Privacy & Security → Local Network**.
- If macOS's firewall is on (**System Settings → Network → Firewall**), allow incoming connections for
  *The Other Me* when prompted, so the host can accept the guest.
- Guest networks, VPN or "client isolation" on some Wi-Fi routers block player-to-player traffic. For play over the
  internet, put both players on a VPN such as Tailscale and use the host's VPN address.

## Troubleshooting
| Problem | Fix |
| --- | --- |
| "Cannot be opened because the developer cannot be verified" | Step 4, Option A. |
| "The Other Me is damaged and can't be opened" | Step 4, Option B (quarantine flag). |
| Nothing happens when double-clicking | Re-extract the ZIP from itch.io (a damaged download can lose the executable permission). |
| Joining fails with a timeout | Check both are on the same network, the IP is correct, Local Network is allowed, and no firewall blocks UDP 7000. |
