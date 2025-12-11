@tool
extends Resource
class_name EoxSkyRenderParams

@export var _exposure_multiplier := 1.0:
  set(value):
    _exposure_multiplier = value
    emit_changed()

@export_range(0.0, 200.0, 0.001) var _world_altitude := 0.1:
  set(value):
    _world_altitude = value
    emit_changed()
 
@export var _world_offset_x := 0.0:
  set(value):
    _world_offset_x = value
    emit_changed()

@export var _world_offset_z := 0.0:
  set(value):
    _world_offset_z = value
    emit_changed()

@export var _enable_camera_position := true:
  set(value):
    _enable_camera_position = value
    emit_changed()

@export_range(0.0, 10.0, 1e-4) var _max_luminance := 10.0:
  set(value):
    _max_luminance = value
    emit_changed()

@export_range(-90, 90, 0.001, "radians_as_degrees") var _sun_altitude: float = 0.0:
  set(value):
    _sun_altitude = value
    emit_changed()

@export_range(-180, 180, 0.01, "radians_as_degrees") var _sun_azimuth: float = 0.0:
  set(value):
    _sun_azimuth = value
    emit_changed()
