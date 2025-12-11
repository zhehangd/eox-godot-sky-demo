extends EoxComputePipeline
class_name EoxSkyComputeAtmosTransmitLut

const kTextureSize := Vector2i(256, 64)

var _uni_atmos_transmit_lut: EoxComputeUniTexture

var _image: Image

func create(
    shader_dir: String, shader_name: String,
    uni_atmos_params: EoxComputeUniBuffer,
    uni_atmos_transmit_lut: EoxComputeUniTexture) -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to create compute_atmos_transmit_lut")
  var shader := load_compute_shader_spirv(
    shader_dir, "compute_atmos_transmit_lut")
  if ck.catch(shader): return ck.err()
  if ck.catch(set_shader(shader)): return ck.err()
  if ck.catch(add_uniform(uni_atmos_params)): return ck.err()
  if ck.catch(add_uniform(uni_atmos_transmit_lut)): return ck.err()
  _uni_atmos_transmit_lut = uni_atmos_transmit_lut
  return OK

func compute_on_changed() -> void:
  if not is_uniform_changed(): return
  print("compute atmos transmit lut")
  var groups := compute_groups2(kTextureSize, Vector2i(8, 8))
  var pipeline = parent.rd.compute_pipeline_create(_shader)
  execute_simple_compute_pipeline(pipeline, groups)
  parent.rd.free_rid(pipeline)
  var res_texture := _uni_atmos_transmit_lut.get_texture()
  var texture := res_texture.get_texture()
  parent.rd.texture_get_data_async(texture, 0, _on_texture_ready)

# Returns linear color
func sample_transmit(re: float, ra: float, cos_zenith: float, altitude: float) -> Color:
  if _image == null: return Color.WHITE
  var rt := sqrt(ra * ra - re * re);
  var r := re + altitude;
  var c := cos_zenith;
  var d := -r * c + sqrt(ra * ra + (c * c - 1) * r * r);
  var rh := sqrt(r * r - re * re);
  var dmin := ra - r;
  var dmax := rh + rt;
  var u := (d - dmin) / (dmax - dmin);
  var v := rh / rt;
  # TODO: use accurate interpolation
  var pos := Vector2i(Vector2(kTextureSize) * Vector2(u, v))
  pos.x = clamp(pos.x, 0, kTextureSize.x - 1)
  pos.y = clamp(pos.y, 0, kTextureSize.y - 1)
  var color := _image.get_pixelv(pos)
  color.a = 1.0
  return color

func _on_texture_ready(data: PackedByteArray) -> void:
  var image := Image.create_from_data(kTextureSize.x, kTextureSize.y, false, Image.FORMAT_RGBA8, data)
  _image = image
