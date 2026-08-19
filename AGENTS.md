# AGENTS.md

Single-page Web Bluetooth app for the Domyos 500B rowing machine, with a Three.js 3D rowing game on top. No build system, no package manager, no tests.

## Commands

- `./start.sh` — serve the app at `http://localhost:8000` (kills any prior process on the port first). Web Bluetooth requires HTTPS or `localhost`, so always use this server, not `file://`.
- No lint, typecheck, test, or build steps exist. Verify changes by reloading in Chrome.

## Architecture

- `index.html` is the entire app — HTML, CSS, and JS in one file (~2400 lines). No bundler.
- Three.js is loaded via an ES module import map from `unpkg.com` (pinned to `three@0.160.0`); there is no local node_modules or `package.json`.
- `index_old.html` is the pre-3D BLE-only version; `index.html` is the active entry (git: "Set game as new index"). Don't edit `index_old.html` for new features.
- `CNAME` is for GitHub Pages custom domain.

## BLE protocol gotchas (see README.md for full reference)

- The Domyos 500B does **not** expose FTMS (`0x1826`); it uses the proprietary ISSC service `49535343-fe7d-4ae5-8fa9-...` with separate Notify and Write characteristics (UUIDs in README). Filter on these, not FTMS.
- Data packets are 26 bytes big-endian with header `0xF0` and a trailing checksum (sum of all prior bytes `& 0xFF`). The parser assumes exactly 26 bytes.
- The app sends an init sequence (`F0 A3 93`, `F0 A4 94`, `F0 A5 95`, `F0 AB 9B`) on connect and a `F0 AC 9C` keepalive every ~300ms. Keep this timing; dropping the keepalive drops the connection.
- This uses the **ChangYow** init variant (MAC not starting with `57`); the Telink variant differs.

## Runtime requirements

- Chrome / Edge / Opera only (Web Bluetooth). No Firefox, no Safari, no iOS.
- The rower must be in BT mode (BT logo on its display) before clicking Connect.
