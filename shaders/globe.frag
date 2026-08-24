#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;
uniform float glow;

out vec4 fragColor;

#define PI 3.14159265359
mat2 rot2D(float a){ float c=cos(a), s=sin(a); return mat2(c,-s,s,c); }

// Noise emas
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5); }
float noise(vec2 p){
    vec2 i = floor(p); vec2 f = fract(p);
    float a = hash(i); float b = hash(i+vec2(1.0,0.0));
    float c = hash(i+vec2(0.0,1.0)); float d = hash(i+vec2(1.0,1.0));
    vec2 u = f*f*(3.0-2.0*f);
    return mix(a,b,u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
}

void main(){
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    vec2 center = vec2(0.0, 0.25);
    vec2 d = p - center;
    float r = length(d);
    float ang = atan(d.y, d.x);

    vec3 col = vec3(0.0);

    // === BACKGROUND MARMER HITAM URAT EMAS ===
    vec2 marbleUV = p * 1.2 + vec2(iTime*0.02, 0.0);
    float marble = noise(marbleUV * 2.5);
    float veins = sin(marbleUV.x * 3.0 + marble * 4.0) * 0.5 + 0.5;
    veins = pow(veins, 8.0) * 2.0;
    vec3 marbleCol = vec3(0.02, 0.02, 0.025) + vec3(0.8, 0.6, 0.15) * veins * 0.9;
    marbleCol += vec3(0.15,0.12,0.08) * marble * 0.2;
    col = marbleCol;

    // === ANGIN ATMOSFER EMAS MULUK - PUSARAN ===
    for(float i=0.0; i<3.0; i++){
        float t = iTime * (0.08 + i*0.04);
        float rr = r * (0.8 + i*0.25);
        float aa = ang + rr * (1.5 + i*0.5) + t;
        float swirl = sin(aa * (2.0 + i) + rr * 4.0) * 0.5 + 0.5;
        float mask = smoothstep(1.8, 0.4, rr) * smoothstep(0.2, 0.5, rr);
        mask *= 0.6 / (0.3 + i*0.3);
        vec3 goldSwirl = vec3(1.0,0.84,0.15) * swirl * mask;
        goldSwirl += vec3(1.0,0.95,0.6) * pow(swirl, 3.0) * mask * 1.2;
        // Partikel debu emas
        float dust = hash(vec2(aa*5.0, rr*8.0 + t)) * step(0.7, swirl);
        goldSwirl += vec3(1.0,0.9,0.4) * dust * mask * 2.0;
        col += goldSwirl * glow;
    }

    // === GLOBE BABE.INFO ===
    float globeR = 0.52;
    float dist = r;
    if(dist < globeR){
        vec2 sUV = d / globeR;
        float z = sqrt(max(0.0, 1.0 - dot(sUV, sUV)));
        vec3 normal = vec3(sUV, z);

        // Rotate
        float ry = rotY + iTime * 0.28;
        normal.xz = rot2D(ry) * normal.xz;

        // Sphere shading
        vec3 lightDir = normalize(vec3(-0.5, -0.3, 0.9));
        float diff = max(0.0, dot(normal, lightDir));
        float spec = pow(max(0.0, dot(reflect(-lightDir, normal), vec3(0.0,0.0,1.0))), 48.0);

        // Base emas
        vec3 base = mix(vec3(0.6,0.45,0.08), vec3(1.0,0.84,0.0), diff);
        base = mix(base, vec3(1.0,0.95,0.65), spec);

        // UKIRAN BABE.INFO - simulasi text berulang dengan noise pattern
        float lon = atan(normal.z, normal.x);
        float lat = asin(normal.y);
        float textPattern = 0.0;
        // Buat baris-baris text BABE.INFO
        for(float row=-2.0; row<=2.0; row+=1.0){
            float latBand = abs(lat - row*0.4);
            if(latBand < 0.22){
                float repeatLon = lon * 3.0 + iTime*0.0; // 3x pengulangan
                float stripe = sin(repeatLon * 8.0) * 0.5 + 0.5;
                stripe = smoothstep(0.45, 0.55, stripe);
                textPattern += stripe * smoothstep(0.22, 0.12, latBand) * 0.5;
            }
        }
        // Emboss effect
        float emboss = textPattern * 0.35;
        base += emboss * 0.3;
        base -= textPattern * 0.15;

        // Darken edges
        float fresnel = pow(1.0 - max(0.0, dot(normal, vec3(0.0,0.0,1.0))), 2.0);
        base = mix(base, base * 0.6, fresnel * 0.5);

        col = mix(col, base, smoothstep(globeR+0.02, globeR-0.01, dist));
        
        // Highlight globe
        col += vec3(1.0,0.95,0.6) * smoothstep(0.03, 0.0, abs(dist - globeR)) * 0.5;
    }

    // === MAHKOTA DURI HITAM ===
    float crownR = globeR + 0.03;
    float crownDist = abs(r - crownR);
    if(crownDist < 0.045){
        float thornAng = ang * 16.0; // 16 duri
        float thorns = sin(thornAng) * 0.5 + 0.5;
        thorns = pow(thorns, 4.0);
        float thornMask = smoothstep(0.045, 0.01, crownDist) * (0.3 + thorns * 1.2);
        // Duri hitam mengkilat
        vec3 thornCol = vec3(0.04,0.04,0.05) + vec3(0.15) * thorns;
        col = mix(col, thornCol, thornMask * 0.95);
        // Highlight duri
        col += vec3(0.3) * thorns * thornMask * smoothstep(0.6, 0.0, crownDist) * 0.5;
    }

    // Outer glow atmosphere
    float outerGlow = smoothstep(0.15, 0.0, abs(r - (globeR + 0.12))) * 0.4;
    col += vec3(1.0,0.84,0.0) * outerGlow * glow;

    // Vignette
    col *= 1.0 - dot(p,p) * 0.18;

    fragColor = vec4(col, 1.0);
}