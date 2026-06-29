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
const float PI = 3.14159265358979;

float hash(vec3 p)
{
    p = fract(p * vec3(443.897, 397.297, 491.187));
    p += dot(p, p.yxz + 19.19);
    return fract((p.x + p.y) * p.z);
}

// Milky Way starfield with gravitational redshift
vec3 starfield(vec3 dir, float minR)
{
    vec3 d = normalize(dir);

    // Gravitational redshift: rays that grazed the hole shift star colors red
    float redshift = 0.0;
    if (minR < ESCAPE_R * 0.5)
    {
        float z = 1.0 / sqrt(max(0.01, 1.0 - 2.0 * M / minR)) - 1.0;
        redshift = clamp(z * 0.35, 0.0, 1.0);
    }

    // Mily Way band
    vec3 galacticNorth = normalize(vec3(0.0, 0.6, 0.8));
    float galLat = abs(dot(d, galacticNorth));
    float band = exp(-galLat * galLat * 8.0);
    vec3 milkyWay = vec3(0.12, 0.10, 0.18) * band;
    milkyWay += vec3(0.08, 0.04, 0.12) * hash(d * 3.7) * band;

    // Sparse bright stars with color variation
    vec3 starColor = vec3(0.0);
    for (int i = 1; i <= 4; i++)
    {
        float scale = 120.0 * float(i);
        vec3 cell = floor(d * scale);
        vec3 g = fract(d * scale) - 0.5;
        float h = hash(cell);
        float s = smoothstep(0.06, 0.0, length(g)) * step(0.85, h);
        float cSeed = hash(cell + 0.5);
        vec3 sc = mix(
            mix(vec3(0.6, 0.7, 1.0), vec3(1.0, 0.95, 0.8), cSeed),
            vec3(1.0, 0.4, 0.2), step(0.92, cSeed)
        );
        starColor += sc * s * (0.5 + 0.5 / float(i));
    }

    for (int i = 1; i <= 2; i++)
    {
        float scale = 300.0 * float(i);
        vec3 cell = floor(d * scale);
        vec3 g = fract(d * scale) - 0.5;
        float h = hash(cell + 10.0);
        float s = smoothstep(0.04, 0.0, length(g)) * step(0.70, h) * band;
        starColor += vec3(0.75, 0.82, 1.0) * s * 0.5;
    }

    vec3 color = vec3(0.01, 0.01, 0.03) + milkyWay + starColor;

    // Apply gravitational redshift tint
    color *= mix(vec3(1.0), vec3(1.0 + redshift, 1.0 - redshift*0.4, 1.0 - redshift*0.7), redshift);

    return color;
}

// Physically motivaded accretion disk
vec3 diskColor(float r, float phase)
{
    // Circular orbit velocity in geometric units
    float denom = max(0.001, 1.0 - 3.0 * M / r);
    float v_orb = clamp(sqrt(M / r) / sqrt(denom), 0.0, 0.95);

    // Doopler: sin(phase)encodes approaching vs receding side
    float cosAlpha = sin(phase);
    float dooplerFactor = sqrt((1.0 + v_orb * cosAlpha) /
                          max(0.001, 1.0 - v_orb * cosAlpha));

    // Gravitational redshift at emission radius
    float gFactor = sqrt(max(0.001, 1.0 - 2.0 * M / r));
    float total = dooplerFactor * gFactor;

    // Temperature gradient: ISCO at r=6M, inner edge glows hottest
    float t = clamp((r - 3.0) / 9.0, 0.0, 1.0);
    vec3 hot = vec3(1.00, 0.95, 0.80); // near-white
    vec3 mid = vec3(1.00, 0.50, 0.10); // orange
    vec3 cool = vec3(0.50, 0.05, 0.01); // deep red
    vec3 base = t < 0.5
        ? mix(hot, mid, t * 2.0)
        : mix(mid, cool, (t - 0.5) * 2.0);

    // Brightness: inverse square falloff x relativistic beaming (∝ D³)
    float brightness = (1.0 / (1.0 + (r - 3.0) * 0.25)) * pow(total, 3.0);

    // Frequency shift changes the percieved color
    vec3 shifted;
    shifted.r = base.r * (total < 1.0 ? total : 1.0);
    shifted.g = base.g * (total < 1.0 ? total * 0.8 : min(total * 0.5, 1.0));
    shifted.b = base.b * (total > 1.0 ? min(total * 0.8, 1.0) : total * 0.5);

    return shifted * brightness * 3.0;
}

// main
void main()
{
    float scale = tan(radians(fov) * 0.5);
    vec3 rayDir = normalize(
        camForward +
        camRight * fragCoord.x * scale * aspectRatio +
        camUp * fragCoord.y * scale
    );

    // Impact parameter
    vec3 toBH = normalize(-camPos);
    float cosTheta = clamp(dot(rayDir, toBH), -1.0, 1.0);
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float r0 = length(camPos);
    float b = r0 * sinTheta;

    // Initial condition for u = 1/r integration
    float u = 1.0 / r0;
    float radicand = max(0.0, 1.0 - (1.0 - 2.0 * M * u) * b * b * u * u);
    float dudPhi_ = sqrt(radicand) / max(b, 0.001);

    vec3 color = vec3(0.0);
    bool hit = false;
    float minR = r0;

    for (int i = 0; i < MAX_STEPS; i++)
    {
        // RK4
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

        float u4 = u + 0.5 * dPhi * k3u;
        float v4 = dudPhi_ + 0.5 * dPhi * k3v;
        float k4u = v4;
        float k4v = 3.0 * M * u4 * u4 - u4;

        u += (dPhi / 6.0) * (k1u + 2.0*k2u + 2.0*k3u + k4u);
        dudPhi_ += (dPhi / 6.0) * (k1v + 2.0*k2v + 2.0*k3v + k4v);

        float r = 1.0 / u;
        minR = min(minR, r);

        // Captured
        if (r < HORIZON)
        {
            color = vec3(0.0);
            hit = true;
            break;
        }

        // Escaped 
        if (r > ESCAPE_R)
        {
            color = starfield(rayDir, minR);
            hit = true;
            break;
        }

        // Accretion disk crossing (equatorial plane, r between ISCO and outer edge)
        if (r > 3.0 && r < 12.0)
        {
            float phase = float(i) * dPhi;
            float crossCheck = sin(phase);
            float prevCross = sin(phase - dPhi);
            if (crossCheck * prevCross < 0.0)
            {
                color += diskColor(r, phase);
            }
        }
    }

    if (!hit)
        color = starfield(rayDir, minR);

    // Tone mapping + gamma
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}