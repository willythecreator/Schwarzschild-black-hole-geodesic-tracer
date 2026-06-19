# Schwarzschild Geodesic Tracer

A from-scratch C++ renderer that traces photon paths (null geodesics)
around a non-rotating Schwarzschild black hole gravitational lensing,
photon ring, event horizon shadow.

## Status

Skeleton stage. Structure and build system are in place; the physics
(geodesic integration, camera ray setup, outcome detection) is stubbed
with TODOs and being filled in incrementally.

## Build

    mkdir build && cd build
    cmake ..
    make
    ./tracer

Produces `output.ppm`. View with any PPM-capable viewer, or
`convert output.ppm output.png` with ImageMagick.