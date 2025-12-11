module octahedral_mapping;

namespace octmap {

func Wrap(float2 v) -> float2 {
  float2 s = step(float2(0.0), v) * 2. - 1.; // copysign
  return (1.0 - abs(v.yx)) * s;
}

// Normal -> UV
public func Encode(float3 n) -> float2 {
  float s = dot(abs(n), float3(1.));
  float h = n.y;
  float2 uv = n.xz / s;
  if (h < 0.0) { uv = Wrap(uv); }
  uv = uv * 0.5 + 0.5;
  return uv;
}

// UV -> Normal
public func Decode(float2 uv) -> float3 {
  uv = uv * 2.0 - 1.0;
  float h = 1.0 - dot(abs(uv), float2(1.0));
  if (h < 0.0) { uv = Wrap(uv); }
  return normalize(float3(uv.x, h, uv.y));
}

}
