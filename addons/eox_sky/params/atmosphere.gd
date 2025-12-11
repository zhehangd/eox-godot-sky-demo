@tool
extends Resource
class_name EoxSkyAtmosphereParams

@export_range(0.01, 100., 0.01, "or_greater", "exp") var _atmosphere_density_scale: float = 1.0:
    set(p_new_scale):
        _atmosphere_density_scale = p_new_scale
        emit_changed()

@export var _rayleigh_altitude_decay = 8.0:
    set(value):
        _rayleigh_altitude_decay = value
        emit_changed()

@export_range(0.0, 10.0, 0.001) var _rayleigh_density_scale: float = 1.0:
    set(value):
        _rayleigh_density_scale = value
        emit_changed()

@export var _rayleigh_color: Color = Color(0.45315824, 0.66650509, 1.):
    set(p_new_color):
        _rayleigh_color = p_new_color
        emit_changed()

@export var _mie_altitude_decay = 1.2:
    set(value):
        _mie_altitude_decay = value
        emit_changed()

@export_range(0.0, 15.0, 0.01) var _mie_eccentricity: float = 3.0:
    set(p_new_mie_eccentricity):
        _mie_eccentricity = p_new_mie_eccentricity
        emit_changed()

@export_range(0.0, 5.0, 0.01) var _mie_rel_density_scale: float = 1.0:
    set(p_new_scale):
        _mie_rel_density_scale = p_new_scale
        emit_changed()

@export var _mie_color: Color = Color(1., 1., 1.):
    set(p_new_color):
        _mie_color = p_new_color
        emit_changed()

@export var _ozone_altitude = 25.:
    set(value):
        _ozone_altitude = value
        emit_changed()

@export var _ozone_altitude_decay = 15.:
    set(value):
        _ozone_altitude_decay = value
        emit_changed()

@export_range(0.0, 5.0, 0.01) var _ozone_rel_density_scale: float = 1.0:
    set(p_new_scale):
        _ozone_rel_density_scale = p_new_scale
        emit_changed()

@export var _ozone_color: Color = Color(0.8247156 , 0., 0.97920046):
    set(p_new_color):
        _ozone_color = p_new_color
        emit_changed()
