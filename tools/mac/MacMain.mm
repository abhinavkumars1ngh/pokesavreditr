#include "Encryption/Encryption.h"
#include "Globals.h"
#include "Save/GetSaveFileContents.h"
#include "Trainer/Trainer9LZA.h"
#include "UI/TouchInput.h"
#include "UI/TrainerViewScreen.h"
#include "Utils/FileUtilities.h"
#include "Utils/Keyboard.h"
#include "Utils/Settings.h"
#include <Cocoa/Cocoa.h>
#include <OpenGL/gl3.h>
#include <SDL2/SDL.h>
#include <algorithm>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <set>
#include <sstream>
#include <unistd.h>

namespace
{
std::string g_savePath;
std::vector<uint8_t> g_originalSaveBytes;
bool g_verification = false;

std::vector<uint8_t> readFile(const std::string &filePath)
{
    std::ifstream inputFile(filePath, std::ios::binary);
    return {std::istreambuf_iterator<char>(inputFile), std::istreambuf_iterator<char>()};
}

void showMessage(const std::string &message)
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"pokesavreditr";
    alert.informativeText = [NSString stringWithUTF8String:message.c_str()];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

bool gameIsRunning()
{
    return [NSRunningApplication runningApplicationsWithBundleIdentifier:@"org.nxnative.0100f43008c44000"].count > 0;
}
} // namespace

namespace Save
{
bool saveTrainerInfoOriginal(Trainer::Trainer &, const char *, u64, AccountUid, bool);

bool macNeedsPokedexUpdate(Trainer::Trainer &trainer)
{
    auto originalTrainer = readTitleSaveAsTrainer(std::filesystem::path(g_savePath).parent_path().c_str(), 0x0100F43008C44000ULL);
    if (!originalTrainer)
    {
        return false;
    }
    auto identities = [](const Trainer::Trainer &sourceTrainer)
    {
        std::set<uint64_t> signatures;
        auto remember = [&](const Pokemon::Pokemon *pokemon)
        {
            if (!pokemon || pokemon->speciesID() == 0 || pokemon->isEgg())
            {
                return;
            }
            const uint64_t signature = pokemon->speciesID() | (static_cast<uint64_t>(pokemon->form()) << 16) | (static_cast<uint64_t>(pokemon->gender()) << 24) | (static_cast<uint64_t>(pokemon->language()) << 32) | (static_cast<uint64_t>(pokemon->isShiny(pokemon->id32(), pokemon->species())) << 40) | (static_cast<uint64_t>(pokemon->isAlpha()) << 41);
            signatures.insert(signature);
        };
        for (const auto &pokemon : sourceTrainer.party)
        {
            remember(pokemon.get());
        }
        for (const auto &box : sourceTrainer.boxes)
        {
            for (const auto &pokemon : box)
            {
                remember(pokemon.get());
            }
        }
        return signatures;
    };
    const auto originalIdentities = identities(*originalTrainer);
    for (const uint64_t signature : identities(trainer))
    {
        if (originalIdentities.find(signature) == originalIdentities.end())
        {
            return true;
        }
    }
    return false;
}

bool saveTrainerInfo(Trainer::Trainer &trainer, const char *, u64, AccountUid, bool)
{
    if (!g_verification && gameIsRunning())
    {
        showMessage("Quit Pokémon Legends: Z-A before saving edits. The game can overwrite changes while it is running.");
        return false;
    }
    if (readFile(g_savePath) != g_originalSaveBytes)
    {
        showMessage("The save changed since pokesavreditr opened it. Quit and reopen pokesavreditr to load the latest progress.");
        return false;
    }
    const auto saveDirectory = std::filesystem::path(g_savePath).parent_path();
    const auto stageDirectory = saveDirectory / (".pkse-stage-" + std::to_string(getpid()));
    std::error_code errorCode;
    std::filesystem::create_directories(stageDirectory, errorCode);
    if (errorCode)
    {
        return false;
    }
    if (!saveTrainerInfoOriginal(trainer, stageDirectory.c_str(), 0x0100F43008C44000ULL, AccountUid{}, false))
    {
        return false;
    }
    auto checkTrainer = readTitleSaveAsTrainer(stageDirectory.c_str(), 0x0100F43008C44000ULL);
    if (!checkTrainer || !checkTrainer->isValid())
    {
        return false;
    }
    const auto stagedBytes = readFile((stageDirectory / "main").string());
    if (stagedBytes.empty())
    {
        return false;
    }
    const auto backupDirectory = saveDirectory.parent_path() / "PKSE Backups";
    std::filesystem::create_directories(backupDirectory, errorCode);
    if (errorCode)
    {
        return false;
    }
    const auto backupPath = backupDirectory / (Utils::getTimestamp() + "-" + std::to_string(getpid()) + ".main");
    if (!std::filesystem::copy_file(g_savePath, backupPath, std::filesystem::copy_options::none, errorCode))
    {
        return false;
    }
    if (readFile(backupPath.string()) != g_originalSaveBytes)
    {
        return false;
    }
    if (rename((stageDirectory / "main").c_str(), g_savePath.c_str()) != 0)
    {
        return false;
    }
    std::filesystem::remove(stageDirectory, errorCode);
    g_originalSaveBytes = stagedBytes;
    return true;
}
} // namespace Save

namespace Utils
{
KeyboardResult promptText(const std::string &header, const std::string &guide, const std::string &initial, int maxChars, const std::function<void(const std::string &)> &textChanged)
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithUTF8String:header.c_str()];
    alert.informativeText = [NSString stringWithUTF8String:guide.c_str()];
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 340, 26)];
    textField.stringValue = [NSString stringWithUTF8String:initial.c_str()];
    alert.accessoryView = textField;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert.window setInitialFirstResponder:textField];
    KeyboardResult keyboardResult;
    keyboardResult.accepted = [alert runModal] == NSAlertFirstButtonReturn;
    if (keyboardResult.accepted)
    {
        NSString *enteredText = textField.stringValue;
        if (maxChars > 0 && enteredText.length > static_cast<NSUInteger>(maxChars))
        {
            enteredText = [enteredText substringToIndex:maxChars];
        }
        keyboardResult.text = enteredText.UTF8String;
        if (textChanged)
        {
            textChanged(keyboardResult.text);
        }
    }
    SDL_PumpEvents();
    return keyboardResult;
}
KeyboardResult promptSystemText(const std::string &header, const std::string &guide, const std::string &initial, int maxChars)
{
    return promptText(header, guide, initial, maxChars, nullptr);
}
NumberResult promptNumber(const std::string &header, int initialValue, int minValue, int maxValue)
{
    NumberResult numberResult;
    const auto keyboardResult = promptText(header, "Enter a number from " + std::to_string(minValue) + " to " + std::to_string(maxValue), std::to_string(initialValue), 12, nullptr);
    if (!keyboardResult.accepted)
    {
        return numberResult;
    }
    char *endPointer = nullptr;
    const long enteredValue = strtol(keyboardResult.text.c_str(), &endPointer, 10);
    if (keyboardResult.text.empty() || *endPointer || enteredValue < minValue || enteredValue > maxValue)
    {
        showMessage("That number is outside the allowed range. No change was made.");
        return numberResult;
    }
    numberResult.accepted = true;
    numberResult.value = static_cast<int>(enteredValue);
    return numberResult;
}
int keyboardPromptsSuppressed()
{
    return 0;
}
void resetKeyboardSuppressionCount()
{
}
} // namespace Utils

int main(int argumentCount, char **arguments)
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        const char *homeDirectory = getenv("HOME");
        g_savePath = std::string(homeDirectory) + "/Library/Application Support/nxnative/0100F43008C44000/save/main";
        g_verification = argumentCount > 2 && std::string(arguments[1]) == "--verify-save";
        const bool uiTest = argumentCount > 2 && std::string(arguments[1]) == "--ui-test";
        if (g_verification || uiTest)
        {
            g_savePath = arguments[2];
        }
        if (argumentCount > 2 && std::string(arguments[1]) == "--save")
        {
            g_savePath = arguments[2];
        }
        g_originalSaveBytes = readFile(g_savePath);
        if (g_originalSaveBytes.empty())
        {
            showMessage("No Pokémon Legends: Z-A save was found at " + g_savePath);
            return 1;
        }
        auto trainer = Save::readTitleSaveAsTrainer(std::filesystem::path(g_savePath).parent_path().c_str(), 0x0100F43008C44000ULL);
        if (!trainer || !trainer->isValid())
        {
            showMessage("This save could not be read. The file has not been changed.");
            return 1;
        }
        if (g_verification)
        {
            auto unchangedSaveBytes = g_originalSaveBytes;
            if (!Save::saveTrainerInfo(*trainer, nullptr, 0, AccountUid{}, false))
            {
                return 2;
            }
            if (readFile(g_savePath) != unchangedSaveBytes)
            {
                auto beforeBlocks = Encryption::decrypt(unchangedSaveBytes.data(), unchangedSaveBytes.size());
                auto afterBytes = readFile(g_savePath);
                auto afterBlocks = Encryption::decrypt(afterBytes.data(), afterBytes.size());
                std::ofstream report(std::filesystem::path(g_savePath).parent_path() / "roundtrip.txt");
                for (size_t blockIndex = 0; blockIndex < beforeBlocks.size(); ++blockIndex)
                {
                    if (beforeBlocks[blockIndex].data != afterBlocks[blockIndex].data)
                    {
                        report << std::hex << beforeBlocks[blockIndex].key << " bytes " << beforeBlocks[blockIndex].data.size() << " -> " << afterBlocks[blockIndex].data.size() << " offsets ";
                        int shownCount = 0;
                        for (size_t byteOffset = 0; byteOffset < std::min(beforeBlocks[blockIndex].data.size(), afterBlocks[blockIndex].data.size()); ++byteOffset)
                        {
                            if (beforeBlocks[blockIndex].data[byteOffset] != afterBlocks[blockIndex].data[byteOffset] && shownCount++ < 12)
                            {
                                report << byteOffset << " ";
                            }
                        }
                        report << "\n";
                    }
                }
                return 3;
            }
            auto reopenedTrainer = Save::readTitleSaveAsTrainer(std::filesystem::path(g_savePath).parent_path().c_str(), 0x0100F43008C44000ULL);
            if (reopenedTrainer->party.empty())
            {
                return 4;
            }
            const int originalLevel = reopenedTrainer->party[0]->level();
            const int targetLevel = originalLevel < 100 ? originalLevel + 1 : 99;
            reopenedTrainer->party[0]->setLevel(targetLevel);
            reopenedTrainer->party[0]->recalculateStats();
            reopenedTrainer->party[0]->refreshChecksum();
            if (!Save::saveTrainerInfo(*reopenedTrainer, nullptr, 0, AccountUid{}, false))
            {
                return 5;
            }
            auto editedTrainer = Save::readTitleSaveAsTrainer(std::filesystem::path(g_savePath).parent_path().c_str(), 0x0100F43008C44000ULL);
            std::ofstream report(std::filesystem::path(g_savePath).parent_path() / "verification.json");
            const bool levelPersisted = editedTrainer && editedTrainer->party[0]->level() == targetLevel;
            report << "{\"unchanged_roundtrip\":true,\"original_level\":" << originalLevel << ",\"edited_level\":" << targetLevel << ",\"level_persisted\":" << (levelPersisted ? "true" : "false") << "}\n";
            return levelPersisted ? 0 : 6;
        }
        const NSString *resourcePath = NSBundle.mainBundle.resourcePath;
        std::error_code errorCode;
        const auto supportDirectory = std::filesystem::path(homeDirectory) / "Library/Application Support/PKSE";
        std::filesystem::create_directories(supportDirectory, errorCode);
        std::filesystem::current_path(supportDirectory, errorCode);
        if (std::filesystem::is_symlink("romfs:", errorCode))
        {
            std::filesystem::remove("romfs:", errorCode);
        }
        errorCode.clear();
        std::filesystem::create_directory_symlink(std::filesystem::path(resourcePath.UTF8String) / "romfs", "romfs:", errorCode);
        errorCode.clear();
        std::filesystem::create_directory_symlink(supportDirectory, "sdmc:", errorCode);
        Utils::loadSettings();
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0)
        {
            showMessage(SDL_GetError());
            return 1;
        }
        {
            UI::PKSEFramebuffer framebuffer;
            UI::TrainerViewScreen trainerScreen(*trainer, "Pokémon Legends: Z-A", g_savePath, 0, AccountUid{}, false);
            UI::TouchInput touch;
            PadState pad;
            bool running = true;
            int frameIndex = 0;
            std::ofstream uiReport;
            if (uiTest)
            {
                uiReport.open(std::filesystem::path(g_savePath).parent_path() / "route.log");
            }
            [NSApp activateIgnoringOtherApps:YES];
            while (running && !trainerScreen.shouldExit() && !trainerScreen.hasRequestedExit())
            {
                SDL_Event event;
                while (SDL_PollEvent(&event))
                {
                    if (event.type == SDL_QUIT)
                    {
                        NSAlert *alert = [[NSAlert alloc] init];
                        alert.messageText = @"Close pokesavreditr?";
                        alert.informativeText = @"Use the editor's Save option to keep edits before closing.";
                        [alert addButtonWithTitle:@"Keep editing"];
                        [alert addButtonWithTitle:@"Close without saving"];
                        if ([alert runModal] == NSAlertSecondButtonReturn)
                        {
                            running = false;
                        }
                    }
                }
                const Uint8 *keyboard = SDL_GetKeyboardState(nullptr);
                pad.buttons_old = pad.buttons_cur;
                pad.buttons_cur = 0;
                const std::pair<SDL_Scancode, u64> bindings[] = {{SDL_SCANCODE_J, HidNpadButton_A}, {SDL_SCANCODE_K, HidNpadButton_B}, {SDL_SCANCODE_U, HidNpadButton_X}, {SDL_SCANCODE_I, HidNpadButton_Y}, {SDL_SCANCODE_Q, HidNpadButton_L}, {SDL_SCANCODE_E, HidNpadButton_R}, {SDL_SCANCODE_Z, HidNpadButton_ZL}, {SDL_SCANCODE_C, HidNpadButton_ZR}, {SDL_SCANCODE_RETURN, HidNpadButton_Plus}, {SDL_SCANCODE_TAB, HidNpadButton_Minus}, {SDL_SCANCODE_LEFT, HidNpadButton_Left}, {SDL_SCANCODE_UP, HidNpadButton_Up}, {SDL_SCANCODE_RIGHT, HidNpadButton_Right}, {SDL_SCANCODE_DOWN, HidNpadButton_Down}};
                for (const auto &binding : bindings)
                {
                    if (keyboard[binding.first])
                    {
                        pad.buttons_cur |= binding.second;
                    }
                }
                ++frameIndex;
                if (uiTest)
                {
                    pad.buttons_cur = 0;
                    const char *route = getenv("PKSE_TEST_ROUTE");
                    if (route)
                    {
                        std::istringstream steps(route);
                        std::string step;
                        while (std::getline(steps, step, ','))
                        {
                            const size_t separator = step.find(':');
                            if (separator != std::string::npos && frameIndex == atoi(step.substr(0, separator).c_str()))
                            {
                                pad.buttons_cur = strtoull(step.substr(separator + 1).c_str(), nullptr, 16);
                            }
                        }
                    }
                }
                if (!uiTest)
                {
                    touch.update();
                }
                trainerScreen.update(pad, touch);
                if (uiTest && pad.buttons_cur)
                {
                    uiReport << frameIndex << " keys " << pad.buttons_cur << " details " << trainerScreen.details.active << " field " << trainerScreen.details.selectedField << " picker " << trainerScreen.pickerActive << " save " << trainerScreen.saveConfirmActive << "\n";
                }
                trainerScreen.draw(framebuffer);
                framebuffer.flush();
                if (uiTest && frameIndex == 600)
                {
                    SDL_Window *window = SDL_GL_GetCurrentWindow();
                    int screenWidth = 0;
                    int screenHeight = 0;
                    SDL_GL_GetDrawableSize(window, &screenWidth, &screenHeight);
                    std::vector<unsigned char> pixels(static_cast<size_t>(screenWidth) * screenHeight * 4);
                    glReadBuffer(GL_FRONT);
                    glReadPixels(0, 0, screenWidth, screenHeight, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
                    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:screenWidth pixelsHigh:screenHeight bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:screenWidth * 4 bitsPerPixel:32];
                    for (int rowIndex = 0; rowIndex < screenHeight; ++rowIndex)
                    {
                        memcpy(bitmap.bitmapData + static_cast<size_t>(rowIndex) * screenWidth * 4, pixels.data() + static_cast<size_t>(screenHeight - rowIndex - 1) * screenWidth * 4, static_cast<size_t>(screenWidth) * 4);
                    }
                    NSString *outputPath = [NSString stringWithUTF8String:(std::filesystem::path(g_savePath).parent_path() / "editor.png").c_str()];
                    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:outputPath atomically:YES];
                    running = false;
                }
                SDL_Delay(8);
            }
        }
        SDL_Quit();
    }
    return 0;
}
