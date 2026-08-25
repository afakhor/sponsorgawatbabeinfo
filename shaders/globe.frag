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
    float globeRadius =
        0.32;

    float total =
        0.0;

    // Area utama di bibir globe
    float distanceFromEdge =
        radius -
        globeRadius;

    float edgeMask =
        exp(
            -abs(
                distanceFromEdge
            ) *
            110.0
        );

    // Area duri ke luar globe
    float outerMask =
        smoothstep(
            -0.01,
            0.015,
            distanceFromEdge
        ) *
        (
            1.0 -
            smoothstep(
                0.12,
                0.22,
                distanceFromEdge
            )
        );

    // Gelombang duri besar
    float spikePattern1 =
        sin(
            angle * 48.0 -
            time * 4.0
        ) *
        0.5 +
        0.5;

    float spikePattern2 =
        sin(
            angle * 83.0 +
            time * 6.0
        ) *
        0.5 +
        0.5;

    float spikePattern3 =
        sin(
            angle * 137.0 -
            time * 8.0
        ) *
        0.5 +
        0.5;

    // Gabungan bentuk duri
    float spikes =
        spikePattern1 *
        0.50
        +
        spikePattern2 *
        0.30
        +
        spikePattern3 *
        0.20;

    spikes =
        smoothstep(
            0.56,
            0.84,
            spikes
        );

    // Membuat sebagian duri lebih panjang
    float longSpikes =
        pow(
            spikePattern2,
            8.0
        ) *
        smoothstep(
            0.65,
            0.90,
            spikePattern1
        );

    // Bentuk duri memanjang keluar dari permukaan
    float spikeShape =
        exp(
            -max(
                distanceFromEdge,
                0.0
            ) *
            25.0
        );

    // Jalur listrik utama yang bergerak
    float flowingPath =
        sin(
            angle * 14.0 -
            time * 5.0 +
            radius * 90.0
        ) *
        0.5 +
        0.5;

    flowingPath =
        smoothstep(
            0.44,
            0.80,
            flowingPath
        );

    // Inti duri terang
    float spikeCore =
        spikes *
        spikeShape *
        outerMask *
        flowingPath;

    // Aura duri
    float spikeAura =
        spikes *
        exp(
            -max(
                distanceFromEdge,
                0.0
            ) *
            12.0
        ) *
        outerMask;

    // Beberapa duri panjang seperti pentol
    float largeSpike =
        longSpikes *
        exp(
            -max(
                distanceFromEdge,
                0.0
            ) *
            18.0
        ) *
        outerMask;

    total +=
        spikeCore *
        5.5;

    total +=
        spikeAura *
        1.45;

    total +=
        largeSpike *
        3.0;

    // Ring tipis sebagai bibir mangkok
    float rim =
        exp(
            -abs(
                distanceFromEdge
            ) *
            190.0
        );

    total +=
        rim *
        0.85;

    // Petir menempel pada permukaan globe
    total +=
        edgeMask *
        spikes *
        1.5;

    return total;
}

// --------------------------------------------------
// ATMOSFER BERLAWANAN ARAH DENGAN GLOBE
// --------------------------------------------------

float globeAtmosphere(
    float radius,
    float angle,
    float time
) {
    float globeRadius =
        0.32;

    float distanceFromGlobe =
        radius -
        globeRadius;

    // Atmosfer melebar ke segala arah
    float wideSmoke =
        exp(
            -max(
                distanceFromGlobe,
                0.0
            ) *
            9.5
        );

    // Asap padat dekat permukaan
    float denseSmoke =
        exp(
            -abs(
                distanceFromGlobe
            ) *
            23.0
        );

    // Gumpalan asap besar
    float cloud1 =
        sin(
            angle * 3.0 +
            time * 1.8 +
            radius * 17.0
        ) *
        0.5 +
        0.5;

    float cloud2 =
        sin(
            angle * 6.0 -
            time * 2.7 +
            radius * 31.0
        ) *
        0.5 +
        0.5;

    float cloud3 =
        sin(
            angle * 11.0 +
            time * 4.4 -
            radius * 54.0
        ) *
        0.5 +
        0.5;

    float cloud4 =
        sin(
            angle * 19.0 -
            time * 6.2 +
            radius * 83.0
        ) *
        0.5 +
        0.5;

    // Noise asap bertingkat
    float smokeNoise =
        cloud1 * 0.40 +
        cloud2 * 0.28 +
        cloud3 * 0.20 +
        cloud4 * 0.12;

    smokeNoise =
        smoothstep(
            0.28,
            0.76,
            smokeNoise
        );

    // Asap lebih padat dan menyatu
    float packedSmoke =
        wideSmoke *
        smokeNoise;

    // Lapisan asap kedua agar atmosfer tidak kosong
    float secondarySmoke =
        denseSmoke *
        smoothstep(
            0.22,
            0.72,
            cloud1 * 0.65 +
            cloud2 * 0.35
        );

    // Ring atmosfer lembut
    float softRing =
        exp(
            -abs(
                radius -
                0.335
            ) *
            90.0
        );

    // Batas penyebaran atmosfer
    float spreadMask =
        1.0 -
        smoothstep(
            0.40,
            0.62,
            radius
        );

    return (
        packedSmoke *
        1.70
        +
        secondarySmoke *
        1.10
        +
        softRing *
        0.85
    ) *
    spreadMask;
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
        0.24,
        0.008
    );

color +=
    atmosphereColor *
    atmosphere *
    glow *
    1.45;


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
        0.12,
        0.002
    ) *
    bolt *
    2.10;


    vec3 boltCore =
    vec3(
        1.0,
        0.88,
        0.38
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

// Arah texture berlawanan dari gerakan windRot
textUV.x =
    fract(
        textUV.x -
        windRot *
        0.04
    );

// PNG berisi tiga BABE vertikal.
// Ambil seluruh texture agar tiga tulisan terlihat.
textUV.y =
    clamp(
        textUV.y,
        0.001,
        0.999
    );

vec4 textPixel =
    texture(
        textTexture,
        textUV
    );

float textAlpha =
    smoothstep(
        0.015,
        0.12,
        textPixel.a
    );

vec3 textColor =
    vec3(
        1.0,
        0.82,
        0.25
    );

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
