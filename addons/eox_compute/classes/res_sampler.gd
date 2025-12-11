@tool
extends EoxComputeComponent
class_name EoxComputeResSampler

var _sampler: RID

func _release() -> void:
  if _sampler.is_valid():
    var rd := parent.rd
    rd.free_rid(_sampler)
  _sampler = RID()

func _predelete() -> void:
  _release()

func set_sampler(sampler: RID) -> Error:
  var ck := EoxComputeReturnCheck.new()
  var err := OK
  _release()
  ck.enable_stack()
  if ck.catch(sampler): return ck.err()
  _sampler = sampler
  return OK

func get_sampler() -> RID:
  return _sampler
