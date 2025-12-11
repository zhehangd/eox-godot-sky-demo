@tool
extends CompositorEffect
class_name EoxComputeCompositorEffect

signal callback(RenderData)

func _render_callback(_type: int, render_data: RenderData) -> void:
    emit_signal("callback", render_data)
