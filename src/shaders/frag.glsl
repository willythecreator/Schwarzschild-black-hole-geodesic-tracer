#version 330 core

in vec2 fragCoord;
out vec4 FragColor;

uniform vec3 camPos;
uniform vec3 camForward;
uniform vec3 camRight;
uniform vec3 camUp;
uniform float aspectRatio;
uniform float time;

const float PI = 3.14159265;
const float M = 1.0;
const float HORIZON = 2.03;
const float ESCAPE_RADIUS = 150.0;

// This is the main performance setting.
// 180-240: fast.
// 280-360: nicer close-up lensing.
const int MAX_STEPS = 240;

float hash(vec3 p) {
    p = fract(p * vec3(443.897, 397.297, 491.187));
    p += dot(p, p.yxz + 19.19);
    return fract((p.x + p.y) * p.z);
}

vec3 starfield(vec3 direction) {
    vec3 d = normalize(direction);
    vec3 stars = vec3(0.0);

    // Three layers are much cheaper than procedural volumetric noise.
    for (int i = 1; i <= 4; i++) {
        float scale = 95.0 * float(i);
        vec3 cell = floor(d * scale);
        vec3 local = fract(d * scale) - 0.5;

        float random = hash(cell + float(i) * 11.7);
        float size = mix(0.012, 0.040, random);

        float star = smoothstep(size, 0.0, length(local));
        star *= step(0.87, random);

        vec3 color = mix(
            vec3(0.55, 0.70, 1.0),
            vec3(1.0, 0.82, 0.48),
            hash(cell + 3.1)
        );

        stars += color * star * (1.1 - 0.2 * float(i));
    }

    return stars;
}

float noise2D(vec2 p)
{
    vec2 cell = floor(p);
    vec2 local = fract(p);

    local = local * local * (3.0 - 2.0 * local);

    float a = hash(vec3(cell, 1.0));
    float b = hash(vec3(cell + vec2(1.0, 0.0), 1.0));
    float c = hash(vec3(cell + vec2(0.0, 1.0), 1.0));
    float d = hash(vec3(cell + vec2(1.0, 1.0), 1.0));

    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float diskTurbulance(vec2 p)
{
    float value = 0.0;
    float weight = 0.55;

    for (int i = 0; i < 3; i++)
    {
        value += noise2D(p) * weight;
        p = p * 2.05 + vec2(17.3, 9.2);
        weight *= 0.5;
    }

    return value;
}

float diskProfile(float radius) {
    const float ISCO = 6.0;

    // No stable thin disk inside the ISCO for a Schwarzschild black hole.
    float innerEdge = smoothstep(5.8, 6.7, radius);
    float outerFade = 1.0 - smoothstep(20.0, 32.0, radius);

    // Approximation of a thin-disk brightness profile:
    // bright just outside the inner edge, gradually dimmer farther out.
    float x = ISCO / max(radius, ISCO);
    float flux = pow(x, 3.0) * max(0.0, 1.0 - sqrt(x));

    return innerEdge * outerFade * flux * 9.0;
}

vec3 accretionDisk(vec3 position, vec3 viewDirection) {
    float radius = length(position.xz);

    if (radius < 5.8 || radius > 32.0)
        return vec3(0.0);

    float density = diskProfile(radius);

    // Uneven plasma texture: cloudy rather than spiral-shaped
    float plasma = diskTurbulance(position.xz * 0.55);
    density *= mix(0.62, 1.25, plasma);

    // Direction in which the disk matter orbits.
    vec3 orbitDirection = normalize(vec3(-position.z, 0.0, position.x));

    // Material moving toward the camera is much brighter.
    float approaching = dot(orbitDirection, -viewDirection);

    // Keep s small realistic birghtness difference, without one side overpowering
    float doppler = clamp(1.0 + approaching * 0.18, 0.82, 1.18);
    float beaming = pow(doppler, 1.3);

    // Yellow-orange near the inner edge; red-orange farther out.
    float temperature = clamp((radius - 6.0) / 21.0, 0.0, 1.0);

    vec3 innerColor = vec3(1.0, 0.62, 0.14);
    vec3 middleColor = vec3(1.0, 0.22, 0.012);
    vec3 outerColor = vec3(0.22, 0.006, 0.0005);

    vec3 color = temperature < 0.35
        ? mix(innerColor, middleColor, temperature / 0.35)
        : mix(middleColor, outerColor, (temperature - 0.35) / 0.65);

    return color * density * beaming * 1.1;
}

vec3 relativisticJet(vec2 screenPosition) {
    vec3 toBlackHole = normalize(-camPos);
    float forwardDepth = dot(toBlackHole, camForward);

    // Do not show a jet if the black hole is behind the camera.
    if (forwardDepth <= 0.01)
        return vec3(0.0);

    // Find the black hole's current position on screen.
    float fovScale = tan(radians(60.0) * 0.5);

    vec2 blackHoleScreen = vec2(
        dot(toBlackHole, camRight) / (forwardDepth * fovScale * aspectRatio),
        dot(toBlackHole, camUp) / (forwardDepth * fovScale)
    );

    // Draw the jet relative to the black hole, not the screen centre.
    vec2 relativePosition = screenPosition - blackHoleScreen;

    // Disk normal / jet direction in world space.
    vec3 spinAxis = vec3(0.0, 1.0, 0.0);

    vec2 screenAxis = vec2(
        dot(spinAxis, camRight),
        dot(spinAxis, camUp)
    );

    float axisLength = length(screenAxis);

    if (axisLength < 0.001)
        return vec3(0.0);

    screenAxis /= axisLength;

    float alongJet = dot(relativePosition, screenAxis);
    float acrossJet = dot(relativePosition, vec2(-screenAxis.y, screenAxis.x));
    float distanceFromHole = abs(alongJet);

    // Wide, soft cone: foggy rather than a laser beam.
    float width = 0.025 + distanceFromHole * 0.090;

    float fog = exp(-pow(acrossJet / width, 2.0));
    float softCore = exp(-pow(acrossJet / (width * 0.48), 2.0));

    float visible =
        smoothstep(0.07, 0.16, distanceFromHole) *
        (1.0 - smoothstep(0.45, 0.95, distanceFromHole));

    // Only show the jet when the camera is above or below the disk.
    float aboveOrBelowDisk = abs(normalize(camPos).y);
    float lookingAtBlackHole = smoothstep(0.70, 0.94, forwardDepth);
    float angleVisibility = smoothstep(0.10, 0.32, aboveOrBelowDisk);

    // Lower values give the transparent, misty look.
    vec3 fogColor = vec3(0.03, 0.12, 0.55) * fog * 0.07;
    vec3 coreColor = vec3(0.45, 0.68, 1.00) * softCore * 0.20;

    return (fogColor + coreColor) *
       visible *
       angleVisibility *
       lookingAtBlackHole;
}

void main() {
    float fovScale = tan(radians(60.0) * 0.5);

    vec3 rayDir = normalize(
        camForward +
        camRight * fragCoord.x * fovScale * aspectRatio +
        camUp * fragCoord.y * fovScale
    );

    float cameraRadius = length(camPos);
    float impactParameter = cameraRadius *
        sqrt(max(0.0, 1.0 - pow(dot(rayDir, normalize(-camPos)), 2.0)));

    // Orbit plane for this ray.
    vec3 planeX = normalize(camPos);
    vec3 planeNormal = cross(camPos, rayDir);

    // Avoid numerical problems for rays directly toward the black hole.
    if (length(planeNormal) < 0.0001)
        planeNormal = vec3(0.0, 1.0, 0.0);

    planeNormal = normalize(planeNormal);
    vec3 planeY = normalize(cross(planeNormal, planeX));

    float u = 1.0 / cameraRadius;
    float velocity = sqrt(max(
        0.0,
        1.0 - (1.0 - 2.0 * M * u) * impactParameter * impactParameter * u * u
    )) / max(impactParameter, 0.02);

    float phi = 0.0;
    float closestRadius = cameraRadius;
    bool captured = false;
    bool escaped = false;

    vec3 diskLight = vec3(0.0);
    vec3 exitDirection = rayDir;

    float previousY = camPos.y;
    int diskHits = 0;
    vec3 previousPosition = camPos;

    for (int i = 0; i < MAX_STEPS; i++) {
        float radiusBefore = 1.0 / max(u, 0.0001);

        // Larger steps far away, smaller steps near the photon sphere.
        float stepSize = mix(0.010, 0.032, smoothstep(2.5, 25.0, radiusBefore));

        // RK2 integration: much cheaper than RK4, still stable enough visually.
        float acceleration = 3.0 * M * u * u - u;
        float uMid = u + velocity * stepSize * 0.5;
        float velocityMid = velocity + acceleration * stepSize * 0.5;

        u += velocityMid * stepSize;
        velocity += (3.0 * M * uMid * uMid - uMid) * stepSize;
        phi += stepSize;

        float radius = 1.0 / max(u, 0.0001);
        closestRadius = min(closestRadius, radius);

        if (radius < HORIZON) {
            captured = true;
            break;
        }

        if (radius > ESCAPE_RADIUS && phi > 0.2) {
            escaped = true;
            break;
        }

        vec3 position = radius * (cos(phi) * planeX + sin(phi) * planeY);
        exitDirection = normalize(position - camPos);

        // A thin disk only needs a ray-plane crossing test.
        // This replaces the old expensive volumetric integration.
        float yNow = position.y;
        bool crossesDisk = previousY * yNow <= 0.0;

        if (crossesDisk && diskHits < 2)
        {
            // Find the exact approximate point where this ray crosses the disk
            // This removes the blocky, fan-shaped edge
            float crossing = clamp(
                previousY / (previousY - yNow),
                0.0,
                1.0
            );

            vec3 diskPosition = mix(previousPosition, position, crossing);
            float diskRadius = length(diskPosition.xz);

            if (diskRadius > 5.8 && diskRadius < 32.0)
            {
                diskLight += accretionDisk(diskPosition, rayDir) * 1.5;
                diskHits++;
            }
        }

        previousY = yNow;
        previousPosition = position;
    }

    vec3 color = vec3(0.0);

    if (!captured)
    {
        // Strong near the black hole, weak far away.
        float lensAmount = 1.0 - smoothstep(3.0, 18.0, closestRadius);

        // Use the bent ray direction to sample the background stars.
        vec3 lensedStarDirection = normalize(
            mix(rayDir, exitDirection, 0.65 + 0.35 * lensAmount)
        );

        color += starfield(lensedStarDirection);
    }

    color += diskLight;

    // Photon ring:
    // Multiple narrow rings around the critical orbit (~3M).
    // This is visually strong and costs almost nothing.
    float criticalDistance = abs(closestRadius - 3.0);

    // Creates one very thin bright ring.
    float photonRing = exp(-criticalDistance * criticalDistance * 140.0);

    // Creates a faint, soft orange glow around that ring.
    float halo = exp(-criticalDistance * criticalDistance * 18.0);

    float ringVisibility = captured ? 0.65 : 1.0;

    vec3 ringColor =
        vec3(1.0, 0.56, 0.12) * photonRing * 1.5 +
        vec3(1.0, 0.12, 0.01) * halo * 0.08;

    color += ringColor * ringVisibility;

    color += relativisticJet(fragCoord);

    // Keep the event-horizon shadow pure black.
    if (captured)
        color = ringColor * 0.35;

    // ACES-like tone mapping and gamma correction.
    color = (color * (2.51 * color + 0.03)) /
            (color * (2.43 * color + 0.59) + 0.14);

    color = pow(clamp(color, 0.0, 1.0), vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}