@tool
extends Resource
class_name EoxSkyPlanetParams

@export var _planet_radius: float = 6371.0:
    set(value):
        _planet_radius = value
        emit_changed()

@export var _atmosphere_thickness: float = 60.0:
    set(value):
        _atmosphere_thickness = value
        emit_changed()
