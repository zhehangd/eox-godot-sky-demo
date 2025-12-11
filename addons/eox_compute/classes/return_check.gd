extends RefCounted
class_name EoxComputeReturnCheck

var _ret: Variant = null
var _error: Error = OK
var _error_message: String = ""
var _enable_stack: bool = false

static func convert_var(val: Variant) -> Error:
  var error: Error
  match typeof(val):
    TYPE_NIL:
      error = Error.ERR_UNAVAILABLE
    TYPE_BOOL:
      error = Error.OK if val else Error.FAILED
    TYPE_INT:
      error = val
    TYPE_RID:
      error = Error.OK if RID(val).is_valid() else Error.FAILED
    _:
      error = Error.OK
  return error

func catch(val: Variant, err_msg: String = "") -> bool:
  _error = convert_var(val)
  if _error != OK:
    var used_err_msg := _error_message if err_msg.is_empty() else _error_message
    if not used_err_msg.is_empty(): push_error(used_err_msg)
    if _enable_stack: print_stack()
  return _error

# Enable if you have first-handed error to report.
func enable_stack(enable: bool = true) -> void:
  _enable_stack = enable

func set_return(ret: Variant) -> void:
  _ret = ret

func err_msg_begin(err_text: String) -> void:
  _error_message = err_text

func err_msg_end() -> void:
  _error_message = ""

func ret() -> Variant:
  return _ret

func err() -> Error:
  return _error
