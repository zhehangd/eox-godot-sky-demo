import common;
import atmosphere; // atmox::
// import noise;      // noix::
import intersection; // isect;
// import cloud; // cloud::
// import cloud_noise;
import octahedral_mapping; // octmap

static const float kMinCloudViewDistance = 0.0625; // km

// Rendering parameters that matter at rendering time but don't change often.
struct SkyParams {
	float3 sun_radiance = kPi;
	float sun_disk_radius = 1.0;
  float3 ground_albedo = 0.05;
  float ground_ambient = 0.02;
  float sky_scattering_multiplier = 1.2;  // 296
  float cloud_scattering_multiplier = 1.2;  // 296
  float pad1;
  float pad2;
  float4 pad4;
}; // 64

// Parameters usually changing every frame. 
struct FrameParams {
  // Transforms a clip space position to planet space direction vector.
  // Normalization is required after transformation (in fragment shader).
	float4x4 clip2planet_norm_matrix;
  // Position of the camera in planet space.
  float3 camera_position;
  int2 viewport_size;
  float time;
  int frame;
	float3 sun_dir;
  float pad1;
  float pad2;
	float max_exposure;
  float exposure_multiplier;
  float pad3;
  float4x4 prev_planet2clip_norm_matrix;
  float3 prev_camera_position;
  float4 pad4;
  float4 pad5;
  float4 pad6;
  // 256
};

// struct CameraParams {
// 	float4x4 clip2planet_norm_matrix;
//   float4x4 prev_planet2clip_norm_matrix;
//   float3 camera_position;
//   float3 prev_camera_position;
// };
// [[vk::push_constant]] CameraParams _cam_params;

ConstantBuffer<atmox::AtmosphereParams> _atmos_params; // 0
RWTexture2D<float3> _atmos_transmit_lut_w; // 1
Sampler2D<float3> _atmos_transmit_lut_r; // 2
ConstantBuffer<FrameParams> _frame_params; // 3
ConstantBuffer<SkyParams> _sky_params; // 4
RWTexture2D<float4> _foreground_color_texture; // 5
Texture2D<float> _foreground_depth_texture; // 6
RWTexture2D<float4> _sky_octmap_texture; // 7


func DrawSun(float3 color, float3 srt, float3 dir, float3 sun_dir, float disk_radius, float3 sun_radiance) -> float3 {
  float c = cos(8.727e-3 * disk_radius);
  float cos_a = dot(dir, normalize(sun_dir));
  float a = step(c, cos_a);
  float3 sun_color = sun_radiance * 1.47e4;
  color = lerp(color, sun_color, a);
  return color;
}

[shader("compute")]
[numthreads(8, 8, 1)]
void ComputeAtmosTransmitLut(uint3 thread_id: SV_DispatchThreadID) {
  var image_size = int2(0);
  _atmos_transmit_lut_w.GetDimensions(image_size.x, image_size.y);
  let image_pos = int2(thread_id.xy);
  let uv = (float2(image_pos) + 0.5) / float2(image_size);
  let compute = atmox::ComputeTransmitLut(_atmos_params);
  _atmos_transmit_lut_w[image_pos] = compute.Compute(uv);
}

struct RenderSkyResult {
  float3 color;
  float dist;
};

func ClampMaxDist(float2[2] ranges, float max_dist)->float2[2] {
  ranges[0] = min(max_dist, ranges[0]);
  ranges[1] = min(max_dist, ranges[1]);
  return ranges;
}

// TODO: just make the light structure a uniform
func RenderSky(SkyRayCommon ray, SkyLightSource light, float max_dist) -> VolumeResult {

  var atmos_extra_params = atmox::AtmosExtraParams();
  atmos_extra_params.scatter_multiplier = _sky_params.sky_scattering_multiplier;
  let atmos_integrator = atmox::AtmosIntegrator(_atmos_params, atmos_extra_params, _atmos_transmit_lut_r, light);

  let transmit_lut_params = atmox::TransmitLutParams(_atmos_params);
  // var cloud_noise_params = flower::CloudCompositeParams();
  // cloud_noise_params.coverage = _cloud_params.coverage;
  // cloud_noise_params.time = _frame_params.time;
  // var cloud_extra_params = cloud::CloudExtraParams();
  // cloud_extra_params.scatter_multiplier = _sky_params.cloud_scattering_multiplier;
  // let cloud_field = flower::CloudField(
  //     cloud_noise_params, _weather_map, _shape_noise_map_r, _detail_noise_map_r);
  // let cloud_integrator = cloud::RenderCloud<flower::CloudField>(
  //   _cloud_params, cloud_extra_params, transmit_lut_params, _atmos_transmit_lut_r, cloud_field, light);

  let ray_sphere = isect::RaySphereEquation(ray.srt, ray.dir);
  let atmos_btm_radius = _atmos_params.planet_radius;
  let cloud_btm_radius = atmos_btm_radius + 1.5;
  let cloud_top_radius = atmos_btm_radius + 1.6;
  let atmos_top_radius = atmos_btm_radius + _atmos_params.atmosphere_thickness;
  let atmos_btm_del = ray_sphere.SphereDelta(atmos_btm_radius);
  let cloud_btm_del = ray_sphere.SphereDelta(cloud_btm_radius);
  let cloud_top_del = ray_sphere.SphereDelta(cloud_top_radius);
  let atmos_top_del = ray_sphere.SphereDelta(atmos_top_radius);
  let atmos_ranges = ClampMaxDist(ray_sphere.LayerRange(
     atmos_btm_del, atmos_top_del, atmos_btm_del), max_dist);

  var atmos_ctx = SkyRayContext();
  atmos_ctx.total_dist = ray_sphere.LayerRangeDist(atmos_ranges);
  let total_dist = atmos_ranges[1].y;
  atmos_ctx.total_steps = 64;

  var volume = VolumeResult();
  volume.Merge(atmos_integrator.Integrate(ray, atmos_ranges[0], atmos_ctx));
  volume.Merge(atmos_integrator.Integrate(ray, atmos_ranges[1], atmos_ctx));
  return volume;
}

struct VertexIn {
  float4 position : POSITION;
};

struct VertexOutput {
  float4 sv_position     : SV_Position;
  //Varying varying    : CoarseVertex;
};

[shader("compute")]
[numthreads(8, 8, 1)]
void RenderSkyOctmap(uint3 thread_id: SV_DispatchThreadID) {
  let image_pos = thread_id.xy;
  var image_size = int2(0);
  _sky_octmap_texture.GetDimensions(image_size.x, image_size.y);
  let image_uv = float2(image_pos) / float2(image_size);

  let srt = _frame_params.camera_position;
  let dir = octmap::Decode(image_uv);
  float3 sun_dir = _frame_params.sun_dir;
  let ray_pos_offset = 0.5;
  let ray = SkyRayCommon(srt, dir, ray_pos_offset);
  let light = SkyLightSource(_frame_params.sun_dir, _sky_params.sun_radiance);
  let volume = RenderSky(ray, light, kInf);
  var color = float3(0.0);
  color = DrawSun( color, ray.srt, ray.dir, light.dir, _sky_params.sun_disk_radius, light.radiance);
  color = volume.transmit * color + volume.emission;
  color *= _frame_params.exposure_multiplier;
  color = clamp(color, 0.0, _frame_params.max_exposure);

  //let color = float3(image_uv.x, image_uv.y, 0.0);
  _sky_octmap_texture[int2(thread_id.xy)] = float4(color, 1.0);
}

[shader("vertex")]
VertexOutput RenderSkyBackgroundVert(VertexIn input) {
  VertexOutput output;
  output.sv_position = input.position; // clip space
  return output;
}

[shader("fragment")]
float4 RenderSkyBackgroundFrag(float4 screen_pos: SV_Position) : SV_Target {
  let screen_uv = screen_pos.xy / float2(_frame_params.viewport_size);
  var clip_pos = float4(screen_uv * 2.0 - 1.0, 1.0, 1.0);
  float3 srt = _frame_params.camera_position;
  float3 dir = normalize(mul(clip_pos, float4x3(_frame_params.clip2planet_norm_matrix)));
  float3 sun_dir = _frame_params.sun_dir;
  let ray_pos_offset = 0.5;
  let ray = SkyRayCommon(srt, dir, ray_pos_offset);
  let light = SkyLightSource(_frame_params.sun_dir, _sky_params.sun_radiance);
  let volume = RenderSky(ray, light, kInf);
  var color = float3(0.0);
  color = DrawSun( color, ray.srt, ray.dir, light.dir, _sky_params.sun_disk_radius, light.radiance);
  color = volume.transmit * color + volume.emission;
  color *= _frame_params.exposure_multiplier;
  color = clamp(color, 0.0, _frame_params.max_exposure);
  // let dist = volume.weight > 0. ? volume.pos / volume.weight : kInf;
  return float4(color, 1.0);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void RenderSkyForeground(uint3 thread_id: SV_DispatchThreadID) {
  let screen_pos_f2 = floor(thread_id.xy) + 0.5;
  let screen_pos_i2 = thread_id.xy;
  let screen_uv = screen_pos_f2 / float2(_frame_params.viewport_size);
  float depth = _foreground_depth_texture[screen_pos_i2];
  var clip_pos = float4(screen_uv * 2.0 - 1.0, depth, 1.0);
  float3 srt = _frame_params.camera_position;
  float4 dir4 = mul(clip_pos, _frame_params.clip2planet_norm_matrix);
  let dir3 = dir4.xyz / dir4.w;
  let dist_m = length(dir3); // this is engine world space dist, we assume meter here
  let dir = dir3 / dist_m;
  let dist = dist_m * 1e-3;
  float3 sun_dir = _frame_params.sun_dir;
  let ray_pos_offset = 0.5;
  let ray = SkyRayCommon(srt, dir, ray_pos_offset);
  let light = SkyLightSource(_frame_params.sun_dir, _sky_params.sun_radiance);
  var color = float3(0.0);
  if (depth > 0.0) {
    let volume = RenderSky(ray, light, dist);
    color = _foreground_color_texture[screen_pos_i2].rgb;
    color = volume.transmit * color + volume.emission * _frame_params.exposure_multiplier;
    color = clamp(color, 0.0, _frame_params.max_exposure);
    _foreground_color_texture[screen_pos_i2] = float4(color, 1.);
  }
}
