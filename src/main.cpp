#include "Vec3.h"
#include "Image.h"
#include "Camera.h"
#include "GeodesicIntegrator.h"
#include <iostream>

int main()
{
    const int width = 800;
    const int height = 600;
    const double dPhi = 0.01;

    Image image(width, height);
    Camera camera(Vec3(0, 0, -50), Vec3(0, 0, 1), 60.0, width, height);

    for (int y = 0; y < height; ++y)
    {
        for (int x = 0; x < width; ++x)
        {
            double b = camera.impactParameterForPixel(x, y);

            GeodesicIntegrator integrator(b, /*r0=*/50.0, /*phi0=*/0.0);
            auto outcome = GeodesicIntegrator::Outcome::StillTracing;

            for (int i = 0; i < 100000 && outcome == GeodesicIntegrator::Outcome::StillTracing; ++i)
            {
                integrator.step(dPhi);
                outcome = integrator.outcome();
            }

            Vec3 color = (outcome == GeodesicIntegrator::Outcome::Captured)
                             ? Vec3(0, 0, 0)
                             : Vec3(0.05, 0.05, 0.1); // placeholder sky color
            image.setPixel(x, y, color);
        }
        if (y % 50 == 0)
            std::cout << "row " << y << "/" << height << "\n";
    }

    image.writePPM("output.ppm");
    std::cout << "done\n";
    return 0;
}