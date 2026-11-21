# pokesavreditr for Nintendo Switch

pokesavreditr is a **Pokémon save editor for Nintendo Switch games**, with
party/box editing, trainer and item tools, backups, and dark/light themes.

For Mac, Windows and Linux instructions, see [the setup guide](SETUP.md).

## Install

1. Use a Nintendo Switch already configured to run homebrew.
2. Copy the included `switch/pokesavreditr/pokesavreditr.nro` to the matching
   folder on your SD card: `/switch/pokesavreditr/pokesavreditr.nro`.
3. Open the Homebrew Menu through title override: hold **R** while starting
   a game. The editor needs the extra memory this provides.
4. Launch **pokesavreditr**, choose the user and game, then create or open a backup.

The `.nro` bundles its required fonts and artwork. No NSP installation, game
packages or console keys are part of this editor download.

## Edit and save

Use the on-screen controller hints. Open a Pokémon, change its level or another
field, and press **X** to keep the Pokémon edit. Return to the main menu and use
**X / Save** to write the file, selecting the intended destination.

Backups, settings, exports and bank files retain the original `sdmc:/PKSE/`
location for compatibility. The app name change does not move or delete them.
Keep a separate backup before editing. Illegal values are informationally
flagged; the editor does not guarantee that edited Pokémon are legitimate.

The Switch build is compiled in GitHub Actions. No physical-console testing was
performed for this release.

Source: https://github.com/abhinavkumars1ngh/pokesavreditr
Upstream PKSE: https://github.com/kiasta/PKSE

## Build from source

Install devkitPro using its official setup instructions, then install:

```bash
dkp-pacman -S switch-dev switch-sdl2 switch-glad switch-lz4
export DEVKITPRO=/opt/devkitpro
```

The package manager may require `sudo`; Windows uses devkitPro's MSys2 `pacman`.
With Python 3 and Pillow installed, fetch all five asset sets:

```bash
python3 tools/gen_fonts.py
python3 tools/gen_typeicons.py
python3 tools/gen_marks.py
python3 tools/gen_ribbons.py
python3 tools/gen_hdsprites.py
make -j2
```

The production output is `pokesavreditr.nro`. The optional development build is
`make BUILD_TYPE=development` and produces `pokesavreditr-dev.nro`.
