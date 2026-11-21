#!/usr/bin/env python3
"""Build the Mac adaptation without altering the Switch sources."""
from pathlib import Path
import concurrent.futures
import hashlib
import os
import re
import plistlib
import shlex
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
brew = shutil.which('brew')
if not brew and Path('/opt/homebrew/bin/brew').is_file():
    brew = '/opt/homebrew/bin/brew'
if not brew:
    raise SystemExit('Homebrew is required to build. Install Homebrew, then brew install sdl2-compat sdl3.')
brew_prefix = Path(subprocess.check_output([brew, '--prefix'], text=True).strip())
for library in ('libSDL2-2.0.0.dylib', 'libSDL3.0.dylib'):
    if not (brew_prefix / 'lib' / library).is_file():
        raise SystemExit('Missing SDL libraries. Run: brew install sdl2-compat sdl3')
for asset in ('fonts/Nunito.ttf', 'fonts/NotoSansSymbols.ttf', 'fonts/NotoSansSymbols2.ttf', 'sprites/pokemon_hd'):
    if not (root / 'romfs' / asset).exists():
        raise SystemExit('Missing generated artwork/fonts. Follow the asset preparation steps in README.md.')
port = root / 'tools/mac'
build = root / 'build-mac'
build.mkdir(exist_ok=True)
shims = port / 'hostnx'
framebuffer = (root / 'src/UI/PKSEFramebuffer.cpp').read_text().replace('SDL_GL_CONTEXT_MAJOR_VERSION, 4', 'SDL_GL_CONTEXT_MAJOR_VERSION, 3').replace('SDL_GL_CONTEXT_MINOR_VERSION, 3', 'SDL_GL_CONTEXT_MINOR_VERSION, 2').replace('SDL_CreateWindow("PKSE"', 'SDL_CreateWindow("pokesavreditr"')
(build / 'PKSEFramebuffer.cpp').write_text(framebuffer)
saveSource = (root / 'src/Save/GetSaveFileContents.cpp').read_text().replace('bool saveTrainerInfo(Trainer::Trainer &trainer,', 'bool saveTrainerInfoOriginal(Trainer::Trainer &trainer,')
saveSource = saveSource.replace('namespace Save\n{', 'namespace Save\n{\n    bool macNeedsPokedexUpdate(Trainer::Trainer &trainer);', 1).replace('trainer.updatePokedexBlock();', 'if (macNeedsPokedexUpdate(trainer)) trainer.updatePokedexBlock();')
(build / 'GetSaveFileContents.cpp').write_text(saveSource)
stubs = (root / 'tools/harness/uihost/HostStubs.cpp').read_text()
files = '#include <cstdio>\n#include <chrono>\n#include <ctime>\n#include <filesystem>\n#include <system_error>\n#include "Utils/FileUtilities.h"\n#include "Utils/HelperUtilities.h"\nnamespace Utils {\n' + stubs[stubs.index('    uint8_t *readAllBytes('):stubs.index('// SCRIPTED rather')]
files = files.replace('return "20260101_000000";', 'char timestamp[64]; const time_t now = time(nullptr); strftime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S", localtime(&now)); return std::string(timestamp) + "-" + std::to_string(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::system_clock::now().time_since_epoch()).count());')
files = files.replace('bool restoreBackupToTitle(AccountUid, u64, const char *, const char *)', 'bool restoreBackupToTitle(AccountUid, u64, const char *, const std::string &, const std::vector<std::string> &)')
(build / 'MacFiles.cpp').write_text(files)
compatibleInclude = build / 'include'
for header in (root / 'include').rglob('*'):
    if not header.is_file():
        continue
    destination = compatibleInclude / header.relative_to(root / 'include')
    destination.parent.mkdir(parents=True, exist_ok=True)
    if header.suffix == '.h' and 'Libs' not in header.parts:
        content = re.sub(r'(?<![:\w])(Pokemon|Trainer)::', r'::\1::', header.read_text())
        content = content.replace('namespace ::', 'namespace ').replace('::Trainer::swapBoxSlots', 'Trainer::swapBoxSlots')
        destination.write_text(content)
    else:
        shutil.copy2(header, destination)
sources = []
for folder in ('Pokemon','Names','Enums','Encryption','Legality','Conversion','Trainer'):
    sources.extend(sorted((root / 'src' / folder).glob('*.cpp')))
for name in ('EventLog','HelperUtilities','Logger','MD5','SHA256','Settings','StringHelpers'):
    sources.append(root / f'src/Utils/{name}.cpp')
for name in ('TrainerViewScreen','BackupSelectionScreen','SpriteManager','ListSearch','TouchInput'):
    sources.append(root / f'src/UI/{name}.cpp')
for folder in ('Panels','Dialogs','Modals'):
    sources.extend(sorted((root / 'src/UI' / folder).glob('*.cpp')))
sources.extend([root / 'src/Save/Block.cpp', root / 'src/Save/SaveEnvelope.cpp', build / 'GetSaveFileContents.cpp', build / 'MacFiles.cpp', build / 'PKSEFramebuffer.cpp',port / 'MacMain.mm'])
flags = ['-std=c++20','-O2','-fno-rtti','-fno-exceptions','-Wall','-Wno-deprecated-declarations','-Wno-unused-parameter','-include','cstdint','-include','cstddef','-include','Globals.h','-I'+str(shims),'-I'+str(compatibleInclude),'-I'+str(compatibleInclude/'UI'),'-I'+str(root/'nanovg'),'-I'+str(root/'memecrypto'),'-I'+str(brew_prefix/'include'),'-DGL_SILENCE_DEPRECATION']
objects = []
def compile_source(source):
    sourceText = source.read_text()
    sourceText = re.sub(r'(?<![:\w])(Pokemon|Trainer)::', r'::\1::', sourceText)
    sourceText = sourceText.replace('::Pokemon::GEOLOCATION_SLOT_COUNT', '::Pokemon::Pokemon::GEOLOCATION_SLOT_COUNT')
    sourceText = sourceText.replace('namespace ::', 'namespace ').replace('Written to backup', 'Saved file')
    compatible = build / (hashlib.sha256(str(source).encode()).hexdigest()[:12] + source.suffix)
    compatible.write_text(sourceText)
    target = compatible.with_suffix('.o')
    stamp = target.with_suffix('.key')
    fingerprint = hashlib.sha256((sourceText + repr(flags)).encode()).hexdigest()
    if target.exists() and stamp.exists() and stamp.read_text() == fingerprint:
        return target
    result = subprocess.run(['clang++',*flags,'-c',str(compatible),'-o',str(target)],capture_output=True,text=True)
    (build / (target.stem+'.log')).write_text(result.stdout+result.stderr)
    if result.returncode:
        print(str(source)+'\n'+'\n'.join(line for line in result.stderr.splitlines() if 'error:' in line),flush=True)
        raise RuntimeError('Compile failed')
    stamp.write_text(fingerprint)
    return target
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
    for completed, target in enumerate(executor.map(compile_source,sources),1):
        objects.append(target)
        if completed % 30 == 0: print(f'Compiled {completed}/{len(sources)}',flush=True)
for source in sorted((root/'memecrypto').glob('*.c')):
    target=build/(source.stem+'.o')
    subprocess.run(['clang','-O2','-I'+str(root/'memecrypto'),'-c',str(source),'-o',str(target)],check=True)
    objects.append(target)
nanovg=build/'nanovg.o'
subprocess.run(['clang','-O2','-DNVG_NO_STB','-I'+str(root/'nanovg'),'-c',str(root/'nanovg/nanovg.c'),'-o',str(nanovg)],check=True)
objects.append(nanovg)
backend = build / 'nanovg_gl_impl.o'
subprocess.run(['clang','-O2','-DGL_SILENCE_DEPRECATION','-I'+str(shims),'-I'+str(root/'nanovg'),'-c',str(root/'nanovg/nanovg_gl_impl.c'),'-o',str(backend)],check=True)
objects.append(backend)
app=root/'dist/pokesavreditr.app'
mac=app/'Contents/MacOS';resources=app/'Contents/Resources';frameworks=app/'Contents/Frameworks'
for folder in (mac,resources,frameworks): folder.mkdir(parents=True,exist_ok=True)
subprocess.run(['clang++',*[str(target) for target in objects],'-L'+str(brew_prefix/'lib'),'-lSDL2','-framework','Cocoa','-framework','OpenGL','-o',str(mac/'pokesavreditr')],check=True)
(frameworks/'libSDL2-2.0.0.dylib').unlink(missing_ok=True)
shutil.copy2(brew_prefix/'lib/libSDL2-2.0.0.dylib',frameworks/'libSDL2-2.0.0.dylib')
dependencies = subprocess.check_output(['otool', '-L', str(mac/'pokesavreditr')], text=True)
for dependency in dependencies.splitlines()[1:]:
    dependency = dependency.strip().split(' (', 1)[0]
    if 'libSDL2' in dependency:
        subprocess.run(['install_name_tool', '-change', dependency, '@executable_path/../Frameworks/libSDL2-2.0.0.dylib', str(mac/'pokesavreditr')], check=True)
(frameworks/'libSDL3.dylib').unlink(missing_ok=True)
shutil.copy2(brew_prefix/'lib/libSDL3.0.dylib',frameworks/'libSDL3.dylib')
subprocess.run(['install_name_tool','-id','@loader_path/libSDL3.dylib',str(frameworks/'libSDL3.dylib')],check=True)
shutil.copytree(root/'romfs',resources/'romfs',dirs_exist_ok=True)
(resources/'LICENSE').write_text((root/'LICENSE').read_text())
shutil.copy2(root/'NOTICE.md', resources/'NOTICE.md')
info={'CFBundleExecutable':'pokesavreditr','CFBundleIdentifier':'io.github.abhinavkumars1ngh.pokesavreditr','CFBundleName':'pokesavreditr','CFBundleDisplayName':'pokesavreditr','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','NSHighResolutionCapable':True,'LSMinimumSystemVersion':'14.0'}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
print('Built '+str(app),flush=True)
