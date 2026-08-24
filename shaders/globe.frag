#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;
uniform float windRot;
uniform float glow;

out vec4 fragColor;

#define PI 3.14159265359

mat2 rotate2D(float a){ float c=cos(a), s=sin(a); return mat2(c,-s,s,c); }
float hash21(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float noise2D(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); float a=hash21(i), b=hash21(i+vec2(1,0)), c=hash21(i+vec2(0,1)), d=hash21(i+vec2(1,1)); return mix(mix(a,b,f.x), mix(c,d,f.x), f.y); }
float fbm(vec2 p){ float v=0., a=0.5; for(int i=0;i<5;i++){ v+=noise2D(p)*a; p=p*2.02+vec2(17.1,9.2); a*=0.5; } return v; }
float circularMask(float dist, float rad){ return 1.0 - smoothstep(rad-0.008, rad+0.008, dist); }

void main(){
    vec2 uv = FlutterFragCoord().xy / iResolution.xy;
    vec2 p = uv*2.0-1.0;
    p.x *= iResolution.x / iResolution.y;

    vec2 globeCenter = vec2(0.0, 0.22); // Naik sedikit
    vec2 d = p - globeCenter;
    float r = length(d);
    float angle = atan(d.y, d.x);

    // FIX UTAMA: BOLA KECIL
    float globeRadius = 0.31;

    // --- BACKGROUND MARBLE ---
    vec2 marbleUV = p * 2.4;
    float marble = fbm(marbleUV * 1.25);
    float veinA = sin(marbleUV.x*3.0 + marbleUV.y*1.4 + marble*7.0);
    float veinB = sin(marbleUV.y*2.1 - marbleUV.x*1.1 + marble*5.0);
    float veins = pow(abs(veinA*veinB), 7.0);
    float thinVeins = pow(max(0.0, sin(marbleUV.x*5.0 + marble*10.0)), 18.0);
    vec3 background = vec3(0.006);
    background += vec3(0.13,0.075,0.018)*veins;
    background += vec3(0.48,0.30,0.075)*thinVeins;
    float grain = hash21(FlutterFragCoord().xy*0.45);
    background += vec3(grain)*0.015;
    vec3 color = background;

    // --- FIX ATMOSPHERE DENGAN LUBANG / HOLE ---
    float wind = 0.0;
    // Buat mask lubang: atmosfer hanya di luar bola + jarak
    float holeMask = smoothstep(globeRadius + 0.04, globeRadius + 0.18, r);
    // Mask luar biar tidak full screen
    float outerMask = smoothstep(1.4, 0.45, r);

    for(int i=0;i<6;i++){
        float fi=float(i);
        float localRadius = r * (0.88 + fi*0.11);
        float localAngle = angle - windRot*(0.50 + fi*0.07) + localRadius*(2.2 + fi*0.2);
        vec2 swirlUV = vec2(cos(localAngle)*localRadius, sin(localAngle)*localRadius);
        swirlUV += vec2(windRot*0.22, -windRot*0.12);
        float cloud = fbm(swirlUV*(3.2 + fi*0.2) + vec2(0.0, windRot*0.5));
        float ribbon = sin(localAngle*(2.5+fi*0.18) + cloud*5.0 + localRadius*7.0);
        ribbon = smoothstep(0.45, 0.90, ribbon*0.5+0.5);
        float cloudMask = smoothstep(0.48, 0.78, cloud);
        float line = ribbon * cloudMask * holeMask * outerMask;

        float dust = hash21(vec2(floor(localAngle*20.0), floor(localRadius*45.0)+fi*12.0));
        dust = pow(dust, 5.0) * holeMask * outerMask * smoothstep(0.65, 0.95, cloud);

        vec3 atmosphereGold = mix(vec3(0.72,0.38,0.035), vec3(1.0,0.88,0.42), ribbon);
        color += atmosphereGold * line * glow * 0.85;
        color += vec3(1.0,0.76,0.22)*dust*glow*3.5;
    }
    float aura = exp(-r*3.0)*0.18 * holeMask;
    color += vec3(1.0,0.47,0.06)*aura*glow;

    // --- GLOBE KECIL DI DALAM HOLE ---
    if(r < globeRadius + 0.03){
        vec2 sphereUV = d / globeRadius;
        float z2 = 1.0 - dot(sphereUV, sphereUV);
        if(z2 > 0.0){
            float z = sqrt(z2);
            vec3 normal = vec3(sphereUV.x, sphereUV.y, z);
            normal.xz = rotate2D(rotY)*normal.xz;
            vec3 lightDir = normalize(vec3(-0.52,0.42,0.92));
            float diffuse = max(0.0, dot(normal, lightDir));
            vec3 viewDir = vec3(0.0,0.0,1.0);
            float specular = pow(max(0.0, dot(reflect(-lightDir, normal), viewDir)), 58.0);
            float fresnel = pow(1.0 - max(0.0, dot(normal, viewDir)), 3.0);

            vec3 darkGold = vec3(0.25,0.105,0.012);
            vec3 brightGold = vec3(0.95,0.58,0.105);
            vec3 globeColor = mix(darkGold, brightGold, smoothstep(0.05,0.98,diffuse));
            globeColor += vec3(1.0,0.78,0.30)*specular*1.4;
            globeColor = mix(globeColor, globeColor*0.42, fresnel*0.55);
            float surfaceNoise = fbm(sphereUV*8.0 + vec2(rotY*0.2));
            globeColor += vec3(0.15,0.075,0.012)*surfaceNoise*0.16;

            float globeMask = circularMask(r, globeRadius);
            color = mix(color, globeColor, globeMask);
            float rim = 1.0 - smoothstep(0.0,0.06, abs(r-globeRadius));
            color += vec3(1.0,0.70,0.18)*rim*0.45;
        }
    }

    // --- THORN CROWN NEMPEL KETAT ---
    float crownRadius = globeRadius + 0.02;
    float crownDist = abs(r - crownRadius);
    if(crownDist < 0.045){
        float thornAngle = angle*28.0 + rotY*1.25;
        float thornShape = smoothstep(0.68,0.98, sin(thornAngle)*0.5+0.5);
        float crownMask = smoothstep(0.045,0.005,crownDist) * thornShape;
        vec3 crownColor = vec3(0.006,0.004,0.002) + vec3(0.10,0.055,0.012)*thornShape;
        color = mix(color, crownColor, crownMask*0.96);
    }

    float vignette = 1.0 - smoothstep(0.45,1.45,length(p*vec2(0.72,0.84)));
    color *= 0.70 + vignette*0.42;
    color = pow(color, vec3(0.91));
    fragColor = vec4(color,1.0);
}