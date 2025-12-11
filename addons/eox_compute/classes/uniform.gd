@tool
@abstract extends EoxComputeComponent
class_name EoxComputeUniform

signal changed

var _binding: int = -1

@abstract
func add_uniform(uniforms: Array[RDUniform]) -> Error

func get_binding() -> int:
  return _binding

func set_binding(binding: int) -> void:
  _binding = binding

func emit_changed() -> void:
  changed.emit()
