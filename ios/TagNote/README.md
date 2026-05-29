# TagNote iPhone App

The iPhone app is a native SwiftUI app. It cannot run inside Docker because iOS
Simulator and app signing require Xcode on macOS.

For local development, run the existing TagNote backend in Docker and connect to
it from iOS Simulator.

## Run The Backend

From the repository root:

```bash
TAGNOTE_TEST_MODE=1 docker compose build
TAGNOTE_TEST_MODE=1 docker compose up -d
```

The API is available at:

```text
http://localhost:3777
```

When `TAGNOTE_TEST_MODE=1`, use:

```text
Email: test@test.com
Password: testpass123
```

## Run The iPhone App

1. Open `ios/TagNote/TagNote.xcodeproj` in Xcode.
2. Select an iPhone simulator.
3. Press Run.
4. On the first screen, enter:

```text
http://localhost:3777
```

iOS Simulator resolves `localhost` to the host Mac, so it can reach the Docker
Compose port mapping directly.

For a physical iPhone, use the Mac's LAN address instead, for example:

```text
http://192.168.1.20:3777
```

Production/self-hosted use should be served over HTTPS.

## Run iOS Tests

Unit tests do not need the TagNote backend. The helper script automatically
selects the first available iPhone simulator:

```bash
ios/TagNote/scripts/test-ios.sh unit
```

E2E UI tests need the Docker backend running and test credentials configured:

```bash
TAGNOTE_TEST_MODE=1 docker compose up -d

TAGNOTE_E2E_SERVER_URL=http://localhost:3777 \
TAGNOTE_E2E_EMAIL=test@test.com \
TAGNOTE_E2E_PASSWORD=testpass123 \
ios/TagNote/scripts/test-ios.sh e2e
```

If you are running the backend on a remote server, expose it through an SSH
tunnel first:

```bash
ssh -L 3777:localhost:3777 user@server
```

To force a specific simulator, set `IOS_TEST_DESTINATION`:

```bash
IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 15 Pro' \
ios/TagNote/scripts/test-ios.sh unit
```

## Headless Mac Mini CI

iOS Simulator tests can run without a visible monitor, but they still need a
logged-in macOS Aqua user session. Do not run them from a system LaunchDaemon or
an SSH-only bootstrap context.

Recommended setup:

1. Keep the CI user logged in on the Mac mini.
2. Enable Screen Sharing for maintenance, but the screen can be locked.
3. Run the test worker as a per-user LaunchAgent under `~/Library/LaunchAgents`.
4. Run `ios/TagNote/scripts/test-ios.sh unit` or `e2e` from that agent.

If `xcrun simctl list devices available` fails with `CoreSimulatorService
connection became invalid`, the process is not running with usable access to the
GUI user's CoreSimulator services. Start the job from the logged-in user session
or reconnect with a tool that preserves that session.
