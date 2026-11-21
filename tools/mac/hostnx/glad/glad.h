#ifndef PKSE_MAC_GLAD_H
#define PKSE_MAC_GLAD_H
#ifndef GL_SILENCE_DEPRECATION
#define GL_SILENCE_DEPRECATION
#endif
#include <OpenGL/gl3.h>
inline int gladLoadGL()
{
    return 1;
}
#endif
