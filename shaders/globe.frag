#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;      // + untuk globe
uniform float windRot;   // - untuk atmosfer, ini kuncinya berlawanan
uniform float glow;

out vec4 fragColor;

#define PI 3.14159265359
mat2 rot2D(float a){ float c=cos(a), s=sin(a); return mat2(c,-s,s,c); }

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p){
    vec2 i=floor(p); vec2 f=fract(p);
    float a=hash(i), b=hash(i+vec2(1.0,0.0));
    float c=hash(i+vec2(0.0,1.0)), d=hash(i+vec2(1.0,1.0));
    vec2 u=f*f*(3.0-2.0*f);
    return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
}

// SDF huruf BABE.INFO palsu tapi terlihat emboss
float babePattern(vec2 uv) {
    // uv.x = longitude, uv.y = latitude
    float line = fract(uv.y * 5.0); // 5 baris
    float id = floor(uv.y * 5.0);
    float rep = fract(uv.x * 3.5 + id*0.7); // 3.5x pengulangan per lingkaran
    
    float letter = step(0.15, rep) * step(rep, 0.85) * step(0.25, line) * step(line, 0.75);
    // Variasi tebal untuk B A B E . I N F O
    float mod = sin(rep * 35.0);
    letter *= smoothstep(0.0, 0.3, mod);
    return letter;
}

void main(){
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    vec2 center = vec2(0.0, 0.22);
    vec2 d = p - center;
    float r = length(d);
    float ang = atan(d.y, d.x);

    vec3 col = vec3(0.0);
    float globeR = 0.52;

    // === BACKGROUND MARMER HITAM URAT EMAS (Statis + slow drift) ===
    vec2 marbleUV = p * 1.1;
    marbleUV += vec2(noise(p*0.5 + iTime*0.02)) * 0.2;
    float marble = noise(marbleUV * 2.8);
    float veins = sin(marbleUV.x*2.2 + marble*6.0) * 0.5 + 0.5;
    veins = pow(veins, 12.0);
    float veins2 = sin(marbleUV.y*1.8 + marble*4.0) * 0.5 + 0.5;
    veins2 = pow(veins2, 10.0);
    vec3 marbleCol = vec3(0.015, 0.015, 0.018);
    marbleCol += vec3(0.85, 0.65, 0.15) * veins * 1.2;
    marbleCol += vec3(0.6, 0.45, 0.1) * veins2 * 0.6;
    marbleCol += vec3(0.08,0.06,0.04) * marble * 0.15;
    col = marbleCol;

    // === ANGIN ATMOSFER EMAS - BERLAWANAN ARAH GLOBE ===
    // windRot negatif, globe rotY positif
    float atmosphere = 0.0;
    for(float i=0.0; i<4.0; i++){
        float t = windRot * (0.6 + i*0.15); // <--- PAKAI windRot, bukan iTime
        float rr = r * (0.85 + i*0.2);
        // Spiral berlawanan: ang - t
        float aa = ang - t + rr * (1.8 + i*0.4);
        float swirl = sin(aa * (1.5 + i*0.5) + rr*3.0) * 0.5 + 0.5;
        float mask = smoothstep(1.7, 0.45, rr) * smoothstep(0.15, 0.55, rr);
        mask *= 0.7 / (0.4 + i*0.35);
        
        vec3 gold = vec3(1.0, 0.82, 0.08) * swirl * mask;
        gold += vec3(1.0, 0.92, 0.5) * pow(swirl, 4.0) * mask * 1.5;
        
        // Debu bintang emas
        float dust = hash(vec2(aa*6.0, rr*10.0 + t*2.0));
        dust = pow(dust, 3.0) * step(0.75, swirl);
        gold += vec3(1.0,0.9,0.3) * dust * mask * 3.0;
        
        col += gold * glow;
        atmosphere += mask * swirl;
    }

    // === GLOBE BABE.INFO - PUTAR KE KANAN ===
    if(r < globeR + 0.04){
        vec2 sUV = d / globeR;
        float z2 = 1.0 - dot(sUV, sUV);
        if(z2 > 0.0){
            float z = sqrt(z2);
            vec3 normal = vec3(sUV, z);

            // ROTASI GLOBE KE KANAN
            normal.xz = rot2D(rotY) * normal.xz;

            vec3 lightDir = normalize(vec3(-0.6, 0.4, 0.9));
            float diff = max(0.0, dot(normal, lightDir));
            float spec = pow(max(0.0, dot(reflect(-lightDir, normal), vec3(0.0,0.0,1.0))), 64.0);

            vec3 base = mix(vec3(0.45,0.32,0.05), vec3(1.0,0.84,0.18), diff*1.2);
            base = mix(base, vec3(1.0,0.96,0.7), spec);

            // UKIRAN BABE.INFO FULL SPHERE
            float lon = atan(normal.z, normal.x); // -PI to PI
            float lat = asin(clamp(normal.y, -1.0, 1.0));
            vec2 sphereUV = vec2(lon / (2.0*PI) + 0.5, lat / PI + 0.5);
            
            float txt = 0.0;
            for(float row=-2.5; row<=2.5; row+=1.0){
                float band = abs(sphereUV.y*5.0 - (row+2.5));
                float bandMask = 1.0 - smoothstep(0.0, 0.6, band);
                if(bandMask > 0.01){
                    float repLon = fract(sphereUV.x * (2.5 + abs(row)*0.3) + row*0.2);
                    // Simulasi tulisan tebal tipis BABE.INFO
                    float block = step(0.08, repLon) * step(repLon, 0.92);
                    block *= bandMask;
                    txt += block * 0.9;
                }
            }
            // Emboss: terang di satu sisi, gelap di sisi lain
            float embossLight = txt * 0.35;
            float embossShadow = txt * 0.28;
            base += embossLight * vec3(1.0,0.95,0.6);
            base -= embossShadow;
            base += txt * 0.15 * vec3(1.0,0.84,0.0);

            // Fresnel & edge dark
            float fresnel = pow(1.0 - max(0.0, dot(normal, vec3(0.0,0.0,1.0))), 2.5);
            base = mix(base, base*0.45, fresnel*0.6);
            
            float edge = smoothstep(globeR+0.015, globeR-0.02, r);
            col = mix(col, base, edge);

            // Rim light emas
            col += vec3(1.0,0.88,0.3) * smoothstep(0.025, 0.0, abs(r - globeR)) * 0.8;
        }
    }

    // === MAHKOTA DURI HITAM - IKUT GLOBE TAPI AGAK OBLIQUE ===
    float crownR = globeR + 0.035;
    float crownDist = abs(r - crownR);
    if(crownDist < 0.05){
        // 20 duri, rotasi ikut rotY biar terasa ngunci di globe
        float thornAng = ang*20.0 + rotY*1.5;
        float thorns = sin(thornAng)*0.5+0.5;
        thorns = pow(thorns, 5.0);
        float thornLen = thorns * 0.035 + 0.01;
        float mask = step(crownDist, thornLen);
        float thornMask = mask * smoothstep(0.05, 0.005, crownDist) * (0.4 + thorns*1.5);
        
        vec3 thornCol = vec3(0.02,0.02,0.025) + vec3(0.12)*thorns;
        col = mix(col, thornCol, thornMask*0.97);
        col += vec3(0.25)*thorns*thornMask*0.6;
    }

    // Outer glow
    float outer = smoothstep(0.18, 0.0, abs(r - (globeR+0.14))) * 0.35;
    col += vec3(1.0,0.8,0.1) * outer * glow * atmosphere * 0.3;

    col *= 1.0 - dot(p,p)*0.22; // vignette
    fragColor = vec4(col, 1.0);
}