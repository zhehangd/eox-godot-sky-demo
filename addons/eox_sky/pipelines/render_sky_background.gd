extends EoxComputePipeline
class_name EoxSkyRenderSkyBackground

var _mesh: EoxComputeResMesh

func _init(parent: EoxComputeParent, name: String) -> void:
  super._init(parent, name)
  _mesh = EoxComputeResMesh.new(parent, "res_render_sky_background_mesh")
  var rd := parent.rd
  const num_vertices := 3
  const num_indices := 3
  var vertex_positions: PackedFloat32Array = [-1., 1., 0., 1., -1., -2., 0., 1., 2., 1., 0., 1.,]
  for i in range(num_vertices):
    for k in range(3):
      vertex_positions[i * 4 + k] *= 16.0
  const indices: PackedInt32Array = [0, 1, 2]
  var vertex_attribute0 = RDVertexAttribute.new()
  vertex_attribute0.location = 0
  vertex_attribute0.stride = 4 * 4 # float4
  vertex_attribute0.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
  var vertex_format := rd.vertex_format_create([vertex_attribute0])
  var position_data := vertex_positions.to_byte_array()
  var position_buffer := rd.vertex_buffer_create(
      position_data.size(), position_data, true)
  var vertex_array := rd.vertex_array_create(
      num_vertices, vertex_format, [position_buffer])
  var index_data := indices.to_byte_array()
  var index_buffer := rd.index_buffer_create(
    num_indices, RenderingDevice.INDEX_BUFFER_FORMAT_UINT32,
    index_data)
  var index_array := rd.index_array_create(index_buffer, 0, indices.size())
  var mesh := _mesh
  mesh.buffers.push_back(position_buffer)
  mesh.buffers.push_back(index_buffer)
  mesh.vertex_array = vertex_array
  mesh.index_array = index_array
  mesh.vertex_format = vertex_format

func _predelete() -> void:
  _mesh._predelete()
  super._predelete()

func render(render_data: RenderData) -> Error:
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to render sky background")
  ck.enable_stack()

  var rd := parent.rd  
  var render_bufs: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
  var render_scene_data : RenderSceneDataRD = render_data.get_render_scene_data()
  var view_count := render_bufs.get_view_count()
  var render_buf_ok := render_bufs != null and render_scene_data != null and view_count > 0
  if ck.catch(render_buf_ok): return ck.err()
  var use_msaa = render_bufs.get_msaa_3d() != RenderingServer.ViewportMSAA.VIEWPORT_MSAA_DISABLED
  var tex_color := render_bufs.get_color_layer(0, use_msaa)
  var tex_depth := render_bufs.get_depth_layer(0, use_msaa)
  if ck.catch(tex_color.is_valid() and tex_depth.is_valid()): return ck.err()
  var frame_buffer := FramebufferCacheRD.get_cache_multipass([tex_color, tex_depth], [], 1)
  if ck.catch(frame_buffer): return ck.err()
  
  var frame_buffer_format := rd.framebuffer_get_format(frame_buffer)

  var rasterization_state = RDPipelineRasterizationState.new()
  rasterization_state.cull_mode = RenderingDevice.POLYGON_CULL_DISABLED

  var multisample_state = RDPipelineMultisampleState.new()
  assert(frame_buffer_format >= 0)
  multisample_state.sample_count = rd.framebuffer_format_get_texture_samples(frame_buffer_format)

  var depth_stencil_state = RDPipelineDepthStencilState.new()
  depth_stencil_state.enable_depth_test = true
  depth_stencil_state.enable_depth_write = true
  depth_stencil_state.enable_stencil = false
  depth_stencil_state.depth_compare_operator = RenderingDevice.COMPARE_OP_GREATER_OR_EQUAL

  var color_blend_state = RDPipelineColorBlendState.new()
  var color_blend_attachment0 = RDPipelineColorBlendStateAttachment.new()
  color_blend_attachment0.enable_blend = false
  color_blend_state.attachments = [color_blend_attachment0]
  
  var pipeline := rd.render_pipeline_create(
    _shader,  frame_buffer_format,
    _mesh.vertex_format, RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
    rasterization_state, multisample_state,
    depth_stencil_state, color_blend_state)
  if ck.catch(pipeline): return ck.err()

  execute_simple_graphics_pipeline(pipeline, frame_buffer, _mesh)
  parent.rd.free_rid(pipeline)
  return OK
