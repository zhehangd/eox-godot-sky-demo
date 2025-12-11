extends EoxComputeBufferSource
class_name EoxSkySrcSkyParams

var _sky_params: EoxSkySkyParams

func set_sky_params(sky_params: EoxSkySkyParams) -> Error:
  var err := _replace_params(_sky_params, sky_params)
  if err == OK: _sky_params = sky_params
  return err

func _predelete() -> void:
  pass

# Disconnect from the old resource and connect to the new resource.
# This does not really "set" the property because we can't reference
# a property in GDScript.
func _replace_params(dst: Resource, src: Resource) -> Error:
  var err: Error = Error.OK
  if dst != null:
    dst.changed.disconnect(_on_params_changed)
    dst = null
  if src != null:
    err = src.changed.connect(_on_params_changed)
  return err

func _on_params_changed() -> void:
  emit_changed()

func pack_data_size() -> int:
  return 64

func pack_data() -> PackedByteArray:
  var enc := EoxComputeBufferEncoder.new(pack_data_size())
  var vecc := EoxComputeVecConstructor
  var sky := _sky_params
  var sun_radiance := vecc.rgb2vec3(sky._sun_color) * sky._sun_radiance;
  enc.push_vec3p1(sun_radiance, sky._sun_disk_size_scale)
  enc.push_vec3p1(vecc.rgb2vec3(sky._ground_albedo), sky._ground_ambient)
  enc.push_f32(sky._sky_scatter_multiplier)
  enc.push_f32(sky._cloud_scatter_multiplier)
  return enc.get_data()
