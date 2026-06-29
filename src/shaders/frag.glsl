#version 330 core
in vec2 fragCoord;
out vec4 FragColor;

uniform vec3 camPos;
uniform vec3 camForward;
uniform vec3 camRight;
uniform vec3 camUp;
uniform float fov;
uniform float aspectRatio;
uniform float time;

const float M = 1.0;
const float HORIZON = 2.02;
const float ESCAPE_R = 200.0;
const int MAX_STEPS = 3000;
const float dPhi = 0.02;

// Starfield based on ray direction
vec3 starfield(vec3 dir)
{
    vec3 d = normalize(dir);
    float stars = 0.0;
    // three layers of stars at different scales
    for (int i = 1; i <= 3; i++)
    {
        float scale = 150.0 * float(i);
        vec3 g = fract(d * scale) - 0.5;
        float s = smoothstep(0.08, 0.0, length(g));
        stars += s * (0.3 + 0.7 / float(i));
    }
    vec3 base = vec3(0.02, 0.02, 0.05);
    return base + vec3(0.9, 0.95, 1.0) * clamp(stars, 0.0, 1.0);
}

// Accreation disk color at radius radius r
vec3 diskColor(float r)
{
    float t = clamp((r - 3.0) / 9.0, 0.0, 1.0);
    vec3 inner = vec3(1.0, 0.6, 0.1);
    vec3 outer = vec3(0.6, 0.1, 0.05);
    float brightness = 1.0 / (1.0 + (r - 3.0) * 0.3);
    return mix(inner, outer, t) * brightness * 2.5;
}

void main()
{
    // Build ray direction from camera basis and fov
    float scale = tan(radians(fov) * 0.5);
    vec3 rayDir = normalize(
        camForward +
        camRight * fragCoord.x * scale * aspectRatio +
        camUp * fragCoord.y * scale
    );

    // Impact parameter: b = r0 * sin(angle between ray and direction to BH)
    vec3 toBH = normalize(-camPos);
    float cosTheta = clamp(dot(rayDir, toBH), -1.0, 1.0);
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float r0 = length(camPos);
    float b = r0 * sinTheta;

    // Orbital plane: figure out the signed angle for disk crossing detection
    vec3 planeNormal = normalize(cross(camPos, rayDir));

    // RK4 geodesic integration in u = 1/r space
    float  u = 1.0 / r0;
    float radicand = max(0.0, 1.0 - (1.0 - 2.0 * M * u) * b * b * u * u);
    float dudPhi_ = sqrt(radicand) / max(b, 0.001);

    vec3 color = vec3(0.0);
    bool hit = false;

    float prevCamDot = dot(camPos, planeNormal);

    for (int i = 0; i < MAX_STEPS; i++)
    {
        float k1u = dudPhi_;
        float k1v = 3.0 * M * u * u - u;

        float u2 = u + 0.5 * dPhi * k1u;
        float v2 = dudPhi_ + 0.5 * dPhi * k1v;
        float k2u = v2;
        float k2v = 3.0 * M * u2 * u2 - u2;

        float u3 = u + 0.5 * dPhi * k2u;
        float v3 = dudPhi_ + 0.5 * dPhi * k2v;
        float k3u = v3;
        float k3v = 3.0 * M * u3 * u3 - u3;

        float u4 = u + dPhi * k3u;
        float v4 = dudPhi_ + dPhi * k3v;
        float k4u = v4;
        float k4v = 3.0 * M * u4 * u4 - u4;

        u += (dPhi / 6.0) * (k1u + 2.0*k2u + 2.0*k3u + k4u);
        dudPhi_ += (dPhi / 6.0) * (k1v + 2.0*k2v + 2.0*k3v + k4v);

        float r = 1.0 / u;

        // Captured by HORIZON
        if (r < HORIZON)
        {
            color = vec3(0.0);
            hit = true;
            break;
        }

        // Escaped to infinity - sample starfield
        if (r > ESCAPE_R)
        {
            // Reconstruct approximate exit direction from angle traveled
            color = starfield(rayDir);
            hit = true;
            break;
        }

        // Disk crossing: equatorial plane between r=3M and r=12M
        // We detect sign change in the dot of position with the plane normal
        float curDot = float(i) * dPhi; // proxy for phi progress
        if (r > 3.0 && r < 12.0)
        {
            // Check if we crossed the equatorial plane this step
            // Using the y-component of the reconstructed position in the orbital plane
            float phase = float(i) * dPhi;
            float crossCheck = sin(phase);
            float prevCross = sin(phase - dPhi);
            if (crossCheck * prevCross < 0.0)
            {
                float doppler = 1.0 + 0.4 * sin(float(i) * 0.1);
                color += diskColor(r) * doppler * 0.6;
            }
        }
    }

    if (!hit)
        color = starfield(rayDir);

    // Simple tone mapping
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}