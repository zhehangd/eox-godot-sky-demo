@tool
extends Resource
class_name EoxSkySkyParams

@export_range(0.0, 5.0, 0.0001) var _sky_scatter_multiplier := 1.0:
  set(value):
    _sky_scatter_multiplier = value
    emit_changed()

@export_range(0.0, 5.0, 0.0001) var _cloud_scatter_multiplier := 1.0:
  set(value):
    _cloud_scatter_multiplier = value
    emit_changed()

@export var _ground_albedo := Color(0.25, 0.25, 0.25):
  set(value):
    _ground_albedo = value
    emit_changed()

@export_range(0.0, 1.0, 0.0001)  var _ground_ambient := 0.02:
  set(value):
    _ground_ambient = value
    emit_changed()

@export_range(0.001, 100., 0.01, "or_greater", "exp") var _sun_radiance := PI:
  set(value):
    _sun_radiance = value
    emit_changed()

@export var _sun_color: Color = Color(1., 1., 1.):
  set(value):
    _sun_color = value
    emit_changed()

@export_range(0.01, 10., 0.01, "or_greater", "exp") var _sun_disk_size_scale := 1.0:
  set(value):
    _sun_disk_size_scale = value
    emit_changed()
