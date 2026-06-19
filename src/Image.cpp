#include "Image.h"
#include <fstream>
#include <algorithm>

Image::Image(int width, int height) : w(width), h(height), pixels(width * height) {}

void Image::setPixel(int x, int y, const Vec3 &color)
{
    pixels[y * w + x] = color;
}

void Image::writePPM(const std::string &filename) const
{
    std::ofstream out(filename, std::ios::binary);
    out << "P6\n"
        << w << " " << h << "\n255\n";
    for (const auto &c : pixels)
    {
        unsigned char r = static_cast<unsigned char>(std::clamp(c.x, 0.0, 1.0) * 255);
        unsigned char g = static_cast<unsigned char>(std::clamp(c.y, 0.0, 1.0) * 255);
        unsigned char b = static_cast<unsigned char>(std::clamp(c.z, 0.0, 1.0) * 255);
        out << r << g << b;
    }
}