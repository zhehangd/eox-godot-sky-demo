extends EoxComputeBufferSource
class_name EoxSkySrcRender

var _planet_params: EoxSkyPlanetParams
var _render_params: EoxSkyRenderParams

func set_render_params(render_params: EoxSkyRenderParams) -> Error:
  var err := _replace_params(_render_params, render_params)
  if err == OK: _render_params = render_params
  return err

func set_planet_params(planet_params: EoxSkyPlanetParams) -> Error:
  var err := _replace_params(_planet_params, planet_params)
  if err == OK: _planet_params = planet_params
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

# Workaround of the issue that RenderSceneData does not provide
# previous camera transforms.
# Currently our dictionary is never cleaned it is ok unless you change
# window size too often.
class PrevData:
  var trans: Projection # prev 4x4 mat world2clip
  var position: Vector3 # prev camera position
var _prev_dict: Dictionary[RID, PrevData]

func vec4to3(v: Vector4) -> Vector3:
  return Vector3(v.x, v.y, v.z)

func vec3to4(v: Vector3, w: float) -> Vector4:
  return Vector4(v.x, v.y, v.z, w)

func trans2proj(trans: Transform3D) -> Projection:
  return Projection(
    vec3to4(trans.basis.x, 0.0),
    vec3to4(trans.basis.y, 0.0),
    vec3to4(trans.basis.z, 0.0),
    vec3to4(trans.origin, 1.0))

func proj2trans(p: Projection) -> Transform3D:
  return Transform3D(
    vec4to3(p.x), vec4to3(p.y),
    vec4to3(p.z), vec4to3(p.w))

var _clip2planet_norm_trans: Projection
var _camera_position: Vector3
var _viewport_size: Vector2i
var _time: float
var _frame_index: int
var _sun_dir: Vector3
var _prev_trans: Projection
var _prev_position: Vector3
var _enable_camera_position: bool
var _camera_position2: Vector3

func update_frame(time: float, frame_index: int):
  var render_params := _render_params
  var planet_params := _planet_params
  var sun_azimuth := render_params._sun_azimuth
  var sun_altitude := render_params._sun_altitude
  var sun_dir := Vector3(
    sin(sun_azimuth) * cos(sun_altitude),
    sin(sun_altitude),
    -cos(sun_azimuth) * cos(sun_altitude))
  _time = time
  _frame_index = frame_index
  _sun_dir = sun_dir
  var cam_position := Vector3(
    render_params._world_offset_x,
    render_params._world_altitude + planet_params._planet_radius,
    render_params._world_offset_z)
  _camera_position = cam_position
  _enable_camera_position = render_params._enable_camera_position

func update_render_data(render_data: RenderData, key: RID):
  if not _prev_dict.has(key):
    _prev_dict.set(key, PrevData.new())
    print("create new camera position cache")
  var prev := _prev_dict[key]
  var render_bufs: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
  var render_scene_data : RenderSceneDataRD = render_data.get_render_scene_data()
  var projection: Projection = render_scene_data.get_cam_projection()
  var inv_view_trans := render_scene_data.get_cam_transform()
  var inv_projection := projection.inverse()
  
  var inv_view_norm_trans := trans2proj(Transform3D(inv_view_trans.basis, Vector3()))
  var view_norm_trans := trans2proj(Transform3D(inv_view_trans.basis.inverse(), Vector3()))

  var viewport_size := render_bufs.get_internal_size()

  var cam_position := _camera_position
  if _enable_camera_position:
    cam_position += inv_view_trans.origin * 1e-3
  var clip2planet_norm_trans := \
    inv_view_norm_trans * inv_projection
  var planet2clip_norm_trans := \
    projection * view_norm_trans
  _clip2planet_norm_trans = clip2planet_norm_trans
  _camera_position2 = cam_position
  _viewport_size = viewport_size
  _prev_trans = prev.trans
  _prev_position = prev.position
  prev.trans = planet2clip_norm_trans
  prev.position = cam_position
  emit_changed()

func pack_data_size() -> int:
  return 256

func pack_data() -> PackedByteArray:
  var enc := EoxComputeBufferEncoder.new(pack_data_size())
  #var vecc := EoxComputeVecConstructor
  enc.push_mat4_projection(_clip2planet_norm_trans)
  enc.push_vec3p1(_camera_position, 1.0)
  enc.push_vec2i(_viewport_size)
  enc.push_f32(_time)
  enc.push_i32(_frame_index)
  enc.push_vec3p1(_sun_dir, 0.0)
  enc.push_f32(0.0)
  enc.push_f32(_render_params._max_luminance)
  enc.push_f32(_render_params._exposure_multiplier)
  enc.push_f32(0.0)
  enc.push_mat4_projection(_prev_trans)
  enc.push_vec3p1(_prev_position, 1.0)
  enc.push_vec4(Vector4())
  enc.push_vec4(Vector4())
  enc.push_vec4(Vector4())
  assert(enc.get_data().size() == pack_data_size())
  return enc.get_data()
