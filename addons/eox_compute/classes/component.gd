@tool
@abstract extends RefCounted
class_name EoxComputeComponent

var parent: EoxComputeParent
var name: String

func _init(parent: EoxComputeParent, name: String) -> void:
  self.parent = parent
  self.name = name
  self.parent.predelete.connect(_predelete)

@abstract 
func _predelete() -> void
