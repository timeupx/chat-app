#version 460 core
#include <flutter/runtime_effect.glsl>

// Bigo-like real-time beauty: soft skin (blur + edge keep) + whitening.
// Uniforms must be declared before samplers; set in the same order from Dart.
uniform float uIntensity; // 0.0 … 1.0
uniform vec2 uSize;
uniform sampler2D uTexture;

out vec4 fragColor;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// Cheap RGB skin likelihood — strong enough for faces under typical lighting.
// Thresholds widened vs the original pass so more of the face/neck/ears is
// caught (was under-triggering on warmer/darker skin tones and shadowed
// cheeks), which was the main reason the effect looked "too subtle".
float skinMask(vec3 c) {
  float r = c.r;
  float g = c.g;
  float b = c.b;
  float rg = r - g;
  float rb = r - b;
  float score = smoothstep(0.006, 0.07, rg)
              * smoothstep(0.02, 0.14, rb)
              * smoothstep(0.08, 0.26, r)
              * (1.0 - smoothstep(0.55, 0.92, abs(r - g)));
  return clamp(score, 0.0, 1.0);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 orig = texture(uTexture, uv);
  float intensity = clamp(uIntensity, 0.0, 1.0);

  if (intensity < 0.001) {
    fragColor = orig;
    return;
  }

  // Wider kernel at higher intensity (still ≤9 taps for 30fps) — bumped up
  // from 1.0–2.2px to 1.4–3.4px so "Smooth"/"Soft Glow" presets actually
  // read as smoothed skin instead of a barely-visible softening.
  float spread = mix(1.4, 3.4, intensity);
  vec2 px = (spread / uSize);

  vec3 blur = orig.rgb * 0.36;
  blur += texture(uTexture, uv + vec2(px.x, 0.0)).rgb * 0.12;
  blur += texture(uTexture, uv + vec2(-px.x, 0.0)).rgb * 0.12;
  blur += texture(uTexture, uv + vec2(0.0, px.y)).rgb * 0.12;
  blur += texture(uTexture, uv + vec2(0.0, -px.y)).rgb * 0.12;
  blur += texture(uTexture, uv + vec2(px.x, px.y)).rgb * 0.04;
  blur += texture(uTexture, uv + vec2(-px.x, px.y)).rgb * 0.04;
  blur += texture(uTexture, uv + vec2(px.x, -px.y)).rgb * 0.04;
  blur += texture(uTexture, uv + vec2(-px.x, -px.y)).rgb * 0.04;

  // Keep eyes / hair / jaw edges sharper than cheeks. Threshold raised a
  // touch so more mid-strength edges (nose shading, cheek contours) still
  // get some smoothing instead of being fully protected.
  float edge = abs(luma(orig.rgb) - luma(blur));
  float edgeKeep = 1.0 - smoothstep(0.022, 0.15, edge);

  float skin = skinMask(orig.rgb);
  // 0.78 → 0.94: skin blends almost fully into the smoothed sample at max
  // intensity, matching the strength of Bigo's default "Smooth" look.
  float smoothAmt = intensity * 0.94 * skin * edgeKeep;
  vec3 smoothed = mix(orig.rgb, blur, smoothAmt);

  // Whitening: lift brightness, soft contrast, warm cast on skin. Toned
  // back down from an earlier pass (whiten 0.34, gray-mix 0.12) that made
  // "Smooth" read as washed-out/too-white — smoothing strength (above) is
  // unaffected, only the brightening/desaturation-toward-gray amount.
  float whiten = intensity * 0.16 * skin;
  vec3 whitened = smoothed + vec3(whiten * 1.0, whiten * 0.88, whiten * 0.80);
  whitened = mix(whitened, vec3(0.56), intensity * 0.045 * skin);
  whitened.r += intensity * 0.018 * skin;
  whitened.g += intensity * 0.009 * skin;

  // Small global glow (very subtle, not skin-masked) — Bigo/Bigo-like
  // beauty cams sit slightly "brighter" overall, not just on skin.
  whitened += vec3(intensity * 0.012);

  fragColor = vec4(clamp(whitened, 0.0, 1.0), orig.a);
}
