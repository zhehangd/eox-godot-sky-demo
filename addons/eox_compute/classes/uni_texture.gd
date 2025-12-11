@tool
extends EoxComputeUniform
class_name EoxComputeUniTexture

var _texture: EoxComputeResTexture
var _sampler: EoxComputeResSampler
var _is_image: bool = false

func set_texture(texture: EoxComputeResTexture) -> Error:
  _texture = texture
  emit_changed()
  return OK

func set_sampler(sampler: EoxComputeResSampler) -> Error:
  _sampler = sampler
  emit_changed()
  return OK

func set_is_image(is_image) -> void:
  _is_image = is_image
  emit_changed()

func _predelete() -> void:
  pass

# compute atmos transmit lut uses it to get lut back to cpu.
func get_texture() -> EoxComputeResTexture:
  return _texture

func add_uniform(uniforms: Array[RDUniform]) -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to add texture uniform")
  if ck.catch(_texture): return ck.err()
  var uniform := RDUniform.new()
  if _is_image:
    var texture := _texture.get_texture()
    if ck.catch(texture): return ck.err()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    uniform.add_id(texture)
  elif _sampler != null:
    var texture := _texture.get_texture()
    var sampler := _sampler.get_sampler()
    if ck.catch(texture): return ck.err()
    if ck.catch(sampler): return ck.err()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
    uniform.add_id(sampler)
    uniform.add_id(texture)
  else:
    var texture := _texture.get_texture()
    if ck.catch(texture): return ck.err()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_TEXTURE
    uniform.add_id(texture)
  uniform.binding = get_binding()
  uniforms.push_back(uniform)
  return OK
