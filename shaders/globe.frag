#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY; // globe + ke kanan
uniform float windRot; // atmosfer - ke kiri
uniform float glow;

out vec4 fragColor;

mat2 rot2D(float a){ float c=cos(a), s=sin(a); return mat2(c,-s,s,c); }
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){
    vec2 i=floor(p); vec2 f=fract(p);
    float a=hash(i), b=hash(i+vec2(1.0,0.0)), c=hash(i+vec2(0.0,1.0)), d=hash(i+vec2(1.0,1.0));
    vec2 u=f*f*(3.0-2.0*f);
    return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
}

void main(){
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv*2.0-1.0;
    p.x *= iResolution.x/iResolution.y;
    vec2 center = vec2(0.0, 0.22);
    vec2 d = p-center;
    float r = length(d);
    float ang = atan(d.y,d.x);
    float globeR = 0.52;
    vec3 col = vec3(0.0);

    // MARMER HITAM URAT EMAS
    vec2 mUV = p*1.1;
    float m = noise(mUV*2.8);
    float veins = pow(sin(mUV.x*2.2+m*6.0)*0.5+0.5, 12.0);
    float veins2 = pow(sin(mUV.y*1.8+m*4.0)*0.5+0.5, 10.0);
    col = vec3(0.015) + vec3(0.85,0.65,0.15)*veins*1.2 + vec3(0.6,0.45,0.1)*veins2*0.6;

    // ANGIN ATMOSFER EMAS - BERLAWANAN ARAH
    float atmos=0.0;
    for(float i=0.0;i<4.0;i++){
        float t = windRot*(0.6+i*0.15); // windRot NEGATIF
        float rr = r*(0.85+i*0.2);
        float aa = ang - t + rr*(1.8+i*0.4);
        float swirl = sin(aa*(1.5+i*0.5)+rr*3.0)*0.5+0.5;
        float mask = smoothstep(1.7,0.45,rr)*smoothstep(0.15,0.55,rr);
        mask *= 0.7/(0.4+i*0.35);
        vec3 gold = vec3(1.0,0.82,0.08)*swirl*mask;
        gold += vec3(1.0,0.92,0.5)*pow(swirl,4.0)*mask*1.5;
        float dust = pow(hash(vec2(aa*6.0, rr*10.0+t*2.0)),3.0)*step(0.75,swirl);
        gold += vec3(1.0,0.9,0.3)*dust*mask*3.0;
        col+=gold*glow;
        atmos+=mask*swirl;
    }

    // GLOBE EMAS POLOS - TANPA TEXT (text digambar di Dart biar tajam)
    if(r < globeR+0.03){
        vec2 sUV = d/globeR;
        float z2 = 1.0-dot(sUV,sUV);
        if(z2>0.0){
            float z = sqrt(z2);
            vec3 n = vec3(sUV,z);
            n.xz = rot2D(rotY)*n.xz; // rotY POSITIF
            vec3 L = normalize(vec3(-0.6,0.4,0.9));
            float diff = max(0.0,dot(n,L));
            float spec = pow(max(0.0,dot(reflect(-L,n),vec3(0.0,0.0,1.0))),64.0);
            vec3 base = mix(vec3(0.45,0.32,0.05),vec3(1.0,0.84,0.18),diff*1.2);
            base = mix(base, vec3(1.0,0.96,0.7), spec);
            float fres = pow(1.0-max(0.0,dot(n,vec3(0.0,0.0,1.0))),2.5);
            base = mix(base, base*0.45, fres*0.6);
            float edge = smoothstep(globeR+0.015,globeR-0.02,r);
            col = mix(col, base, edge);
            col += vec3(1.0,0.88,0.3)*smoothstep(0.025,0.0,abs(r-globeR))*0.8;
        }
    }

    // MAHKOTA DURI
    float crownR = globeR+0.035;
    float cDist = abs(r-crownR);
    if(cDist<0.05){
        float thA = ang*20.0+rotY*1.5;
        float th = pow(sin(thA)*0.5+0.5,5.0);
        float mask = step(cDist, th*0.035+0.01)*smoothstep(0.05,0.005,cDist)*(0.4+th*1.5);
        vec3 thCol = vec3(0.02)+vec3(0.12)*th;
        col = mix(col, thCol, mask*0.97);
    }

    col*=1.0-dot(p,p)*0.22;
    fragColor=vec4(col,1.0);
}