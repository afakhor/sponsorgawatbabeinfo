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
// PETIR YANG MENYELIMUTI GLOBE
// --------------------------------------------------

float wrappingLightning(
    float angle,
    float radius,
    float time
) {
    float total = 0.0;

    // Petir berada di sekitar tepi globe
    float surfaceMask =
        smoothstep(
            0.275,
            0.315,
            radius
        );

    float outerMask =
        1.0 -
        smoothstep(
            0.315,
            0.43,
            radius
        );

    float wrapMask =
        surfaceMask *
        outerMask;

    for (float i = 0.0; i < 10.0; i += 1.0) {
        float seed =
            i * 23.731;

        float speed =
            0.35 +
            i * 0.11;

        float strike =
            floor(
                time * speed +
                seed
            );

        float chance =
            hash1(
                strike +
                seed
            );

        // Mengatur jumlah sambaran
        if (chance > 0.30) {
            float baseAngle =
                hash1(
                    strike +
                    seed +
                    4.0
                ) *
                TWO_PI;

            float phase =
                fract(
                    time * speed +
                    seed
                );

            // Denyut pendek seperti kilatan
            float pulse =
                exp(
                    -phase * 13.0
                );

            // Jalur utama zig-zag
            float path =
                sin(
                    radius * 160.0 +
                    time * 17.0 +
                    seed
                ) * 0.070
              + sin(
                    radius * 290.0 -
                    time * 29.0 +
                    seed * 1.7
                ) * 0.040
              + sin(
                    radius * 470.0 +
                    time * 43.0 +
                    seed * 2.2
                ) * 0.020;

            float lightningAngle =
                baseAngle +
                path;

            float distanceMain =
                angularDistance(
                    angle,
                    lightningAngle
                );

            // Inti petir
            float core =
                smoothstep(
                    0.020,
                    0.0,
                    distanceMain
                );

            // Cahaya aura
            float aura =
                smoothstep(
                    0.105,
                    0.0,
                    distanceMain
                );

            // Cabang petir
            float branchWave1 =
                sin(
                    angle * 34.0 +
                    radius * 210.0 +
                    seed
                ) * 0.5 + 0.5;

            float branch1 =
                pow(
                    branchWave1,
                    18.0
                ) *
                aura;

            float branchWave2 =
                sin(
                    angle * 57.0 -
                    radius * 330.0 +
                    seed * 2.0
                ) * 0.5 + 0.5;

            float branch2 =
                pow(
                    branchWave2,
                    23.0
                ) *
                aura;

            // Ekor memanjang mengikuti lengkungan globe
            float tailWave =
                sin(
                    angle * 15.0 +
                    radius * 95.0 -
                    time * 20.0 +
                    seed
                ) * 0.5 + 0.5;

            float tail =
                pow(
                    tailWave,
                    12.0
                ) *
                smoothstep(
                    0.095,
                    0.0,
                    distanceMain
                );

            total +=
                (
                    core * 7.0 +
                    aura * 1.25 +
                    branch1 * 3.0 +
                    branch2 * 2.0 +
                    tail * 1.5
                ) *
                pulse;
        }
    }

    // Aliran listrik tipis tambahan
    float electricBand =
        sin(
            angle * 22.0 +
            radius * 115.0 -
            time * 15.0
        ) * 0.5 + 0.5;

    electricBand =
        pow(
            electricBand,
            22.0
        );

    electricBand *=
        smoothstep(
            0.285,
            0.32,
            radius
        ) *
        (
            1.0 -
            smoothstep(
                0.32,
                0.39,
                radius
            )
        );

    total +=
        electricBand *
        2.0;

    return total * wrapMask;
}

// --------------------------------------------------
// ATMOSFER BERLAWANAN ARAH DENGAN GLOBE
// --------------------------------------------------

float globeAtmosphere(
    float radius,
    float angle,
    float time
) {
    float edgeDistance =
        abs(
            radius -
            0.32
        );

    // Cahaya lembut di sekitar tepi globe
    float softGlow =
        exp(
            -edgeDistance *
            30.0
        );

    // Garis atmosfer bergerak berlawanan
    // dengan rotasi globe
    float flow1 =
        sin(
            angle * 7.0 +
            time * 3.5 +
            sin(
                angle * 2.0 -
                time * 1.2
            ) *
            0.7
        );

    float flow2 =
        sin(
            angle * 15.0 +
            time * 5.0 +
            radius * 80.0
        );

    float flow3 =
        sin(
            angle * 28.0 +
            time * 7.5 -
            radius * 135.0
        );

    float flowingLines =
        flow1 * 0.55 +
        flow2 * 0.30 +
        flow3 * 0.15;

    flowingLines =
        flowingLines *
        0.5 +
        0.5;

    flowingLines =
        smoothstep(
            0.54,
            0.82,
            flowingLines
        );

    // Ring atmosfer yang tipis
    float sharpRing =
        exp(
            -abs(
                radius -
                0.326
            ) *
            180.0
        );

    // Membatasi atmosfer di dekat globe
    float atmosphereMask =
        smoothstep(
            0.245,
            0.305,
            radius
        ) *
        (
            1.0 -
            smoothstep(
                0.335,
                0.47,
                radius
            )
        );

    return (
        softGlow *
        flowingLines *
        0.85
        +
        sharpRing *
        1.10
    ) *
    atmosphereMask;
}

// --------------------------------------------------
// FLASH GLOBAL
// --------------------------------------------------

float lightningFlash(float time) {
    float flash = 0.0;

    for (float i = 0.0; i < 8.0; i += 1.0) {
        float speed =
            0.55 +
            i * 0.19;

        float id =
            floor(
                time * speed +
                i * 13.17
            );

        float randomValue =
            hash1(
                id +
                i * 3.71
            );

        if (randomValue > 0.63) {
            float phase =
                fract(
                    time * speed +
                    i * 13.17
                );

            flash +=
                exp(
                    -phase * 28.0
                ) *
                (
                    randomValue -
                    0.63
                ) *
                7.0;
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
        fragCoord /
        iResolution.xy;

    vec2 p =
        uv * 2.0 -
        1.0;

    // Koreksi aspect ratio
    p.x *=
        iResolution.x /
        iResolution.y;

    // Posisi globe
    vec2 center =
        vec2(
            0.0,
            0.12
        );

    vec2 delta =
        p -
        center;

    float radius =
        length(delta);

    float angle =
        atan(
            delta.y,
            delta.x
        );

    float globeR =
        0.32;

    // --------------------------------------------------
    // BACKGROUND
    // --------------------------------------------------

    vec3 color =
        vec3(
            0.001,
            0.0015,
            0.003
        );

    // Partikel kecil di background
    float stars =
        hash2(
            floor(
                p * 110.0
            )
        );

    float starMask =
        step(
            0.985,
            stars
        );

    color +=
        vec3(
            1.0,
            0.40,
            0.05
        ) *
        starMask *
        0.45;

    // --------------------------------------------------
    // ATMOSFER LUAR
    // --------------------------------------------------

    float atmosphere =
        globeAtmosphere(
            radius,
            angle,
            iTime
        );

    vec3 atmosphereColor =
        vec3(
            1.0,
            0.19,
            0.005
        );

    color +=
        atmosphereColor *
        atmosphere *
        glow *
        0.95;

    // --------------------------------------------------
    // PETIR DI LUAR GLOBE
    // --------------------------------------------------

    float bolt =
        wrappingLightning(
            angle,
            radius,
            iTime
        );

    vec3 boltAura =
        vec3(
            1.0,
            0.16,
            0.002
        ) *
        bolt *
        1.85;

    vec3 boltCore =
        vec3(
            1.0,
            0.96,
            0.62
        ) *
        pow(
            max(
                bolt,
                0.0
            ),
            1.35
        ) *
        4.8;

    color +=
        boltAura;

    color +=
        boltCore;

    // Kilatan global
    float flash =
        lightningFlash(
            iTime
        );

    color +=
        vec3(
            1.0,
            0.38,
            0.025
        ) *
        flash *
        0.22;

    // --------------------------------------------------
    // PERMUKAAN GLOBE 3D
    // --------------------------------------------------

    if (radius < globeR) {
        vec2 sphereUV =
            delta /
            globeR;

        float zSquared =
            1.0 -
            dot(
                sphereUV,
                sphereUV
            );

        if (zSquared > 0.0) {
            float z =
                sqrt(
                    zSquared
                );

            float c =
                cos(
                    rotY
                );

            float s =
                sin(
                    rotY
                );

            // Rotasi globe
            vec2 rotatedXZ =
                vec2(
                    sphereUV.x * c -
                    z * s,

                    sphereUV.x * s +
                    z * c
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
                    vec3(
                        -0.65,
                        0.40,
                        0.90
                    )
                );

            float diffuse =
                max(
                    0.0,
                    dot(
                        normal,
                        lightDirection
                    )
                );

            float frontLight =
                smoothstep(
                    -0.20,
                    0.70,
                    normal.z
                );

            float rim =
                pow(
                    1.0 -
                    max(
                        0.0,
                        normal.z
                    ),
                    3.0
                );

            // Warna emas globe
            vec3 darkGold =
                vec3(
                    0.055,
                    0.006,
                    0.001
                );

            vec3 gold =
                vec3(
                    0.40,
                    0.075,
                    0.003
                );

            vec3 brightGold =
                vec3(
                    1.0,
                    0.58,
                    0.045
                );

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
                    diffuse *
                    frontLight *
                    0.82
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

vec2 textUV =
    vec2(
        longitude /
        TWO_PI +
        0.5,

        latitude /
        PI +
        0.5
    );

// Satu rangkaian texture mengelilingi globe.
// Gunakan 1.0 agar tidak terlalu banyak pengulangan.
textUV.x =
    fract(
        textUV.x +
        windRot *
        0.04
    );

// Gunakan seluruh tinggi texture.
// Karena PNG berisi:
//
// BABE
// BABE
// BABE
//
// ketiganya akan tampil vertikal pada globe.
textUV.y =
    clamp(
        textUV.y,
        0.001,
        0.999
    );

// Jika posisi tulisan terbalik atas-bawah,
// gunakan baris ini sebagai pengganti baris di atas:
//
// textUV.y =
//     clamp(
//         1.0 - textUV.y,
//         0.001,
//         0.999
//     );

vec4 textPixel =
    texture(
        textTexture,
        textUV
    );

// Alpha berasal dari background transparan PNG
float textAlpha =
    smoothstep(
        0.015,
        0.12,
        textPixel.a
    );

// Warna tulisan
vec3 textColor =
    vec3(
        1.0,
        0.82,
        0.25
    );

// Pencahayaan tulisan mengikuti permukaan globe
float textLight =
    0.80 +
    diffuse *
    0.65;

globeColor =
    mix(
        globeColor,
        textColor *
        textLight,
        textAlpha *
        0.96
    );


            // --------------------------------------------------
            // PETIR MEMANTUL PADA PERMUKAAN
            // --------------------------------------------------

            globeColor +=
                vec3(
                    1.0,
                    0.20,
                    0.005
                ) *
                bolt *
                0.30;

            globeColor +=
                vec3(
                    1.0,
                    0.72,
                    0.16
                ) *
                flash *
                0.48;

            // Rim emas
            globeColor +=
                vec3(
                    1.0,
                    0.18,
                    0.002
                ) *
                rim *
                1.55;

            color =
                globeColor;
        }
    }

    // --------------------------------------------------
    // VIGNETTE DAN COLOR GRADING
    // --------------------------------------------------

    float vignette =
        1.0 -
        dot(
            p,
            p
        ) *
        0.20;

    color *=
        max(
            vignette,
            0.0
        );

    color =
        pow(
            max(
                color,
                0.0
            ),
            vec3(
                0.86
            )
        );

    fragColor =
        vec4(
            color,
            1.0
        );
}
