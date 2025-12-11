@tool
extends EoxComputeComponent
class_name EoxComputeResBuffer

signal changed

# If not null, the buffer track the content of this object.
var _source: EoxComputeBufferSource
var _size: int
var _buffer: RID
var _changed: bool = false

func _predelete() -> void:
  _detach_source(_source)
  _release_buffer(_buffer)
  _source = null
  _buffer = RID()

func _release_buffer(buffer: RID) -> void:
  if buffer.is_valid(): parent.rd.free_rid(buffer)

func _detach_source(source: EoxComputeBufferSource) -> void:
  source.changed.disconnect(_on_source_changed)

func _detach_and_attach_source(dst: EoxComputeBufferSource, src: EoxComputeBufferSource) -> Error:
  var status: Error
  if dst != null:
    _detach_source(dst)
    dst = null
  if src != null:
    status = src.changed.connect(_on_source_changed)
  return status

# Returns or creates new buffer (and possibly frees the old) to make sure
# the buffer has the given size. If a replacement happens, the previous
# buffer will be freed before creating a new one.
func _prepare_buffer(curr_buffer: RID, curr_size: int, new_size: int) -> RID:
  if curr_buffer.is_valid() and (curr_size == new_size): return curr_buffer
  _release_buffer(curr_buffer)
  var rd := parent.rd
  curr_buffer = rd.uniform_buffer_create(new_size, PackedByteArray(), 0)
  if not curr_buffer.is_valid():
    push_error("failed to create buffer %s" % [name])
  return curr_buffer

func set_source(source: EoxComputeBufferSource) -> Error:
  var status: Error
  status = _detach_and_attach_source(_source, source)
  _source = null
  if status != OK: return status
  
  var size := source.pack_data_size()
  var buffer := _prepare_buffer(_buffer, _size, size)
  _buffer = RID() # if reused, it is assigned to buffer.
  _size = 0
  if not buffer.is_valid(): return FAILED
  _buffer = buffer
  _size = size
  _source = source
  _on_source_changed()
  return OK

func update_on_changed() -> Error:
  if _changed == false: return OK
  _changed = false
  var ck := EoxComputeReturnCheck.new()
  ck.err_msg_begin("failed to update res buffer %s" % name)
  if ck.catch(_source): return ck.err()
  var data := _source.pack_data()
  if ck.catch(not data.is_empty()): return ck.err()
  if ck.catch(data.size() == _size): return ck.err()
  if ck.catch(parent.rd.buffer_update(_buffer, 0, _size, data)): return ck.err()
  emit_changed()
  return OK

func get_buffer() -> RID:
  return _buffer

func emit_changed() -> void:
    changed.emit()

func _on_source_changed() -> void:
  _changed = true
  emit_changed()
    
