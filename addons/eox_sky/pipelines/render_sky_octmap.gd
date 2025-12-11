extends EoxComputePipeline
class_name EoxSkyRenderSkyOctmap

func compute() -> void:
  var groups := compute_groups2(Vector2i(256, 256), Vector2i(8, 8))
  var pipeline = parent.rd.compute_pipeline_create(_shader)
  execute_simple_compute_pipeline(pipeline, groups)
  parent.rd.free_rid(pipeline)
