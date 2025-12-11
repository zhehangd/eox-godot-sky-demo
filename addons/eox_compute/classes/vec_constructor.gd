extends RefCounted
class_name EoxComputeVecConstructor

static func vec2fr1(v: float) -> Vector2:
  return Vector2(v, v)

static func vec2ifr1(v: float) -> Vector2i:
  return Vector2i(v, v)

static func vec3fr1(v: float) -> Vector3:
  return Vector3(v, v, v)

static func vec3ifr1(v: float) -> Vector3i:
  return Vector3i(v, v, v)

static func vec4fr1(v: float) -> Vector4:
  return Vector4(v, v, v, v)

static func vec4ifr1(v: float) -> Vector4i:
  return Vector4i(v, v, v, v)

static func pow2(v: Vector2, p: float) -> Vector2:
  for i in range(2): v[i] = pow(v[i], p)
  return v

static func pow3(v: Vector3, p: float) -> Vector3:
  for i in range(3): v[i] = pow(v[i], p)
  return v

static func pow4(v: Vector4, p: float) -> Vector4:
  for i in range(4): v[i] = pow(v[i], p)
  return v

static func rgb2vec3(color: Color) -> Vector3:
  return pow3(Vector3(color.r, color.g, color.b), 2.2)

static func rgba2vec4(color: Color) -> Vector4:
  return pow4(Vector4(color.r, color.g, color.b, color.a), 2.2)
