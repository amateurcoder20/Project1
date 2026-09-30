# Knights vs Queens

Tic-tac-toe for Android. **Knights** (player 1) play against **Queens** (player 2 or a depth-limited minimax AI) on a low-poly 3D wood-and-marble board.

Choose **Classic** or **Courts**, a board, a series (Casual, Bo3, or Bo5), then **Local 2-Player** or **Vs AI**. Classic is the default and has no special powers.

| Board | Win |
| --- | --- |
| 3×3 | 3 in a row (Classic only; Courts starts on 5×5) |
| 5×5 | 4 in a row |
| 8×8 | 5 in a row |

**Courts** (5×5 or 8×8 only): each side may, once per game, replace that turn’s drop with a pair. Knights place two pieces a chess knight move apart (2×1). Queens place two pieces on diagonally touching squares — adjacent corners only, not a gap. Both squares must be empty. Arm the pair chip, tap the first square, tap a glowing landing, then confirm. Both squares are previewed before the pair is placed. If the first piece already finishes the line, the turn wins and the second piece is not placed. A normal drop is still any empty square. 3×3 has no pairs. Classic has no pairs.

**Crown War** keeps a Knights–Queens score for the session. Bo3 is first to 2, Bo5 is first to 3. After the game, the final board and winning line stay up. Score, Rematch, Restart, and Menu sit in a bottom sheet.

**Vs AI** rank: **Squire** (easy), **Marshal** (normal), **Regent** (harder search). You pick Knights or Queens; the AI takes the other side. Knights still move first, so a Queen player sees the AI open. Marshal and Regent spend their pair to win, to cover two threats, or to make two threats. Squire does not.

The match view frames the **full** board and pieces in the HUD-safe area (portrait). Earlier 4×4 builds clipped the near/far ranks; the camera is now more overhead, has no dutch tilt, and the 3D world is drawn in a SubViewport inset below the turn bar and above Restart/Menu.

This project is built in **Godot 4** (GDScript, Mobile renderer) so the same 3D scene can be edited on desktop and exported to Google Play as APK or AAB.

> The repo still contains a leftover bootstrap file named `Test File` on `main`. It is unused by the game and can be deleted later; it is left in place so this work does not block on it.

## Requirements

- [Godot 4.3 or newer](https://godotengine.org/download/) (developed against **4.7.2**)
- Standard (non-.NET) build — scripts are GDScript, not C#
- For Android export: Android SDK / Build-Tools, a JDK 17+, and Godot’s Android export templates matching your editor version

## How to play

1. On the title screen, leave **Classic** selected (or switch to **Courts**). Pick a board, a series, and an AI rank.
2. Choose **Local 2-Player** (hotseat; a pass-the-phone card appears, and **Skip handoffs** hides later ones) or **Vs AI**.
3. Tap an empty cell to drop a piece. Knights always move first. In Courts, the pair chip is **Knight pair** or **Queen pair** on that side’s turn. **How to play** on the menu, or **?** during a match, shows a normal place, then each pair.
4. Complete a straight line of the required length (horizontal, vertical, or diagonal) to win. A full board with no line is a draw.
5. In Vs AI, choose **You: Knights** or **You: Queens** before the match. The rank name shows while the AI thinks (Squire / Marshal / Regent).
6. **Rematch** starts the next game in the series. After a Bo3 or Bo5 is decided, Rematch starts a fresh series. **Restart** replays the current game without touching the score. **Menu** returns to the title. Android back goes Menu, then Quit.

## Get the APK on your phone (no computer)

This repo builds a **debug sideload APK** in GitHub Actions. It is for testing on a device, **not** for the Play Store (that still needs a release AAB and your upload keystore).

The package id is `com.amateurcoder20.project1`. The artifact is named **KnightsVsQueens-debug** and contains `KnightsVsQueens-debug.apk` (arm64-v8a, debug-signed with the Android debug key — no secrets in the repo).

### 1. Start a build

On your phone’s browser, stay logged in to GitHub as the repo owner (needed if the repo is private):

1. Open [https://github.com/amateurcoder20/Project1/actions](https://github.com/amateurcoder20/Project1/actions)
2. Tap **Build debug APK**
3. Tap **Run workflow** → branch **`test1`** → **Run workflow**  
   If you don’t see **Run workflow** yet, a build also starts automatically on every push to `test1`. Open the latest run from this page instead.

The first run can take **10–20 minutes** (it downloads Godot 4.7.2 export templates). Later runs reuse a cache and are faster.

### 2. Download the APK

1. Wait until the run is green (checkmark).
2. Open that run and scroll to **Artifacts**.
3. Tap **KnightsVsQueens-debug** to download. GitHub gives you a **zip**.
4. In Files / Downloads, unzip it. You should see `KnightsVsQueens-debug.apk`.

Artifacts are kept for **14 days**. Run the workflow again if it expired.

### 3. Install on Android

1. Tap the `.apk`.
2. If Android blocks it, allow **Install unknown apps** for **Files** or **Chrome** (Settings → Apps → Special app access → Install unknown apps).
3. Install, then open **Knights vs Queens**.

This debug APK will not pass Play review and should not be uploaded to the Play Console. Use the AAB preset on a machine with your release keystore for store builds.

## Open and run in the editor

1. Install Godot 4.3+ and open this folder with **Import** (or drag the folder onto the project manager).
2. The main scene is `scenes/main_menu.tscn`.
3. Press **F5** (Run Project). A portrait window (720×1280 logical, scaled) should open.
4. Click empty squares to place pieces. Touch works on phones; on desktop, left-click a cell.

Headless rules + AI checks (from this folder):

```bash
godot --headless --path . -s tests/test_game_logic.gd
```

## Architecture

| Piece | Role |
| --- | --- |
| `scripts/board_preset.gd` | The three size/win-length pairs |
| `scripts/game_logic.gd` | N×N board, legal moves, k-in-a-row / draw (no nodes) |
| `scripts/tic_tac_ai.gd` | AI for either faction. Squire / Marshal / Regent map onto search depth. Marshal+ may spend a Courts pair to win, block a fork, or create one |
| `scripts/courts_rules.gd` | Knight pair (2×1) and adjacent Queen pair. No pairs on 3×3 |
| `scripts/how_to_play.gd` | Reopenable three-step diagram: normal place, Knight pair, Queen pair |
| `scripts/piece_factory.gd` | Procedural low-poly knight (horse head) and queen (crown) |
| `scripts/board_view.gd` | Wood table, marble/wood squares, hover, pulsing power cells |
| `scripts/world_look.gd` | Warm lighting + camera framing so the whole board stays on-screen |
| `scripts/match_juice.gd` | Place squash’s tones and a short win sting (synthesized) |
| `scripts/main_menu.gd` / `game.gd` | Mode chips, side pick, match loop, pass-the-phone, result sheet |
| `scripts/game_session.gd` | Autoload: mode, board, series score, AI rank, human side |
| `scripts/player_prefs.gd` | First-run coach and the one-time Courts tutorial |

The 3D board and pieces are built at runtime from primitive meshes (boxes, cylinders, spheres). No external `.glb` assets are required.

Marshal is full-strength on 3×3, uses threat detection plus a few ply on 5×5, and neighborhood + shallow search on 8×8 so phones stay responsive. Squire searches one ply, does not block, and does not spend a pair. Regent adds about one ply on 5×5 and a slightly deeper 8×8 cap. The same ladder plays Knights or Queens.

## Android / Play Store export

Suggested identifiers (already set in `export_presets.cfg` and `project.godot`):

| Field | Value |
| --- | --- |
| App name | Knights vs Queens |
| Application id / package | `com.amateurcoder20.project1` |
| Version name | `1.0.0` |
| Version code | `1` |
| Orientation | Portrait (`screen/orientation=1`) |
| Min SDK | Template default for the debug APK; `24` on the Play AAB preset |
| Renderer | Mobile |
| Internet permission | Off (offline game) |

Placeholder launcher icons live in `assets/icons/` (192, 512, adaptive 432). Replace them with final art before a store listing. Play Console still needs a 512×512 icon and a 1024×500 feature graphic at upload time.

### One-time machine setup

1. In Godot: **Editor → Editor Settings → Export → Android**
   - Point **Android SDK Path** at your SDK (the folder that contains `platform-tools`).
   - Install a **JDK 17** and set **Java SDK Path** if Godot does not find it.
2. **Project → Install Android Build Template…**  
   Gradle builds (needed for AAB) unpack into `android/build/` (gitignored).
3. Download **Export Templates** for your exact Godot version: **Editor → Manage Export Templates**.

### Signing (high level)

- **Local debug APK:** Godot can use the debug keystore from Editor Settings. Fine for sideloading, not for Play.
- **Play upload:** create a dedicated upload keystore and **never commit it**.

```bash
keytool -genkey -v -keystore ~/keys/knights-vs-queens-upload.keystore \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

In the **Android Play Store AAB** preset, set:

- Release keystore path, user (alias), and password (or leave passwords to the OS keyring / CI secrets)
- Enable **Signed** (already on)

Google Play App Signing will re-sign the AAB with Google’s app key. Keep the upload keystore backed up; losing it means a Play support request to reset the upload key.

Do not put keystore files, aliases, or passwords in git. `*.keystore` is gitignored.

### Export

- **Sideload / internal testing:** use the GitHub Actions APK above, or Project → Export → **Android APK** → Export Project (debug).  
  Output: `build/android/KnightsVsQueens.apk` (arm64-v8a). The APK preset uses Godot’s export templates (Gradle off) so CI can sign a debug APK without an `android/build` tree.
- **Play Store:** Export → **Android Play Store AAB** → Export Project  
  Output: `build/android/KnightsVsQueens.aab`. This preset still uses a Gradle build. Upload that AAB in Play Console.

Command line (editor settings and templates must already be configured):

```bash
godot --headless --path . --export-release "Android APK" build/android/KnightsVsQueens.apk
godot --headless --path . --export-release "Android Play Store AAB" build/android/KnightsVsQueens.aab
```

### Play Console checklist (store-side, not in this repo)

- Package `com.amateurcoder20.project1` must be unique on Play; change it in the preset if the id is taken.
- Target API is whatever Godot’s Android gradle template uses for your editor (leave **Target SDK** blank to use the template default, which tracks Play’s requirement).
- Content rating, store listing, privacy policy if you later add networking. This MVP has no ads, IAP, analytics, or internet permission.
- Bump `version/code` by 1 for every Play upload; bump `version/name` when you want a user-visible version.

## Regenerating icons

```bash
python3 tools/gen_icons.py
```

## Scope

Offline play: Classic and Courts, local hotseat, vs AI, Crown War series, 3D board, Android export metadata. No online multiplayer, ads, or in-app purchases. Courts pairs are the adjacent double-place above; there is no Leap, Command, or gapped Queen diagonal.
