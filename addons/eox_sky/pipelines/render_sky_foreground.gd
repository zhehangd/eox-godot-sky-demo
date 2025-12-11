extends EoxComputePipeline
class_name EoxSkyRenderSkyForeground



func render(render_data: RenderData) -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to render sky foreground")
  ck.enable_stack()

  var render_bufs: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
  if ck.catch(render_bufs): return ck.err()
  
  var view_count := render_bufs.get_view_count()
  if ck.catch(view_count > 0): return ck.err()
  var screen_color := render_bufs.get_color_layer(0)
  var screen_depth := render_bufs.get_depth_layer(0)
  var viewport_size := render_bufs.get_internal_size()

  var groups := compute_groups2(viewport_size, Vector2i(8, 8))
  var pipeline = parent.rd.compute_pipeline_create(_shader)  
  _uniform_changed = false
  var uniforms: Array[RDUniform]
  for depend in _uniforms:
    depend.add_uniform(uniforms)
  var uni_screen_color := RDUniform.new()
  uni_screen_color.binding = 5
  uni_screen_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
  uni_screen_color.add_id(screen_color)
  var uni_screen_depth := RDUniform.new()
  uni_screen_depth.binding = 6
  uni_screen_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_TEXTURE
  uni_screen_depth.add_id(screen_depth)
  uniforms.push_back(uni_screen_color)
  uniforms.push_back(uni_screen_depth)
  var rd := parent.rd
  if ck.catch(pipeline): return ck.err()
  var uniform_set := rd.uniform_set_create(uniforms, _shader, 0)
  if ck.catch(uniform_set): return ck.err()
  var cl := rd.compute_list_begin()
  rd.compute_list_bind_compute_pipeline(cl, pipeline)
  rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
  rd.compute_list_dispatch(cl, groups.x, groups.y, groups.z)
  rd.compute_list_end()
  rd.free_rid(uniform_set)
  parent.rd.free_rid(pipeline)
  return OK
