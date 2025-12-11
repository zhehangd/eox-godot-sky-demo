extends EoxComputeComponent
class_name EoxComputeComputePipeline

var _shader: RID
var _uniforms: Array[EoxComputeUniform]
var _uniform_changed: bool

func _predelete() -> void:
  clear_uniforms()

func _release_shader() -> void:
  if _shader.is_valid():
    parent.rd.free_rid(_shader)
    _shader = RID()

func load_shader_spirv(shader_dir: String, shader_name: String) -> RID:
  var ck := EoxComputeReturnCheck.new()
  ck.set_return(RID())
  ck.err_msg_begin("failed to load spirv shader %s" % [name])
  var shader_path: String = shader_dir.path_join("%s.spv" % [shader_name])
  var shader_spirv_data := FileAccess.get_file_as_bytes(shader_path)
  if ck.catch(not shader_spirv_data.is_empty()): return ck.ret()
  var shader_spirv = RDShaderSPIRV.new()
  shader_spirv.set_stage_bytecode(
    RenderingDevice.SHADER_STAGE_COMPUTE, shader_spirv_data)
  var shader = parent.rd.shader_create_from_spirv(shader_spirv)
  if ck.catch(shader): return ck.ret()
  return shader

func compute_groups2(size: Vector2i, threads: Vector2i) -> Vector3i:
  var one := Vector2i(1, 1)
  var groups2 := (size - one) / threads + one
  return Vector3i(groups2.x, groups2.y, 1)

func compute_groups3(size: Vector3i, threads: Vector3i) -> Vector3i:
  var one := Vector3i(1, 1, 1)
  return (size - one) / threads + one

func set_shader(shader: RID) -> Error:
  _release_shader()
  _shader = shader
  return OK

func add_uniform(uniform: EoxComputeUniform) -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to add uniform %s to %s" % [uniform.name, name])
  if ck.catch(uniform.changed.connect(_on_uniform_changed)): return ck.err()
  _uniforms.push_back(uniform)
  return OK

func clear_uniforms() -> void:
  for uniform in _uniforms:
    uniform.changed.disconnect(_on_uniform_changed)

func execute_pipeline(groups: Vector3i) -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to execute compute pipeline %s" % [name])
  _uniform_changed = false
  var uniforms: Array[RDUniform]
  for depend in _uniforms:
    depend.add_uniform(uniforms)
  var rd := parent.rd
  var pipeline = parent.rd.compute_pipeline_create(_shader)
  if ck.catch(pipeline): return ck.err()
  var uniform_set := rd.uniform_set_create(uniforms, _shader, 0)
  if ck.catch(uniform_set): return ck.err()
  var cl := rd.compute_list_begin()
  rd.compute_list_bind_compute_pipeline(cl, pipeline)
  rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
  rd.compute_list_dispatch(cl, groups.x, groups.y, groups.z)
  rd.compute_list_end()
  rd.free_rid(uniform_set)
  rd.free_rid(pipeline)
  return OK

func is_uniform_changed() -> bool:
  return _uniform_changed

func _on_uniform_changed() -> void:
  _uniform_changed = true
