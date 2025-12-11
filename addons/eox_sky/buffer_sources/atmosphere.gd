extends EoxComputeBufferSource
class_name EoxSkySrcAtmosphere

var _planet_params: EoxSkyPlanetParams
var _atmos_params: EoxSkyAtmosphereParams

func set_planet_params(planet_params: EoxSkyPlanetParams) -> Error:
  var err := _replace_params(_planet_params, planet_params)
  if err == OK: _planet_params = planet_params
  return err

func set_atmos_params(atmos_params: EoxSkyAtmosphereParams) -> Error:
  var err := _replace_params(_atmos_params, atmos_params)
  if err == OK: _atmos_params = atmos_params
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
  return 256

func pack_data() -> PackedByteArray:
  var enc := EoxComputeBufferEncoder.new(pack_data_size())
  var vecc := EoxComputeVecConstructor
  var atmos := _atmos_params
  var planet := _planet_params
  var rayleigh_color := vecc.rgb2vec3(atmos._rayleigh_color)
  var mie_color := vecc.rgb2vec3(atmos._mie_color)
  var ozone_color := vecc.rgb2vec3(atmos._ozone_color)
  var density_scale := atmos._atmosphere_density_scale
  var rayleigh_density_scale := density_scale * atmos._rayleigh_density_scale
  var mie_density_scale := density_scale * atmos._mie_rel_density_scale
  var ozone_density_scale := density_scale * atmos._ozone_rel_density_scale
  var rayleigh_scatter := rayleigh_color * (3.31e-2 * rayleigh_density_scale)
  var rayleigh_absorb := vecc.vec3fr1(0.0) # no absorption
  var rayleigh_extinct := rayleigh_scatter + rayleigh_absorb
  var mie_scatter := mie_color * (3.996e-3 * mie_density_scale)
  var mie_absorb := mie_color * (4.4e-3 * mie_density_scale)
  var mie_extinct := mie_scatter + mie_absorb
  var ozone_scatter := vecc.vec3fr1(0.0) # no scattering
  var ozone_absorb := (vecc.vec3fr1(1.0) - ozone_color) * (1e-3 * ozone_density_scale)
  var ozone_extinct := ozone_scatter + ozone_absorb
  var scattering_matrix = Basis(rayleigh_scatter, mie_scatter, vecc.vec3fr1(0.0))
  var mie_eccentricity := 1.0 - exp(-atmos._mie_eccentricity)
  var extinction_matrix = Basis(rayleigh_extinct, mie_extinct, ozone_extinct)
  var re := planet._planet_radius
  var ra := re + planet._atmosphere_thickness
  var rt := sqrt(ra * ra - re * re)
  enc.push_f32(re)
  enc.push_f32(planet._atmosphere_thickness)
  enc.push_f32(rt)
  enc.push_f32(atmos._rayleigh_altitude_decay)
  enc.push_f32(atmos._mie_altitude_decay)
  enc.push_f32(atmos._ozone_altitude)
  enc.push_f32(atmos._ozone_altitude_decay)
  enc.push_f32(mie_eccentricity)
  enc.push_vec2i(Vector2i(256, 64)) # not used
  enc.push_nbytes(24)
  enc.push_mat3(scattering_matrix)
  enc.push_mat3(extinction_matrix)
  return enc.get_data()
