@tool
extends Node3D

func _ready() -> void:
  var sky: EoxSky = $EoxSky
  var world_env: WorldEnvironment = $WorldEnvironment
  var post_opaque_effect: EoxComputeCompositorEffect = world_env.compositor.compositor_effects[0]
  post_opaque_effect.callback.connect(sky.render_post_opaque)
  var post_trans_effect: EoxComputeCompositorEffect = world_env.compositor.compositor_effects[1]
  post_trans_effect.callback.connect(sky.render_post_transparent)
  _set_sky_material()

func _set_sky_material() -> void:
  var sky: EoxSky = $EoxSky
  var world_env: WorldEnvironment = $WorldEnvironment
  var sky_material: ShaderMaterial = world_env.environment.sky.sky_material
  var texture: Texture2DRD = sky_material.get_shader_parameter("_octmap")
  texture.texture_rd_rid = sky.get_sky_octmap_texture()

func _process(_delta: float) -> void:
  var sky: EoxSky = $EoxSky
  var sun: DirectionalLight3D = $Sun
  sun.basis = sky.get_sun_light_basis()
  sun.light_color = sky.get_sun_color()
  sun.light_energy = sky.get_sun_energy()
