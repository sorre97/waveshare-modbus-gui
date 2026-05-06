# RelayCtrl Pro

Desktop GUI for controlling a **Waveshare 8-channel Modbus relay board** over TCP.

Dark/neon-green cyberpunk UI. Python FastAPI WebSocket backend. Flutter desktop frontend (macOS, Linux, Windows).

---

## Architecture

```
[Flutter GUI] ──WebSocket──► [FastAPI Hub :8192] ──Modbus TCP──► [Relay Board :4196]
```

The hub maintains a single persistent Modbus TCP connection to the relay board and broadcasts state to all connected GUI clients over WebSocket.

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| Backend   | Python 3.10+ |
| Frontend  | Flutter 3.32+ / Dart 3.5+ |
| Board     | Waveshare 8-ch Modbus relay (TCP mode) |

---

## Backend

### Setup

```bash
cd Backend
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install fastapi uvicorn websockets wsproto
```

### Run

```bash
python main.py
```

All parameters have defaults that match the Waveshare board out of the box:

```
--modbus-ip       IP address of the Modbus device     (default: 192.180.100.21)
--modbus-port     TCP port of the Modbus device        (default: 4196)
--device-address  Modbus device address (hex ok)       (default: 0x01)
--host            Hub bind address                     (default: 0.0.0.0)
--port            Hub WebSocket port                   (default: 8192)
```

#### Examples

```bash
# Default (real board)
python main.py

# Different board IP
python main.py --modbus-ip 192.168.1.50

# Point at mock server for local testing
python main.py --modbus-ip 127.0.0.1 --modbus-port 4196

# Custom hub port
python main.py --port 9000
```

---

## Mock Modbus Server (for development)

Simulates the relay board locally — no hardware needed.

```bash
python mock_modbus/server.py
```

Options:

```
--host      Bind host   (default: 127.0.0.1)
--port      Bind port   (default: 4196)
--verbose   Also log background read-poll traffic
```

Then start the backend pointing at it:

```bash
python Backend/main.py --modbus-ip 127.0.0.1 --modbus-port 4196
```

---

## GUI (Flutter)

### Run from source

```bash
cd GUI
flutter pub get
flutter run -d macos      # or linux / windows
```

### Build release

```bash
flutter build macos --release
flutter build linux --release
flutter build windows --release
```

Connect the GUI to your backend via **Settings** (default `127.0.0.1:8192`).

---

## CI/CD — GitHub Actions

Every push to `main` triggers the Release workflow:

| Job | Runner | Output |
|-----|--------|--------|
| `build-macos` | `macos-latest` | `RelayCtrlPro-macOS.dmg` |
| `build-linux` | `ubuntu-22.04` | `RelayCtrlPro-Linux-x86_64.AppImage` |
| `build-windows` | `windows-2022` | `RelayCtrlPro-Windows-x64-Portable.zip` |
| `build-backend` | `ubuntu-latest` | `RelayCtrlPro-Backend.zip` |

Releases are tagged `v0.1.N` (N = commit count). Only one workflow runs at a time — new pushes cancel in-progress runs.

### macOS Gatekeeper

The app is ad-hoc signed but not notarized. After dragging to Applications:

```bash
xattr -cr "/Applications/RelayCtrl Pro.app"
```

Then open normally.

---

## Project Structure

```
waveshare-modbus-gui/
├── .github/workflows/release.yml   # CI/CD
├── Backend/
│   ├── main.py                     # FastAPI WebSocket hub
│   └── pycrc.py                    # Modbus CRC
├── mock_modbus/
│   └── server.py                   # Mock relay board (dev/testing)
├── cli/
│   └── modbus-cmd.py               # Reference CLI tool
└── GUI/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── theme.dart
        ├── services/ws_service.dart
        ├── screens/
        │   ├── dashboard_screen.dart
        │   ├── main_layout.dart
        │   └── settings_screen.dart
        └── widgets/
            ├── relay_card.dart
            ├── relay_toggle.dart
            ├── sidebar.dart
            └── modbus_console.dart
```
