#pragma once
#include "Vec3.h"
#include <vector>
#include <string>

class Image
{
public:
    Image(int width, int height);

    void setPixel(int x, int y, const Vec3 &color); // components in [0,1]
    void writePPM(const std::string &filename) const;

    int width() const { return w; }
    int height() const { return h; }

private:
    int w, h;
    std::vector<Vec3> pixels;
};