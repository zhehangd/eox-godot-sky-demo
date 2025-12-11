shader_type sky;

uniform float _value: hint_range(0.0, 1.0, 0.001) = 1.0;
uniform sampler2D _octmap: hint_default_black, filter_linear;

vec2 octmap_wrap(vec2 v) {
  vec2 s = step(vec2(0.0), v) * 2. - 1.; // copysign
  return (1.0 - abs(v.yx)) * s;
}

// Normal -> UV
vec2 octmap_encode(vec3 n) {
  float s = dot(abs(n), vec3(1.));
  float h = n.y;
  vec2 uv = n.xz / s;
  if (h < 0.0) { uv = octmap_wrap(uv); }
  uv = uv * 0.5 + 0.5;
  return uv;
}

// UV -> Normal
vec3 Decode(vec2 uv) {
  uv = uv * 2.0 - 1.0;
  float h = 1.0 - dot(abs(uv), vec2(1.0));
  if (h < 0.0) { uv = octmap_wrap(uv); }
  return normalize(vec3(uv.x, h, uv.y));
}


void sky() {
  float _time = TIME; // hint the engine that we are time-dependent.
  vec2 uv = octmap_encode(EYEDIR);
  vec3 color = texture(_octmap, uv).rgb * _value;
  COLOR = color;
}
