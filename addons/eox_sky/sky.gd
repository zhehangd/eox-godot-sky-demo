@tool
extends EoxComputeParent
class_name EoxSky

@export var _render_params: EoxSkyRenderParams:
  set(render_params):
    var ck := EoxComputeReturnCheck.new()
    ck.err_msg_begin("failed to set render params")
    _render_params = null
    if ck.catch(_src_render_params.set_render_params(render_params)): return
    _render_params = render_params

@export var _planet_params: EoxSkyPlanetParams:
  set(planet_params):
    var ck := EoxComputeReturnCheck.new()
    ck.err_msg_begin("failed to set planet params")
    _planet_params = null
    if ck.catch(_src_atmos_params.set_planet_params(planet_params)): return
    if ck.catch(_src_render_params.set_planet_params(planet_params)): return
    _planet_params = planet_params

@export var _sky_params: EoxSkySkyParams:
  set(sky_params):
    var ck := EoxComputeReturnCheck.new()
    ck.err_msg_begin("failed to set sky params")
    _sky_params = null
    if ck.catch(_src_sky_params.set_sky_params(sky_params)): return
    _sky_params = sky_params

@export var _atmos_params: EoxSkyAtmosphereParams:
  get():
    return _atmos_params
  set(atmos_params):
    var ck := EoxComputeReturnCheck.new()
    ck.err_msg_begin("failed to set atmos params")
    _atmos_params = null
    if ck.catch(_src_atmos_params.set_atmos_params(atmos_params)): return
    _atmos_params = atmos_params

var _script_dir := (get_script() as GDScript).resource_path.get_base_dir()
var _shader_dir := _script_dir.path_join("shaders")

var _src_atmos_params := EoxSkySrcAtmosphere.new(self, "src_atmos")
var _src_render_params := EoxSkySrcRender.new(self, "src_render")
var _src_sky_params := EoxSkySrcSkyParams.new(self, "src_sky_params")
var _res_atmos_params := EoxComputeResBuffer.new(self, "res_atmos_params")
var _res_render_params := EoxComputeResBuffer.new(self, "res_render_params")
var _res_sky_params := EoxComputeResBuffer.new(self, "res_sky_params")
var _res_atmos_transmit_lut := EoxComputeResTexture.new(self, "res_atmos_transmit_lut")
var _res_atmos_lut_sampler := EoxComputeResSampler.new(self, "res_atmos_lut_sampler")
var _res_sky_octmap_texture := EoxComputeResTexture.new(self, "res_sky_octmap_texture")
var _uni_atmos_params := EoxComputeUniBuffer.new(self, "uni_atmos_params")
var _uni_sky_params := EoxComputeUniBuffer.new(self, "uni_sky_params")
var _uni_render_params := EoxComputeUniBuffer.new(self, "uni_render_params")
var _uni_atmos_transmit_lut_w := EoxComputeUniTexture.new(self, "uni_atmos_transmit_lut_w")
var _uni_atmos_transmit_lut_r := EoxComputeUniTexture.new(self, "uni_atmos_transmit_lut_r")
var _uni_sky_octmap_texture := EoxComputeUniTexture.new(self, "uni_sky_octmap_texture")
var _compute_atmos_transmit_lut := EoxSkyComputeAtmosTransmitLut.new(self, "compute_atmos_transmit_lut")
var _render_sky_background := EoxSkyRenderSkyBackground.new(self, "render_sky_background")
var _render_sky_foreground := EoxSkyRenderSkyForeground.new(self, "render_sky_foreground")
var _render_sky_octmap := EoxSkyRenderSkyOctmap.new(self, "render_sky_octmap")

var _time := 0.0
var _frame_index := 0

func _is_params_ready() -> bool:
  return \
    _sky_params != null and _atmos_params != null and \
    _render_params != null and _planet_params != null

func get_atmos_transmit_lut_texture() -> RID:
  return _res_atmos_transmit_lut.get_texture()

func get_sky_octmap_texture() -> RID:
  return _res_sky_octmap_texture.get_texture()

# Based on the geological position of the world origin.
func get_sun_light_basis() -> Basis:
  var basis := Basis()
  if not _is_params_ready(): return basis
  basis = basis.rotated(Vector3(1.0, 0.0, 0.0), -_render_params._sun_altitude)
  basis = basis.rotated(Vector3(0.0, 1.0, 0.0), PI - _render_params._sun_azimuth)
  return basis

# Calculate sun sRGB color that can be assigned to directional light's light_color.
# Based on the geological position of the world origin.
func get_sun_color() -> Color:
  if not _is_params_ready(): return Color.WHITE
  var re := _planet_params._planet_radius
  var ra := _planet_params._atmosphere_thickness + re
  var altitude := _render_params._world_altitude
  var cos_zenith := cos(PI * 0.5 - _render_params._sun_altitude)
  var transmit := _compute_atmos_transmit_lut.sample_transmit(re, ra, cos_zenith, altitude)
  var sun_color := _sky_params._sun_color.srgb_to_linear()
  return (sun_color * transmit).linear_to_srgb()

func get_sun_energy() -> float:
  if not _is_params_ready(): return 1.0
  return _sky_params._sun_radiance / PI

func _ready() -> void:
  var err := _create_all()
  if err != OK: set_fatal("sky halt")

func _process(delta: float) -> void:
  if fatal: return
  if not _is_params_ready(): return
  _res_atmos_params.update_on_changed()
  _res_sky_params.update_on_changed()
  _compute_atmos_transmit_lut.compute_on_changed()
  _src_render_params.update_frame(_time, _frame_index)
  _frame_index += 1
  _time += delta

func render_post_opaque(render_data: RenderData) -> void:
  if fatal: return
  if not _is_params_ready(): return
  # key should be a persistent texture rid.
  # as we don't need it right now, we give an empty rid.
  _src_render_params.update_render_data(render_data, RID())
  _res_render_params.update_on_changed()
  # Godot creates randiance map even before pre-opaque, so we are one frame behind.
  # There is nothing we can do.
  # Due to the same reason, if there are multiple viewports to render, it is
  # likely to have problems because we are always rendering octmap for the next
  # viewport.
  _render_sky_octmap.compute()
  # We render background sky here so we have correct MSAA on the borders between
  # scene and background.
  _render_sky_background.render(render_data)

func render_post_transparent(render_data: RenderData) -> void:
  if fatal: return
  if not _is_params_ready(): return
  # We assume that render_params has been updated in render_post_opaque.
  # This only renders aerial perspective in front of the scene.
  _render_sky_foreground.render(render_data)

func _create_all() -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to initialize sky")
  if ck.catch(_create_params()): return ck.err()
  if ck.catch(_create_atmos_transmit_lut()): return ck.err()
  if ck.catch(_create_sky_octmap_texture()): return ck.err()
  if ck.catch(_create_compute_atmos_transmit_lut()): return ck.err()
  if ck.catch(_create_render_sky_background()): return ck.err()
  if ck.catch(_create_render_sky_foreground()): return ck.err()
  if ck.catch(_create_render_sky_octmap()): return ck.err()
  return OK

func _create_params() -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to create parameter sources")
  if ck.catch(_src_atmos_params.set_atmos_params(_atmos_params)): return ck.err()
  if ck.catch(_src_atmos_params.set_planet_params(_planet_params)): return ck.err()
  if ck.catch(_src_sky_params.set_sky_params(_sky_params)): return ck.err()
  if ck.catch(_src_render_params.set_render_params(_render_params)): return ck.err()
  if ck.catch(_src_render_params.set_planet_params(_planet_params)): return ck.err()
  if ck.catch(_res_atmos_params.set_source(_src_atmos_params)): return ck.err()
  if ck.catch(_res_render_params.set_source(_src_render_params)): return ck.err()
  if ck.catch(_res_sky_params.set_source(_src_sky_params)): return ck.err()
  if ck.catch(_uni_atmos_params.set_buffer(_res_atmos_params)): return ck.err()
  if ck.catch(_uni_render_params.set_buffer(_res_render_params)): return ck.err()
  if ck.catch(_uni_sky_params.set_buffer(_res_sky_params)): return ck.err()
  _uni_atmos_params.set_binding(0)
  _uni_render_params.set_binding(3)
  _uni_sky_params.set_binding(4)
  return OK

func _create_atmos_transmit_lut() -> Error:
  var ck := EoxComputeReturnCheck.new()
  if true:
    ck.err_msg_begin("failed to create atmos_lut_sampler sampler")
    var state := RDSamplerState.new()
    var sampler := rd.sampler_create(state)
    if ck.catch(sampler): return ck.err()
    if ck.catch(_res_atmos_lut_sampler.set_sampler(sampler)): return ck.err()
    ck.err_msg_end()
  if true:
    ck.err_msg_begin("failed to create atmos_transmit_lut texture")
    var tex_size := _compute_atmos_transmit_lut.kTextureSize
    var format: RDTextureFormat = RDTextureFormat.new()
    format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
    format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    format.width = tex_size.x
    format.height = tex_size.y
    format.usage_bits = (
      RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
      RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
      RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
      RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
    var texture := rd.texture_create(format, RDTextureView.new(), [])
    if ck.catch(texture): return ck.err()
    if ck.catch(_res_atmos_transmit_lut.set_texture(texture, true)): return ck.err()
    ck.err_msg_end()
  if true:
    ck.err_msg_begin("failed to create uni_atmos_transmit_lut")
    if ck.catch(_uni_atmos_transmit_lut_w.set_texture(_res_atmos_transmit_lut)): return ck.err()
    _uni_atmos_transmit_lut_w.set_is_image(true)
    _uni_atmos_transmit_lut_w.set_binding(1)
    if ck.catch(_uni_atmos_transmit_lut_r.set_texture(_res_atmos_transmit_lut)): return ck.err()
    if ck.catch(_uni_atmos_transmit_lut_r.set_sampler(_res_atmos_lut_sampler)): return ck.err()
    _uni_atmos_transmit_lut_r.set_binding(2)
    ck.err_msg_end()
  return OK

func _create_compute_atmos_transmit_lut() -> Error:
  return _compute_atmos_transmit_lut.create(
    _shader_dir, "compute_atmos_transmit_lut", _uni_atmos_params,
    _uni_atmos_transmit_lut_w)

func _create_sky_octmap_texture() -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to create sky_octmap_texture")
  if true:
    var format: RDTextureFormat = RDTextureFormat.new()
    format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
    format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    format.width = 256
    format.height = 256
    format.usage_bits = (
      RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
      RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
      RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
      RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
    var texture := rd.texture_create(format, RDTextureView.new(), [])
    if ck.catch(texture): return ck.err()
    if ck.catch(_res_sky_octmap_texture.set_texture(texture, true)): return ck.err()
  if true:
    if ck.catch(_uni_sky_octmap_texture.set_texture(_res_sky_octmap_texture)): return ck.err()
    _uni_sky_octmap_texture.set_is_image(true)
    _uni_sky_octmap_texture.set_binding(7)
  return OK

func _create_render_sky_background() -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to create render_sky_background")
  var shader := _render_sky_background.load_graphics_shader_spirv(
    _shader_dir, "render_sky_background")
  if ck.catch(shader): return ck.err()
  if ck.catch(_render_sky_background.set_shader(shader)): return ck.err()
  var graphics := _render_sky_background
  if ck.catch(graphics.add_uniform(_uni_atmos_params)): return ck.err()
  if ck.catch(graphics.add_uniform(_uni_sky_params)): return ck.err()
  if ck.catch(graphics.add_uniform(_uni_render_params)): return ck.err()
  if ck.catch(graphics.add_uniform(_uni_atmos_transmit_lut_r)): return ck.err()
  return OK

func _create_render_sky_foreground() -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to create render_sky_foreground")
  var shader := _render_sky_foreground.load_compute_shader_spirv(
    _shader_dir, "render_sky_foreground")
  if ck.catch(shader): return ck.err()
  if ck.catch(_render_sky_foreground.set_shader(shader)): return ck.err()
  var compute := _render_sky_foreground
  if ck.catch(compute.add_uniform(_uni_atmos_params)): return ck.err()
  if ck.catch(compute.add_uniform(_uni_sky_params)): return ck.err()
  if ck.catch(compute.add_uniform(_uni_render_params)): return ck.err()
  if ck.catch(compute.add_uniform(_uni_atmos_transmit_lut_r)): return ck.err()
  return OK

func _create_render_sky_octmap() -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to create render_sky_octmap")
  var shader := _render_sky_octmap.load_compute_shader_spirv(
    _shader_dir, "render_sky_octmap")
  if ck.catch(shader): return ck.err()
  if ck.catch(_render_sky_octmap.set_shader(shader)): return ck.err()
  var compute := _render_sky_octmap
  if ck.catch(compute.add_uniform(_uni_atmos_params)): return ck.err()
  if ck.catch(compute.add_uniform(_uni_sky_params)): return ck.err()
  if ck.catch(compute.add_uniform(_uni_render_params)): return ck.err()
  if ck.catch(compute.add_uniform(_uni_atmos_transmit_lut_r)): return ck.err()
  if ck.catch(compute.add_uniform(_uni_sky_octmap_texture)): return ck.err()
  return OK
