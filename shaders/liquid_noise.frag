#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;
uniform float uTime;
uniform float uIntensity;  // 0..1
uniform vec4  uColor1;
uniform vec4  uColor2;

out vec4 fragColor;

// ── Helpers ───────────────────────────────────────────────────────────────────

vec3 permute(vec3 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }

// Simplex noise 2-D
float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                       -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy  -= i1;
    i = mod(i, 289.0);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                   + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy),
                             dot(x12.zw, x12.zw)), 0.0);
    m = m * m * m * m;
    vec3 x  = 2.0 * fract(p * C.www) - 1.0;
    vec3 h  = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// ── FBM (Fractal Brownian Motion) — 4 octaves ─────────────────────────────────
float fbm(vec2 p, float t) {
    float v  = 0.0;
    float a  = 0.50;
    vec2  s  = vec2(1.0);
    mat2  r  = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5)); // slight rotate
    for (int i = 0; i < 4; i++) {
        v += a * snoise(p + t * 0.06);
        p  = r * p * 2.1;
        t *= 1.15;
        a *= 0.50;
    }
    return v;
}

// ── Curl noise — divergence-free flow field ───────────────────────────────────
// Returns a 2-D velocity vector that naturally swirls without sinks/sources.
vec2 curl(vec2 p, float t) {
    const float e = 0.0035;
    float n1 = fbm(p + vec2(0.0,  e), t);
    float n2 = fbm(p + vec2(0.0, -e), t);
    float n3 = fbm(p + vec2( e, 0.0), t);
    float n4 = fbm(p + vec2(-e, 0.0), t);
    // Curl = (∂F/∂y, -∂F/∂x)
    return vec2(n1 - n2, -(n3 - n4)) / (2.0 * e);
}

void main() {
    vec2  uv     = FlutterFragCoord().xy / uSize;
    float ratio  = uSize.x / uSize.y;
    vec2  p      = uv * vec2(ratio, 1.0);   // aspect-correct space
    float t      = uTime * 0.35;

    // ── Curl-noise warp ───────────────────────────────────────────────────────
    // Advect the UV through the curl field for a fluid, swirling motion.
    vec2 velocity = curl(p * 1.2, t);
    vec2 warped   = p + velocity * 0.18;

    // ── FBM over warped coords for the liquid "depth" field ──────────────────
    float depth = fbm(warped * 1.6, t);           // -1..1
    depth = depth * 0.5 + 0.5;                    //  0..1

    // ── Secondary high-freq ripple (surface tension) ──────────────────────────
    float ripple = snoise(warped * 5.5 + t * 0.4) * 0.12
                 + snoise(warped * 9.0 - t * 0.6) * 0.05;
    depth = clamp(depth + ripple, 0.0, 1.0);

    // ── Base liquid color blend ───────────────────────────────────────────────
    vec4 color = mix(uColor1, uColor2, depth);

    // ── Surface normal from FBM gradient (for lighting) ──────────────────────
    const float e2 = 0.006;
    float nL = fbm((warped + vec2(-e2, 0.0)) * 1.6, t);
    float nR = fbm((warped + vec2( e2, 0.0)) * 1.6, t);
    float nT = fbm((warped + vec2(0.0, -e2)) * 1.6, t);
    float nB = fbm((warped + vec2(0.0,  e2)) * 1.6, t);
    vec3 surfNormal = normalize(vec3(nL - nR, nT - nB, 0.35));

    // ── Primary specular ──────────────────────────────────────────────────────
    vec3 lightDir = normalize(vec3(-0.4, -0.6, 1.0));
    vec3 viewDir  = vec3(0.0, 0.0, 1.0);
    vec3 halfVec  = normalize(lightDir + viewDir);
    float spec    = pow(max(dot(surfNormal, halfVec), 0.0), 64.0) * 0.55
                  * uIntensity;

    // ── Iridescent sheen (thin-film interference approximation) ───────────────
    // Angle to view shifts colour phase: emulates soap-bubble / liquid-metal.
    float viewDot   = dot(surfNormal, viewDir);
    float filmAngle = 1.0 - abs(viewDot);
    // Shift hue of the iridescent overlay based on angle and noise depth
    float iridPhase = filmAngle * 2.8 + depth * 1.5 + t * 0.12;
    vec3  irid = vec3(
        0.5 + 0.5 * sin(iridPhase + 0.0),
        0.5 + 0.5 * sin(iridPhase + 2.094),  // +120°
        0.5 + 0.5 * sin(iridPhase + 4.189)   // +240°
    );
    float iridStrength = smoothstep(0.3, 0.8, filmAngle) * 0.20 * uIntensity;
    color.rgb = mix(color.rgb, irid, iridStrength);

    // ── Subsurface-scatter approximation ─────────────────────────────────────
    // Thin areas scatter more light → subtle warm glow through the liquid.
    float thickness = 1.0 - clamp(length(velocity) * 0.3, 0.0, 1.0);
    float sss       = thickness * (1.0 - depth) * 0.14 * uIntensity;
    color.rgb      += vec3(sss * 1.1, sss * 0.8, sss * 0.6);   // warm tint

    // ── Specular hotspot overlay ──────────────────────────────────────────────
    color.rgb += spec;

    // ── Edge vignette ─────────────────────────────────────────────────────────
    float dist    = distance(uv, vec2(0.5));
    float vignette = 1.0 - smoothstep(0.35, 0.72, dist) * 0.25;
    color.rgb *= vignette;

    // ── Alpha (translucent, BackdropFilter blur shows through) ────────────────
    float alpha   = uIntensity * 0.55;
    fragColor     = vec4(color.rgb, alpha);
}
