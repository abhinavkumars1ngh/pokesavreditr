# pokesavreditr

A **Pokémon save editor for Nintendo Switch games**. Edit party and box
Pokémon, levels, moves, stats, trainer details and items through a controller-friendly
interface with automatic backups and dark/light themes.

Maintained by [Abhinav Kumar Singh](https://github.com/abhinavkumars1ngh).

## Platforms and setup

| Platform | How to use it |
| --- | --- |
| Nintendo Switch | Download the `.nro` release and launch through the Homebrew Menu. |
| macOS | Build the native `.app`; the desktop save workflow currently targets Legends: Z-A. |
| Windows / Linux | Download and copy the Switch release to an SD card, or build the Switch `.nro`. Native desktop apps are not available. |
| Android / iOS | No native app is currently provided. |

Follow the [complete setup guide](docs/SETUP.md) for platform-specific steps.

## Nintendo Switch app

Download the Switch package from [Releases](https://github.com/abhinavkumars1ngh/pokesavreditr/releases).
The production Switch homebrew file is **pokesavreditr.nro**. Copy it to
`/switch/pokesavreditr/` on a homebrew-enabled Switch and launch it from the
Homebrew Menu through title override (hold **R** while starting a game).

See [Switch installation and building](docs/SWITCH-INSTALL.md). Fonts and artwork
are bundled. Backups and banks use `sdmc:/PKSE/` for compatibility. The interface
has teal accents, dark and light themes, and blue charcoal dark surfaces.

The [Switch build workflow](.github/workflows/build-switch.yml) compiles the
production `.nro` and uploads an installable `pokesavreditr-switch` artifact.
Physical-console testing has not been performed for this release.

## Mac features

- Edit party and box Pokémon.
- Open the local Legends: Z-A save automatically, or specify a save file.
- Create and verify a timestamped backup before each write.
- Refuse writes if the game is running or the save changed after opening.
- Use mouse controls or a keyboard mapped to the editor's Switch buttons.
- Bundle SDL and the generated UI assets in a movable `.app`.

The Mac save workflow targets Legends: Z-A. Other games, console save management
and every advanced feature have not all been validated on Mac. No game, save
or keys are supplied.

## Build on macOS

The tested setup is Apple silicon with Xcode command-line tools, Python 3 and
Homebrew. The app declares macOS 14 as its minimum; older Macs and Intel Macs
have not been validated.

```bash
git clone https://github.com/abhinavkumars1ngh/pokesavreditr.git
cd pokesavreditr
xcode-select --install  # skip if command-line tools are already installed
brew install sdl2-compat sdl3
python3 -m venv .venv
source .venv/bin/activate
python -m pip install Pillow
```

Fetch the generated fonts and artwork once. These scripts download upstream
assets; the HOME sprites are the largest download.

```bash
python tools/gen_fonts.py
python tools/gen_typeicons.py
python tools/gen_marks.py
python tools/gen_ribbons.py
python tools/gen_hdsprites.py
python tools/mac/BuildMac.py
open dist/pokesavreditr.app
```

The output is `dist/pokesavreditr.app`, signed locally with an ad-hoc signature.
It is not notarized. Rebuilding needs the development tools; the finished app
bundles its runtime libraries. Generated assets and build products are ignored
by Git. Switch and Mac builds have separate outputs.

## Open and edit a save

Quit the game before saving edits. By default, the Mac app reads:

```text
~/Library/Application Support/nxnative/0100F43008C44000/save/main
```

For another Legends: Z-A save, name the file `main` in its own save folder and run:

```bash
open dist/pokesavreditr.app --args --save "/path/to/save/main"
```

To change a level: open a Pokémon, edit **Level**, then press **U** to keep that
Pokémon's changes. Return to the main menu with **K**, press **U** again, and
confirm with **J** to write the save. Editing a Pokémon and saving the file are
two separate steps.

Backups are stored in `PKSE Backups/` beside the save folder. To restore one,
quit the game and editor, copy a backup into the save folder, and name the copy
`main`. The original `~/Library/Application Support/PKSE/` settings/bank location
is retained for compatibility.

| Mac key | Editor control |
| --- | --- |
| Arrow keys | Navigate |
| J / K | A: confirm / B: back |
| U / I | X: save / Y |
| Q / E | L / R |
| Z / C | ZL / ZR |
| Return / Tab | Plus / Minus |

## Verify changes safely

The built-in save verification command performs a round trip and changes one
Pokémon's level. **Use a disposable copy**, never the only copy of a save:

```bash
mkdir -p /tmp/pokesavreditr-test/save
cp "/path/to/save/main" /tmp/pokesavreditr-test/save/main
dist/pokesavreditr.app/Contents/MacOS/pokesavreditr \
  --verify-save /tmp/pokesavreditr-test/save/main
cat /tmp/pokesavreditr-test/save/verification.json
```

## License

[GNU AGPL v3.0](LICENSE). Original PKSE and third-party credits and license
notices are preserved. See [credits and notices](NOTICE.md) and the
[original PKSE documentation](docs/UPSTREAM-README.md).
