extends RefCounted
class_name EoxComputeBufferEncoder

var _data: PackedByteArray
var _i: int = 0

func _init(size: int):
  _data.resize(size)

func push_f32(val: float):
  _data.encode_float(_i, val)
  _i += 4

func push_i32(val: int):
  _data.encode_s32(_i, val)
  _i += 4

func push_vec4(vec: Vector4):
  for i in range(4):
    _data.encode_float(_i, vec[i])
    _i += 4

func push_vec3p1(vec: Vector3, val: float):
  for i in range(3):
    _data.encode_float(_i, vec[i])
    _i += 4
  _data.encode_float(_i, val)
  _i += 4

func push_vec2i(vec: Vector2i) -> void:
  for i in range(2):
    _data.encode_s32(_i, vec[i])
    _i += 4

func push_mat3(basis: Basis) -> void:
  push_vec3p1(basis.x, 0.0)
  push_vec3p1(basis.y, 0.0)
  push_vec3p1(basis.z, 0.0)

func push_mat4x3(basis: Basis, offset: Vector3) -> void:
  push_vec3p1(basis.x, 0.0)
  push_vec3p1(basis.y, 0.0)
  push_vec3p1(basis.z, 0.0)
  push_vec3p1(offset, 1.0)

func push_mat4_projection(proj: Projection) -> void:
  for i in range(4): push_vec4(proj[i])

func push_mat4_transform(mat: Transform3D) -> void:
  for i in range(3): push_vec3p1(mat.basis[i], 0.0)
  push_vec3p1(mat.origin, 1.0)

func push_bytes(bytes: PackedByteArray) -> void:
  var n := bytes.size()
  for i in range(n): _data[_i] = bytes[i]
  _i += n

func push_nbytes(n: int) -> void:
  _i += n

func get_data() -> PackedByteArray:
  return _data
