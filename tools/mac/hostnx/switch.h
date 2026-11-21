#ifndef PKSE_MAC_SWITCH_H
#define PKSE_MAC_SWITCH_H
#include "../../harness/uihost/hostnx/switch.h"
#include <SDL2/SDL.h>
using Result = int;
#define R_FAILED(result) ((result) != 0)
#define R_SUCCEEDED(result) ((result) == 0)
enum PlSharedFontType
{
    PlSharedFontType_Standard,
    PlSharedFontType_ChineseSimplified,
    PlSharedFontType_ExtChineseSimplified,
    PlSharedFontType_ChineseTraditional,
    PlSharedFontType_KO,
    PlSharedFontType_NintendoExt
};
struct PlFontData
{
    void *address;
    size_t size;
};
inline Result plGetSharedFontByType(PlFontData *, PlSharedFontType)
{
    return 1;
}
struct HidTouchState
{
    u32 x;
    u32 y;
};
struct HidTouchScreenState
{
    int count;
    HidTouchState touches[1];
};
inline int hidGetTouchScreenStates(HidTouchScreenState *touchState, int)
{
    int cursorX = 0;
    int cursorY = 0;
    touchState->count = (SDL_GetMouseState(&cursorX, &cursorY) & SDL_BUTTON_LMASK) ? 1 : 0;
    touchState->touches[0] = {static_cast<u32>(cursorX), static_cast<u32>(cursorY)};
    return 1;
}
#endif
