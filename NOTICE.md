# Attribution and local modifications

**pokesavreditr** is Abhinav Kumar Singh's personal macOS adaptation of
[PKSE by kiasta and contributors](https://github.com/kiasta/PKSE). It includes
PKSE's editor, generated game tables, save handling and cryptography. The
original application and those components were not written from scratch for
this project. The supplied PKSE-master snapshot did not contain Git history;
its exact upstream commit is unknown.

Mac adaptation and publication changes, November 2026:

- Cocoa/SDL desktop entry point, Mac compatibility headers and OpenGL setup.
- Direct Legends: Z-A save access, verified backups, changed-file detection
  and protection against writing while the game is running.
- A Mac app build helper that bundles SDL libraries and generated artwork.
- pokesavreditr app naming, bundle identity, documentation and repository setup.

The original PKSE documentation is retained in [docs/UPSTREAM-README.md](docs/UPSTREAM-README.md).
The project retains the GNU Affero General Public License v3.0 in [LICENSE](LICENSE).
Existing copyright and license notices remain in the source.

PKSE also credits PKHeX, PKSM, PokeAPI, devkitPro/libnx, NanoVG, stb_image,
memecrypto and the Nunito/Noto font authors. Vendored components retain their
own notices and licenses; see the upstream README, `memecrypto/LICENSE`,
`nanovg/` and the generated font license files. Pokémon names and artwork
belong to their respective owners. No game packages, console keys, personal
saves or backups are included in this repository.
