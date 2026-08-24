#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;
uniform float windRot;
uniform float glow;

out vec4 fragColor;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float hash1(float p){ return fract(sin(p*127.1)*43758.5453); }
float noise(vec2 p){
    vec2 i=floor(p); vec2 f=fract(p);
    float a=hash(i), b=hash(i+vec2(1.0,0.0)), c=hash(i+vec2(0.0,1.0)), d=hash(i+vec2(1.0,1.0));
    vec2 u=f*f*(3.0-2.0*f);
    return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
}

// Petir bercabang mengerikan
float lightning(vec2 p, float ang, float r, float t){
    float bolt = 0.0;
    // 3 petir utama acak
    for(float i=0.0; i<3.0; i++){
        float seed = i*7.0;
        float strikeSpeed = 2.3 + seed*0.4;
        float strikeTime = floor(iTime*strikeSpeed + seed);
        float strikeTrigger = hash1(strikeTime);
        
        // Hanya nyamber kalau hash > 0.82 -> jeda mengerikan
        if(strikeTrigger > 0.82){
            float baseAng = hash1(strikeTime+1.0)*6.283 - 3.1415;
            float angDiff = abs(ang - baseAng);
            angDiff = min(angDiff, 6.283-angDiff);
            
            // Zigzag petir
            float zigzag = sin(r*18.0 - iTime*25.0 + seed*3.0)*0.15;
            float mainBolt = smoothstep(0.15, 0.0, abs(angDiff + zigzag) - 0.02);
            mainBolt *= smoothstep(1.8, 0.2, r) * smoothstep(0.1, 0.4, r);
            
            // Cabang-cabang kecil
            float branch = sin(ang*12.0 + r*20.0 + seed)*0.5+0.5;
            branch = pow(branch, 8.0) * mainBolt * 0.6;
            
            float intensity = pow(strikeTrigger, 3.0) * 4.0;
            bolt += (mainBolt + branch) * intensity;
        }
    }
    return bolt;
}

void main(){
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv*2.0-1.0;
    p.x *= iResolution.x/iResolution.y;
    vec2 center = vec2(0.0,0.22);
    vec2 d = p-center;
    float r = length(d);
    float ang = atan(d.y,d.x);
    float globeR = 0.52;
    vec3 col = vec3(0.008,0.008,0.01); // lebih hitam pekat biar kilat nyala

    // MARMER HITAM RETAK
    float m = noise(p*1.1*2.2 + iTime*0.01);
    float veins = pow(sin(p.x*2.2+m*6.0)*0.5+0.5, 12.0);
    col += vec3(0.85,0.65,0.15)*veins*0.5;

    // === ATMOSFER MENGGELEGAR ===
    float atmosAccum = 0.0;
    for(float i=0.0;i<4.0;i++){
        float t = windRot*(0.7+i*0.18);
        float rr = r*(0.88+i*0.15);
        float distort = noise(vec2(ang*2.0, rr*3.0 + iTime*0.5))*0.4;
        float aa = ang - t + rr*(2.2+i*0.3) + distort;
        float swirl = sin(aa*(2.5+i*0.4)+rr*4.0 + noise(vec2(aa*2.0, iTime))*2.0)*0.5+0.5;
        swirl = pow(swirl, 1.5);
        float mask = smoothstep(1.25, 0.38, rr) * smoothstep(0.18, 0.52, rr);
        mask *= 0.6/(0.3+i*0.3);
        vec3 gold = vec3(1.0,0.78,0.08)*swirl*mask;
        gold += vec3(1.0,0.9,0.4)*pow(swirl,5.0)*mask*1.8;
        col += gold*glow*0.6;
        atmosAccum += mask*swirl;
    }

    // === KILATAN PETIR MENAKUTKAN - DI LUAR BOLA ===
    float bolt = lightning(p, ang, r, iTime);
    vec3 lightningCol = vec3(1.0,0.95,0.7)*bolt*3.0 + vec3(1.0,0.92,0.3)*pow(bolt,2.0)*6.0;
    // Outer glow petir
    vec3 lightningGlow = vec3(1.0,0.82,0.15)*bolt*0.8;
    col += lightningCol;
    col += lightningGlow;

    // FLASH SELURUH LAYAR PAS PETIR NYAMBER - bikin jantung copot
    float flashTrigger = 0.0;
    for(float i=0.0;i<3.0;i++){
        float ft = floor(iTime*(2.1+i*0.3)+i*4.0);
        if(hash1(ft) > 0.85){
            float f = fract(iTime*(2.1+i*0.3)+i*4.0);
            float flash = exp(-f*18.0) * hash1(ft+2.0);
            flashTrigger += flash;
        }
    }
    col += vec3(1.0,0.92,0.6)*flashTrigger*0.35;
    col += vec3(0.8,0.7,0.3)*flashTrigger*atmosAccum*0.5;

    // GLOBE EMAS
    if(r < globeR){
        vec2 sUV = d/globeR;
        float z2 = 1.0-dot(sUV,sUV);
        if(z2>0.0){
            float z = sqrt(z2);
            float c = cos(rotY); float s = sin(rotY);
            vec2 xz = vec2(sUV.x*c - z*s, sUV.x*s + z*c);
            vec3 n = vec3(xz.x, sUV.y, xz.y);
            float diff = max(0.0, dot(n, normalize(vec3(-0.6,0.4,0.9))));
            vec3 base = mix(vec3(0.45,0.32,0.05), vec3(1.0,0.84,0.18), diff);
            float edge = smoothstep(globeR+0.01, globeR-0.02, r);
            // Kilat bikin globe kedip
            base += flashTrigger*0.4;
            col = mix(col, base, edge);
        }
    }

    // Vignette horror
    col *= 1.0 - dot(p,p)*0.32;
    col = pow(col, vec3(0.92)); // contrast tinggi

    fragColor = vec4(col,1.0);
}