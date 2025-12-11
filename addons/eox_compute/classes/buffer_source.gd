@tool
@abstract extends EoxComputeComponent
class_name EoxComputeBufferSource

signal changed

func emit_changed():
  changed.emit()

# Returns the size of the buffer.
# This should be a constant.
@abstract
func pack_data_size() -> int

# Packs data that matches the layout of the buffer.
@abstract
func pack_data() -> PackedByteArray
