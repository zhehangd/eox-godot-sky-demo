@tool
extends EoxComputeComponent
class_name EoxComputeResTexture

# RenderingDevice Resource (not RenderingServer!)
var _texture: RID

# It can only detect RID changes, not the content of the RID.
signal changed

# if false, the resource is considered managed by someone else and this class
# will not free it.
var _managed: bool = true

func _release() -> void:
  if _texture.is_valid() and _managed:
    var rd := parent.rd
    rd.free_rid(_texture)
  _texture = RID()
  _managed = true

func _predelete() -> void:
  _release()

func set_texture(texture: RID, managed: bool) -> Error:
  var err := OK
  _release()
  if texture.is_valid():
    if not parent.rd.texture_is_valid(texture):
      err = Error.ERR_INVALID_PARAMETER
  if err == OK:
    _texture = texture
    _managed = managed
  changed.emit()
  return err

func get_texture() -> RID:
  return _texture
