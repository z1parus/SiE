#include <flutter/runtime_effect.glsl>

uniform float iTime;       // 0
uniform float iBreath;     // 1  (0..1 breathing phase)
uniform vec2  iResolution; // 2,3
uniform float isDark;      // 4  (1.0 = dark theme, 0.0 = light)

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(127.1, 311.7));
  p += dot(p, p + 19.19);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i),                    hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)),   hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 6; i++) {
    v += a * noise(p);
    p  *= 2.1;
    a  *= 0.48;
  }
  return v;
}

void main() {
  vec2 fc  = FlutterFragCoord().xy;
  vec2 uv  = fc / iResolution;
  vec2 c   = uv - 0.5;
  float r  = length(c);

  // Clip to circle
  if (r > 0.5) {
    fragColor = vec4(0.0);
    return;
  }

  // Spherical surface projection for natural cloud wrapping
  float nx = c.x / 0.5;
  float ny = c.y / 0.5;
  float nz = sqrt(max(0.0, 1.0 - nx * nx - ny * ny));

  float speed = 0.03 + iBreath * 0.015;
  vec2 sUV = vec2(
    atan(nx, nz) * 0.5 + iTime * speed,
    asin(clamp(ny, -1.0, 1.0)) * 0.8
  );

  // Domain-warped FBM for organic cloud shapes
  vec2 q = vec2(
    fbm(sUV * 1.8 + vec2(0.0,  iTime * 0.025)),
    fbm(sUV * 1.8 + vec2(5.2,  iTime * 0.020))
  );
  float clouds = fbm(sUV * 2.2 + 3.5 * q);

  // Edge vignette — darker at sphere perimeter for 3D depth
  float vignette = pow(1.0 - smoothstep(0.28, 0.50, r), 0.55);

  vec3 col;
  if (isDark > 0.5) {
    // Dark theme: deep navy base, blue-grey cloud wisps
    vec3 base   = vec3(0.110, 0.126, 0.208);  // #1C2035
    vec3 cloud  = vec3(0.212, 0.282, 0.416);  // #36486A
    vec3 bright = vec3(0.290, 0.369, 0.502);  // #4A5E80
    col  = mix(base, cloud, clouds);
    col  = mix(col, bright, clouds * clouds * 0.55);
  } else {
    // Light theme: pearl white base, soft grey cloud wisps
    vec3 base   = vec3(0.945, 0.945, 0.961);  // #F1F1F5
    vec3 cloud  = vec3(0.753, 0.761, 0.800);  // #C0C2CC
    vec3 bright = vec3(0.996, 0.996, 1.000);  // #FEFEFF
    col  = mix(base, cloud, clouds * 0.75);
    col  = mix(col, bright, (1.0 - clouds) * 0.30);
  }

  col *= vignette;

  fragColor = vec4(col, 1.0);
}
