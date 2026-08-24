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
    return fract(
        sin(p * 127.1) *
        43758.5453
    );
}

float hash2(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7))) *
        43758.5453
    );
}

float angularDistance(float a, float b) {
    float d = abs(a - b);
    return min(d, TWO_PI - d);
}

// --------------------------------------------------
// TEXTURE SAMPLING
// --------------------------------------------------

vec4 sampleTextTexture(vec2 uv) {
    // fract membuat texture berulang horizontal dan vertikal
    uv = fract(uv);
    return texture(textTexture, uv);
}

// --------------------------------------------------
// PETIR MEMBUNGKUS GLOBE
// --------------------------------------------------

float wrappingLightning(
    float angle,
    float radius,
    float time
) {
    float total = 0.0;

    // Radius globe = 0.52.
    // Petir berada dari dalam permukaan sampai keluar.
    float nearGlobe =
        smoothstep(0.43, 0.505, radius);

    float outerLimit =
        1.0 - smoothstep(0.58, 0.92, radius);

    float wrapMask =
        nearGlobe * outerLimit;

    if (wrapMask <= 0.0) {
        return 0.0;
    }

    // Beberapa aliran listrik dengan posisi berbeda
    for (float i = 0.0; i < 8.0; i += 1.0) {
        float seed = i * 17.173;

        float speed =
            0.45 + i * 0.105;

        float strikeId =
            floor(time * speed + seed);

        float chance =
            hash1(strikeId + seed);

        // Semakin kecil threshold, semakin sering petir aktif
        if (chance > 0.38) {
            float baseAngle =
                hash1(strikeId + seed + 3.0) *
                TWO_PI;

            float pulsePhase =
                fract(time * speed + seed);

            // Sambaran cepat
            float pulse =
                exp(-pulsePhase * 9.0);

            // Jalur zig-zag utama
            float zigzag =
                sin(radius * 74.0 + time * 22.0 + seed)
                * 0.075
              + sin(radius * 139.0 - time * 31.0 + seed)
                * 0.038
              + sin(radius * 245.0 + time * 47.0 + seed)
                * 0.018;

            float movingAngle =
                baseAngle + zigzag;

            float distanceMain =
                angularDistance(
                    angle,
                    movingAngle
                );

            // Inti putih petir
            float core =
                smoothstep(
                    0.032,
                    0.0,
                    distanceMain
                );

            // Aura kuning di sekeliling inti
            float aura =
                smoothstep(
                    0.16,
                    0.0,
                    distanceMain
                );

            // Cabang pertama
            float branchPattern =
                sin(
                    angle * 31.0 +
                    radius * 105.0 +
                    seed
                ) * 0.5 + 0.5;

            float branch1 =
                pow(branchPattern, 14.0) *
                aura *
                smoothstep(0.48, 0.54, radius);

            // Cabang kedua
            float branchPattern2 =
                sin(
                    angle * 47.0 -
                    radius * 180.0 +
                    seed * 2.0
                ) * 0.5 + 0.5;

            float branch2 =
                pow(branchPattern2, 19.0) *
                aura;

            // Ekor petir yang memanjang mengelilingi globe
            float tailPattern =
                sin(
                    angle * 12.0 +
                    radius * 58.0 -
                    time * 13.0 +
                    seed
                ) * 0.5 + 0.5;

            float tail =
                pow(tailPattern, 9.0) *
                smoothstep(0.08, 0.0, distanceMain) *
                0.9;

            total +=
                (
                    core * 5.0 +
                    aura * 0.75 +
                    branch1 * 4.2 +
                    branch2 * 2.4 +
                    tail
                )
                * pulse;
        }
    }

    // Aliran listrik tipis tambahan
    float flowingBand =
        sin(
            angle * 18.0 +
            radius * 80.0 -
            time * 10.0
        ) * 0.5 + 0.5;

    flowingBand =
        pow(flowingBand, 18.0);

    flowingBand *=
        smoothstep(0.49, 0.535, radius) *
        smoothstep(0.70, 0.55, radius);

    total +=
        flowingBand * 2.0;

    return total * wrapMask;
}

// --------------------------------------------------
// ATMOSFER / GLOW LUAR GLOBE
// --------------------------------------------------

float globeAtmosphere(
    float radius,
    float angle,
    float time
) {
    // Glow luas dari tepi globe ke luar
    float distanceFromEdge =
        abs(radius - 0.52);

    float wideGlow =
        exp(-distanceFromEdge * 20.0);

    // Glow dibuat tidak rata agar terlihat hidup
    float wave =
        0.70 +
        0.30 *
        sin(
            angle * 9.0 -
            time * 4.0
        );

    // Ring tipis terang
    float sharpRing =
        exp(-abs(radius - 0.535) * 100.0);

    // Glow luar yang menyelimuti globe
    float outerGlow =
        exp(-max(radius - 0.52, 0.0) * 18.0) *
        smoothstep(0.95, 0.45, radius);

    return
        wideGlow * wave * 0.75 +
        sharpRing * 1.25 +
        outerGlow * 0.8;
}

// --------------------------------------------------
// FLASH KILAT
// --------------------------------------------------

float lightningFlash(float time) {
    float flash = 0.0;

    for (float i = 0.0; i < 6.0; i += 1.0) {
        float speed =
            0.65 + i * 0.18;

        float id =
            floor(time * speed + i * 9.17);

        float randomValue =
            hash1(id + i * 2.71);

        if (randomValue > 0.66) {
            float phase =
                fract(time * speed + i * 9.17);

            flash +=
                exp(-phase * 24.0) *
                (randomValue - 0.66) *
                6.0;
        }
    }

    return flash;
}

// --------------------------------------------------
// MAIN
// --------------------------------------------------

void main() {
    vec2 fragCoord =
        FlutterFragCoord().xy;

    vec2 uv =
        fragCoord / iResolution.xy;

    vec2 p =
        uv * 2.0 - 1.0;

    // Koreksi aspect ratio
    p.x *=
        iResolution.x / iResolution.y;

    // Posisi globe
    vec2 center =
        vec2(0.0, 0.16);

    vec2 delta =
        p - center;

    float radius =
        length(delta);

    float angle =
        atan(delta.y, delta.x);

    float globeR =
        0.32;

    // Background hitam
    vec3 color =
        vec3(0.001, 0.002, 0.004);

    // --------------------------------------------------
    // ATMOSFER / GLOW
    // --------------------------------------------------

    float atmosphere =
        globeAtmosphere(
            radius,
            angle,
            iTime
        );

    vec3 atmosphereColor =
        vec3(1.0, 0.20, 0.005);

    color +=
        atmosphereColor *
        atmosphere *
        glow *
        0.75;

    // --------------------------------------------------
    // PETIR
    // --------------------------------------------------

    float bolt =
        wrappingLightning(
            angle,
            radius,
            iTime
        );

    vec3 boltAura =
        vec3(1.0, 0.22, 0.005) *
        bolt *
        1.65;

    vec3 boltWhite =
        vec3(1.0, 0.98, 0.70) *
        pow(max(bolt, 0.0), 1.35) *
        4.6;

    color +=
        boltAura;

    color +=
        boltWhite;

    // Flash lokal
    float flash =
        lightningFlash(iTime);

    color +=
        vec3(1.0, 0.52, 0.10) *
        flash *
        0.15;

    // --------------------------------------------------
    // GLOBE 3D
    // --------------------------------------------------

    if (radius < globeR) {
        vec2 sphereUV =
            delta / globeR;

        float zSquared =
            1.0 - dot(sphereUV, sphereUV);

        if (zSquared > 0.0) {
            float z =
                sqrt(zSquared);

            float cosine =
                cos(rotY);

            float sine =
                sin(rotY);

            // Rotasi permukaan globe
            vec2 rotatedXZ =
                vec2(
                    sphereUV.x * cosine - z * sine,
                    sphereUV.x * sine + z * cosine
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
                    vec3(-0.65, 0.40, 0.90)
                );

            float diffuse =
                max(
                    0.0,
                    dot(normal, lightDirection)
                );

            float frontLight =
                smoothstep(
                    -0.15,
                    0.65,
                    normal.z
                );

            float rim =
                pow(
                    1.0 - max(0.0, normal.z),
                    3.0
                );

            // Warna globe
            vec3 darkGold =
                vec3(0.12, 0.018, 0.001);

            vec3 gold =
                vec3(0.66, 0.20, 0.008);

            vec3 brightGold =
                vec3(1.0, 0.78, 0.12);

            vec3 globeColor =
                mix(
                    darkGold,
                    gold,
                    diffuse
                );

            globeColor =
                mix(
                    globeColor,
                    brightGold,
                    diffuse * frontLight * 0.78
                );

            // --------------------------------------------------
            // TEXTURE BABE.INFO
            // --------------------------------------------------

            float longitude =
                atan(
                    rotatedXZ.x,
                    rotatedXZ.y
                );

            float latitude =
                asin(
                    clamp(
                        normal.y,
                        -1.0,
                        1.0
                    )
                );

            // Koordinat texture globe
            vec2 textUV =
                vec2(
                    longitude / TWO_PI + 0.5,
                    latitude / PI + 0.5
                );

            // BABE.INFO dibuat mengelilingi globe
            textUV.x =
                fract(
                    textUV.x * 2.0 +
                    windRot * 0.04
                );

            // Jangan fract pada Y secara berlebihan.
            // Ini menjaga teks tetap berada di permukaan globe.
            textUV.y =
                clamp(
                    textUV.y * 1.4 - 0.2,
                    0.001,
                    0.999
                );

            vec4 textPixel =
    texture(
        textTexture,
        textUV
    );

// Debug: abaikan alpha PNG
float textAlpha = 1.0;

vec3 textColor =
    textPixel.rgb;

globeColor =
    mix(
        globeColor,
        textColor,
        1.0
    );


            vec3 textColor =
                vec3(1.0, 0.92, 0.36);

            // Tulisan tetap terlihat pada area gelap
            float textLighting =
                0.75 +
                diffuse * 0.60;

            globeColor =
                mix(
                    globeColor,
                    textColor * textLighting,
                    textAlpha * 0.98
                );

            // Petir memantul ke permukaan globe
            globeColor +=
                vec3(1.0, 0.35, 0.01) *
                bolt *
                0.22;

            globeColor +=
                vec3(1.0, 0.75, 0.22) *
                flash *
                0.42;

            // Rim permukaan globe
            globeColor +=
                vec3(1.0, 0.24, 0.005) *
                rim *
                1.4;

            color =
                globeColor;
        }
    }

    // Vignette, bukan atmosfer
    float vignette =
        1.0 - dot(p, p) * 0.22;

    color *=
        max(vignette, 0.0);

    color =
        pow(
            max(color, 0.0),
            vec3(0.88)
        );

    fragColor =
        vec4(color, 1.0);
}
