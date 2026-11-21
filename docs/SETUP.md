# Setup guide

pokesavreditr is a Pokémon save editor for Nintendo Switch games. The Switch
release runs on a homebrew-enabled console. The native Mac app currently opens
Pokémon Legends: Z-A saves. Windows and Linux can prepare the SD card or build
the Switch app; native Windows/Linux desktop versions are not included.

## Nintendo Switch — install the ready-made app

1. Download `pokesavreditr-1.0.0-switch.zip` from
   [Releases](https://github.com/abhinavkumars1ngh/pokesavreditr/releases).
2. Extract the ZIP on your computer. Copy its `switch` folder to the root of
   your Switch SD card. The resulting file should be:
   `/switch/pokesavreditr/pokesavreditr.nro`.
3. Put the SD card back into a Switch already configured to run homebrew.
4. Hold **R** while launching a game to open the Homebrew Menu through title
   override, then launch **pokesavreditr**. This gives the editor more memory
   than Album applet mode.
5. Choose the user, game and save backup to edit. Create a backup first.

Fonts and artwork are inside the `.nro`; they do not need a separate download.
The editor does not include games, saves or console keys. It does not set up
homebrew on an unmodified console.

After changing a Pokémon, press **X** to keep the edit. Return to the main menu
and use **X / Save** to write the file, choosing the intended destination.
Backups, settings and the bank use `sdmc:/PKSE/` for compatibility.

## macOS — build and open the native app

Requirements: Apple silicon, Xcode command-line tools, Homebrew and Python 3.
The app declares macOS 14 as its minimum; Intel Macs have not been validated.

In Terminal:

```bash
git clone https://github.com/abhinavkumars1ngh/pokesavreditr.git
cd pokesavreditr
xcode-select --install  # skip if already installed
brew install sdl2-compat sdl3
python3 -m venv .venv
source .venv/bin/activate
python -m pip install Pillow
python tools/gen_fonts.py
python tools/gen_typeicons.py
python tools/gen_marks.py
python tools/gen_ribbons.py
python tools/gen_hdsprites.py
python tools/mac/BuildMac.py
open dist/pokesavreditr.app
```

The resulting app bundles its runtime libraries and assets. It uses a local
ad-hoc signature and is not notarized. You can move the built `.app` elsewhere
on the same Mac.

The default Legends: Z-A save is:

```text
~/Library/Application Support/nxnative/0100F43008C44000/save/main
```

To select a different Legends: Z-A save, put its `main` file in a save folder:

```bash
open dist/pokesavreditr.app --args --save "/path/to/save/main"
```

Quit the game before writing edits. **J** confirms, **K** goes back, **U** is
X/save, and arrow keys navigate. Save the Pokémon edit with **U**, then return
to the main menu and use **U**, **J** to save the file. Verified backups are
written into `PKSE Backups/` beside the save folder.

## Windows — install on Switch or build the Switch app

To install the ready-made Switch release, use File Explorer to extract the ZIP
and copy its `switch` folder onto the SD card. Follow the Switch steps above.
The `.nro` does not run as a Windows desktop application.

For a source build:

1. Follow [devkitPro's Getting Started guide](https://devkitpro.org/wiki/Getting_Started)
   and select **Switch Development** in its Windows installer.
2. Install Git and Python 3 with Pillow, then clone this repository.
3. Open the **devkitPro MSys2 shell**, enter the repository and install the
   required packages:

   ```bash
   pacman -S --needed switch-dev switch-sdl2 switch-glad switch-lz4
   ```

4. Run the five asset scripts shown below, then `make -j2` in that same shell.
   Use `python` instead of `python3` if that is your Python command.

## Linux — install on Switch or build the Switch app

To install the ready-made release, extract the ZIP with your archive manager
and copy its `switch` folder onto the SD card. Follow the Switch steps above.
There is no native Linux desktop executable in this release.

For a source build, follow the official
[devkitPro pacman instructions](https://github.com/devkitPro/pacman/releases/latest)
for your distribution. Install Git, Make, Python 3 and Pillow, clone this
repository, then install:

```bash
sudo dkp-pacman -S --needed switch-dev switch-sdl2 switch-glad switch-lz4
export DEVKITPRO=/opt/devkitpro
```

Arch-based systems configured with devkitPro repositories use `sudo pacman`
instead of `sudo dkp-pacman`. Follow the official distribution-specific setup;
do not manually extract Debian packages on other distributions.

## Asset preparation and Switch build

From the repository root on Windows, Linux or macOS with devkitPro installed:

```bash
python3 tools/gen_fonts.py
python3 tools/gen_typeicons.py
python3 tools/gen_marks.py
python3 tools/gen_ribbons.py
python3 tools/gen_hdsprites.py
make -j2
```

Pillow is required by the sprite script. Use a Python virtual environment if
your system Python requires one. If `DEVKITPRO` is empty, open a new devkitPro
shell or set it to your installation directory.

The output is `pokesavreditr.nro`. Copy it to
`/switch/pokesavreditr/pokesavreditr.nro` on the SD card. The GitHub Actions
workflow also builds this output using devkitPro's official Docker image.

## Other platforms

Android and iOS apps are not currently provided. A `.nro` is a Nintendo Switch
homebrew executable; renaming it to `.exe`, `.app` or another extension does
not make it run on a different platform.

License and original contributor credits: [NOTICE.md](../NOTICE.md) and
[LICENSE](../LICENSE).
