@tool
extends EoxComputeResource
class_name EoxComputeResMesh

# you need to manually create these variables.
# this class only cares about releasing them.

# data buffers e.g. vertex positions.
# this does not include vertex and index arrays.
var buffers: Array[RID] 
var vertex_array: RID
var index_array: RID
var vertex_format: int

func _predelete() -> void:
  var rd := parent.rd
  if vertex_array.is_valid():
    rd.free_rid(vertex_array)
  if index_array.is_valid():
    rd.free_rid(index_array)
  for rid in buffers:
    rd.free_rid(rid)
  buffers.clear()
  vertex_array = RID()
  index_array = RID()
