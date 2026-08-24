#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;
uniform float windRot;
uniform float glow;

uniform sampler2D textTexture;

out vec4 fragColor;

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;

// --------------------------------------------------
// RANDOM
// --------------------------------------------------

float hash1(float p) {
    return fract(sin(p * 127.1) * 43758.5453123);
}

float hash(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7))) *
        43758.5453123
    );
}

// --------------------------------------------------
// ANGLE
// --------------------------------------------------

float angularDistance(float a, float b) {
    float d = abs(a - b);
    return min(d, TWO_PI - d);
}

// --------------------------------------------------
// PETIR BERCAWANG DI LUAR GLOBE
// --------------------------------------------------

float lightning(
    float angle,
    float radius,
    float time
) {
    float total = 0.0;

    // Petir hanya berada di ring luar globe
    float ringOuter =
        smoothstep(0.47, 0.57, radius) *
        smoothstep(0.98, 0.68, radius);

    if (ringOuter <= 0.0) {
        return 0.0;
    }

    for (float i = 0.0; i < 5.0; i += 1.0) {
        float seed = i * 19.371;

        // Setiap petir memiliki interval berbeda
        float speed = 0.72 + i * 0.19;
        float strikeId = floor(time * speed + seed);

        float chance = hash1(strikeId + seed);

        // Probabilitas kemunculan petir
        if (chance > 0.48) {
            float baseAngle =
                hash1(strikeId + seed + 2.0) * TWO_PI;

            // Jalur zig-zag
            float zigzag =
                sin(radius * 65.0 - time * 17.0 + seed) * 0.055
              + sin(radius * 125.0 + time * 29.0 + seed) * 0.022
              + sin(angle * 11.0 + seed) * 0.018;

            float boltAngle = baseAngle + zigzag;

            float distanceToBolt =
                angularDistance(angle, boltAngle);

            // Inti petir
            float core =
                smoothstep(0.040, 0.0, distanceToBolt);

            // Cahaya menyebar dari inti petir
            float aura =
                smoothstep(0.16, 0.0, distanceToBolt);

            // Cabang petir
            float branchNoise =
                sin(angle * 24.0 + radius * 92.0 + seed) *
                0.5 + 0.5;

            float branches =
                pow(branchNoise, 13.0) *
                aura;

            // Pulse pendek seperti sambaran
            float phase =
                fract(time * speed + seed);

            float pulse =
                exp(-phase * 10.0);

            // Kedipan tambahan
            float flicker =
                0.65 +
                0.35 * sin(time * 43.0 + seed);

            total +=
                (core * 2.5 + aura * 0.65 + branches * 1.8)
                * pulse
                * flicker;
        }
    }

    return total * ringOuter;
}

// --------------------------------------------------
// GLOW RING DI LUAR GLOBE
// --------------------------------------------------

float electricRing(float radius, float time) {
    float ringDistance = abs(radius - 0.535);

    float ring =
        exp(-ringDistance * 90.0);

    float movement =
        0.75 +
        0.25 * sin(time * 7.0 + radius * 40.0);

    return ring * movement;
}

// --------------------------------------------------
// FLASH SAAT SAMBARAN
// --------------------------------------------------

float lightningFlash(float time) {
    float flash = 0.0;

    for (float i = 0.0; i < 4.0; i += 1.0) {
        float speed = 0.85 + i * 0.23;
        float id = floor(time * speed + i * 8.31);
        float randomValue = hash1(id + i * 3.7);

        if (randomValue > 0.73) {
            float phase = fract(time * speed + i * 8.31);

            // Sangat terang di awal, lalu cepat padam
            flash +=
                exp(-phase * 18.0) *
                (randomValue - 0.73) *
                3.8;
        }
    }

    return flash;
}

// --------------------------------------------------
// MAIN
// --------------------------------------------------

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    vec2 uv =
        fragCoord / iResolution.xy;

    // Normalized coordinate
    vec2 p =
        uv * 2.0 - 1.0;

    // Koreksi aspect ratio
    p.x *= iResolution.x / iResolution.y;

    // Posisi globe
    vec2 center = vec2(0.0, 0.18);

    vec2 d =
        p - center;

    float radius =
        length(d);

    float angle =
        atan(d.y, d.x);

    // Radius globe
    float globeR = 0.52;

    // Background hitam pekat
    vec3 color =
        vec3(0.003, 0.004, 0.008);

    // --------------------------------------------------
    // PETIR LUAR GLOBE
    // --------------------------------------------------

    float bolt =
        lightning(angle, radius, iTime);

    vec3 boltCore =
        vec3(1.0, 0.98, 0.78) *
        pow(max(bolt, 0.0), 1.35) *
        3.8;

    vec3 boltGold =
        vec3(1.0, 0.42, 0.015) *
        bolt *
        1.4;

    color += boltCore;
    color += boltGold;

    // Ring listrik tipis yang berdenyut
    float ring =
        electricRing(radius, iTime);

    float ringWave =
        0.78 +
        0.22 * sin(iTime * 5.0 + angle * 8.0);

    color +=
        vec3(1.0, 0.52, 0.04) *
        ring *
        ringWave *
        glow *
        0.7;

    // --------------------------------------------------
    // FLASH
    // --------------------------------------------------

    float flash =
        lightningFlash(iTime);

    color +=
        vec3(1.0, 0.82, 0.36) *
        flash *
        0.16;

    // --------------------------------------------------
    // GLOBE 3D
    // --------------------------------------------------

    if (radius < globeR) {
        vec2 sphereUV =
            d / globeR;

        float zSquared =
            1.0 - dot(sphereUV, sphereUV);

        if (zSquared > 0.0) {
            float z =
                sqrt(zSquared);

            // Rotasi globe
            float c =
                cos(rotY);

            float s =
                sin(rotY);

            vec2 rotatedXZ =
                vec2(
                    sphereUV.x * c - z * s,
                    sphereUV.x * s + z * c
                );

            vec3 normal =
                normalize(
                    vec3(
                        rotatedXZ.x,
                        sphereUV.y,
                        rotatedXZ.y
                    )
                );

            vec3 lightDirection =
                normalize(
                    vec3(-0.65, 0.42, 0.88)
                );

            float diffuse =
                max(
                    0.0,
                    dot(normal, lightDirection)
                );

            // Siluet 3D
            float sideLight =
                pow(
                    max(0.0, normal.z),
                    0.55
                );

            // Rim globe
            float rim =
                pow(
                    1.0 - max(0.0, normal.z),
                    3.0
                );

            vec3 darkGold =
                vec3(0.18, 0.055, 0.006);

            vec3 midGold =
                vec3(0.62, 0.25, 0.018);

            vec3 brightGold =
                vec3(1.0, 0.78, 0.12);

            vec3 globeColor =
                mix(darkGold, midGold, diffuse);

            globeColor =
                mix(globeColor, brightGold, sideLight * 0.72);

            // --------------------------------------------------
            // TEXTURE BABE.INFO
            // --------------------------------------------------

            // x = longitude
            // y = latitude
            float longitude =
                atan(rotatedXZ.x, rotatedXZ.y);

            float latitude =
                asin(clamp(normal.y, -1.0, 1.0));

            vec2 texUV =
                vec2(
                    longitude / TWO_PI + 0.5,
                    latitude / PI + 0.5
                );

            // Ulangi texture secara horizontal
            texUV.x =
                fract(texUV.x * 2.0 + windRot * 0.025);

            // Sedikit pengulangan vertikal
            texUV.y =
                fract(texUV.y * 1.35);

            vec4 textSample =
                texture(textTexture, texUV);

            // Teks mengikuti pencahayaan globe
            vec3 textColor =
                vec3(1.0, 0.84, 0.25);

            float textStrength =
                textSample.a *
                smoothstep(0.12, 0.45, diffuse);

            globeColor =
                mix(
                    globeColor,
                    textColor,
                    textStrength * 0.92
                );

            // Glow petir memantul ke permukaan globe
            globeColor +=
                vec3(1.0, 0.52, 0.06) *
                bolt *
                0.24;

            globeColor +=
                vec3(1.0, 0.8, 0.3) *
                flash *
                0.48;

            // Edge globe yang bercahaya
            globeColor +=
                vec3(1.0, 0.34, 0.015) *
                rim *
                (1.25 + bolt * 0.75);

            color =
                globeColor;
        }
    }

    // --------------------------------------------------
    // GLOW GLOBE
    // --------------------------------------------------

    float globeGlow =
        exp(-abs(radius - globeR) * 28.0);

    color +=
        vec3(1.0, 0.36, 0.015) *
        globeGlow *
        0.24;

    // Vignette
    float vignette =
        1.0 - dot(p, p) * 0.28;

    color *=
        max(vignette, 0.0);

    // Kontras warna
    color =
        pow(max(color, 0.0), vec3(0.88));

    fragColor =
        vec4(color, 1.0);
}
