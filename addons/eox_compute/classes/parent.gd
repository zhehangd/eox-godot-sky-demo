@tool
extends Node
class_name EoxComputeParent

signal predelete

var rd: RenderingDevice = RenderingServer.get_rendering_device()

var fatal: bool

func _notification(what: int) -> void:
  if what == NOTIFICATION_PREDELETE:
    predelete.emit()
        
func set_fatal(text: String) -> void:
  push_error(text)
  fatal = true
  return
