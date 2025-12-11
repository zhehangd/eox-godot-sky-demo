@tool
extends EoxComputeUniform
class_name EoxComputeUniBuffer

var _buffer: EoxComputeResBuffer

func _predelete() -> void:
  pass

func set_buffer(buffer: EoxComputeResBuffer) -> Error:
  if _buffer != null:
    _buffer.changed.disconnect(_on_buffer_changed)
  _buffer = null
  var err: Error
  if buffer != null:
    err = buffer.changed.connect(_on_buffer_changed)
  if OK == err: _buffer = buffer
  _on_buffer_changed()
  return err

func add_uniform(uniforms: Array[RDUniform]) -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to add buffer uniform")
  var binding := get_binding()
  if ck.catch(binding >= 0): return ck.err()
  if ck.catch(_buffer): return ck.err()
  var resource: RID = _buffer.get_buffer()
  if ck.catch(resource): return ck.err()
  var uniform := RDUniform.new()
  uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
  uniform.binding = binding
  uniform.add_id(resource)
  uniforms.push_back(uniform)
  return OK

func _on_buffer_changed() -> void:
  emit_changed()
