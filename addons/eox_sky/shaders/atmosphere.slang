module atmos;

import common;
import intersection;

namespace atmox {

public struct AtmosphereParams {
  // Radius of the planet in km.
  public float planet_radius = 6371.0; // 0
  // Thickness of the atmosphere in km.
  // This is a hard limit where we stop integration.
  public float atmosphere_thickness = 60.0; // 4
  // sqrt(ra^2 - re^2)
  public float atmosphere_tangent_length; // 8
  // Density decay constant with altitude of rayleigh pariticles (exp)
  public float rayleigh_density_decay = 8.0; // 12
  // Density decay constant with altitude of mie particles (exp)
  public float mie_density_decay = 1.2; // 16
  // Average altitude of ozone layer.
  public float ozone_altitude = 25.; // 20
  // Desity decay constant with altitude of ozone layer (linear)
  public float ozone_altitude_decay = 15.; // 24

  public float mie_eccentricity; // 28
  public int2 transmittance_lut_size = int2(256, 64); // 36
  float2 placeholder2; // 44
  float4 placeholder1; // 60

  // Scattering coefficient matrix of Rayleigh, mie, ozone particles
  public float3x3 scattering_matrix; // 108
  // Extinction coefficient matrix of Rayleigh, mie, ozone particles
  // Extinction is scattering + absorption
  public float3x3 extinction_matrix; // 152

  float4x4 placeholder3; // 216

  public func CalRayleighPhase(float cos_t) -> float {
    return 3.0 / (16.0 * kPi) * (1.0 + cos_t * cos_t);
  }

  public func HenyeyGreenstein(float cos_t, float g) -> float {
    const float k = 0.25 / kPi;
    return k * (1.0 - g * g) / (pow(1.0 + g * g - 2.0 * g * cos_t, 1.5));
  }

  public func CalMiePhase(float cos_t, float g) -> float {
    return HenyeyGreenstein(cos_t, g);
  }

  // Calculates the relative densities of different particles that participate
  // absorption and scattering. They all range from 0 to 1.

  public func CalRayleighDensity(float altitude) -> float {
    float density = exp(-altitude / 8.0);
    return density;
  }

  public func CalMieDensity(float altitude) -> float {
    float density = exp(-altitude / 1.2);
    return density;
  }

  public func CalOzoneDensity(float altitude) -> float {
    return max(0., 1. - abs(altitude - 25.) / 15.);
  }

  public func ComputeDensity(float altitude) -> float3 {
    float rayleigh = CalRayleighDensity(altitude);
    float mie = CalMieDensity(altitude);
    float ozone = CalOzoneDensity(altitude);
    return float3(rayleigh, mie, ozone);
  }

  public func ComputePhase(float cos_scatt) -> float3 {
    float rayleigh = CalRayleighPhase(cos_scatt);
    float mie = CalMiePhase(cos_scatt, mie_eccentricity);
    float ozone = 1. / (4. * kPi);
    return float3(rayleigh, mie, ozone);
  }

  public func ComputeExtinction(float3 density) -> float3 {
    float3 extinction = mul(density, extinction_matrix);
    return extinction;
  }

  public func ComputePhaseScattering(float3 density, float3 phase)->float3 {
    float3 phase_scattering = mul(density * phase, scattering_matrix);
    return phase_scattering;
  }

  public func ComputeRayAltitude(float start_radius, float start_cos_zenith, float ray_dist) ->float {
    float r = start_radius;
    float c = start_cos_zenith;
    float k = ray_dist;
    float h = sqrt(k * k + r * r + 2 * k * r * c) - planet_radius;
    return h;
  }
};

public struct AtmosExtraParams {
  public float scatter_multiplier;
};

public struct TransmitLutParams {
  float _ra;
  float _re;
  float _rt;

  public __init(AtmosphereParams atmos_params) {
    _ra = atmos_params.planet_radius + atmos_params.atmosphere_thickness;
    _re = atmos_params.planet_radius;
    _rt = atmos_params.atmosphere_tangent_length;
  }

  public __init(float planet_radius, float atmosphere_radius, float tangent_len) {
    _ra = atmosphere_radius;
    _re = planet_radius;
    _rt = tangent_len;
  }

  public func Decode(float2 uv)->float3 {
    var ra = _ra;
    var re = _re;
    var rt = _rt;
    var u = uv.x;
    var v = uv.y;
    var rh = rt * v; // observer to horizon dist
    var r = sqrt(rh * rh + re * re);
    var dmin = ra - r;
    var dmax = (1. + v) * rt;
    var d = u * (dmax - dmin) + dmin;
    var cos_zenith = (ra * ra - r * r - d * d) / (2.0 * r * d);
    return float3(cos_zenith, r, d);
  }

  public func Encode(float cos_zenith, float h) -> float2 {
    var ra = _ra;
    var re = _re;
    var rt = _rt;
    var r = re + h;
    var c = cos_zenith;
    var d = -r * c + sqrt(ra * ra + (c * c - 1) * r * r);
    var rh = sqrt(r * r - re * re);
    var dmin = ra - r;
    var dmax = rh + rt;
    var u = (d - dmin) / (dmax - dmin);
    var v = rh / rt;
    return float2(u, v);
  }
};

public struct ComputeTransmitLut {
  AtmosphereParams _atmos_params;
  TransmitLutParams _transmit_lut_params;

  public __init(AtmosphereParams atmos_params, ) {
    _atmos_params = atmos_params;
    _transmit_lut_params = TransmitLutParams(_atmos_params);
  }

  public func Compute(float2 uv)->float3 {
    let m = _transmit_lut_params.Decode(uv);
    let cos_zenith = m.x;
    let ray_length = m.z; // byproduct of uv decoding
    let ray_init_radius = m.y;

    let num_steps = 40;
    let step_length = ray_length / float(num_steps);
    float3 transmit = float3(1.0);
    for (int step_idx = 0; step_idx < num_steps; ++step_idx) {
      let k = ray_length * (float(step_idx) + 0.5) / float(num_steps);
      let r0 = ray_init_radius;
      let c0 = cos_zenith;
      let h = sqrt(k * k + r0 * r0 + 2 * k * r0 * c0) - _atmos_params.planet_radius;
      let density = _atmos_params.ComputeDensity(h);
      let extinction_rate = _atmos_params.ComputeExtinction(density);
      transmit *= exp(-extinction_rate * step_length);
    }
    return transmit;
  }
};

struct RayMarchSkySample {
  float radius;
  float sun_cos_zenith;
}

struct RayMarchSky {
  float _srt_radius;
  float _srt_cos_zenith;
  float _sun_cos_scatter;
  float _sun_cos_zenith;

  __init(float3 srt, float3 dir, float3 sun_dir) {
    var srt_length = length(srt);
    var srt_dir = srt / srt_length;
    _srt_radius = srt_length;
    _srt_cos_zenith = dot(srt_dir, dir);
    _sun_cos_zenith = dot(srt_dir, sun_dir);
    _sun_cos_scatter = dot(dir, sun_dir);
  }

  func SunCosScatter() -> float {
    return _sun_cos_scatter;
  }

  func Sample(float d) -> RayMarchSkySample {
    // altitude, cos_sun_zenith, cos_scatter
    float r = _srt_radius;
    float cos_s = _sun_cos_scatter;
    float ray_r = sqrt(r * r + d * d + 2. * r * d * _srt_cos_zenith);
    float ray_cos_zenith = (r * r + d * d - ray_r * ray_r) / (2. * d * r);
    float ray_cos_sun_zenith = (r * _sun_cos_zenith + d * cos_s) / ray_r;
    return RayMarchSkySample(ray_r, ray_cos_sun_zenith);
  }
};

public struct AtmosIntegrator : ISkyIntegrator {
  atmox::AtmosphereParams _atmos;
  AtmosExtraParams _atmos_extra_params;
  TransmitLutParams _transmit_lut_params;
  Sampler2D<float3> _transmit_lut;
  SkyLightSource _light;

  public __init(
      atmox::AtmosphereParams atmos, AtmosExtraParams atmos_extra_params,
      Sampler2D<float3> transmit_lut, SkyLightSource light) {
    _atmos = atmos;
    _atmos_extra_params = atmos_extra_params;
    _transmit_lut_params = TransmitLutParams(_atmos);
    _transmit_lut = transmit_lut;
    _light = light;
  }

  func ComputeSteps(float dist, SkyRayContext ctx) -> int {
    let remain_dist = ctx.total_dist - ctx.curr_dist;
    let remain_steps = ctx.total_steps - ctx.curr_steps;
    let a = dist / remain_dist;
    let num_steps = int(ceil(float(remain_steps) * a));
    return num_steps;
  }

  public override func Integrate(SkyRayCommon base, float2 range, inout SkyRayContext ctx) -> VolumeResult {
    let dist = range.y - range.x;
    var ret = VolumeResult();
    if (!(dist > 0.0 && ctx.total_dist > 0.0)) { return ret; }

    let ray = RayMarchSky(base.srt, base.dir, _light.dir);
    let phase = _atmos.ComputePhase(ray.SunCosScatter());
    let num_steps = ComputeSteps(dist, ctx);
    let delta = dist / float(num_steps);
    var k = range.x + delta * 0.5;
    var transmit_sam2cam = float3(1.0);
    var scatter = float3(0.0);
    for (int i = 0; i < num_steps; ++i) {
      let sample = ray.Sample(k);
      let altitude = sample.radius - _atmos.planet_radius;
      let density = _atmos.ComputeDensity(altitude);
      let extinction_rate = _atmos.ComputeExtinction(density);
      let local_transmit = exp(-extinction_rate * delta);
      float3 scatter_coeff = _atmos.ComputePhaseScattering(density, phase);
      let transmit_sun2sam = ComputeSun2SampleTransmit(altitude, sample.sun_cos_zenith);
      let scatter_rate = scatter_coeff * delta;
      scatter += scatter_rate * transmit_sun2sam * transmit_sam2cam;
      transmit_sam2cam *= local_transmit;
      k += delta;
    }
    ret.transmit = transmit_sam2cam;
    ret.emission = scatter * _atmos_extra_params.scatter_multiplier * _light.radiance;
    ctx.curr_steps = min(ctx.total_steps, ctx.curr_steps + num_steps);
    ctx.curr_dist = min(ctx.total_dist, ctx.curr_dist + dist);
    return ret;
  }

  func ComputeSun2SampleTransmit(float h, float sun_cos_zenith) -> float3 {
    var uv = _transmit_lut_params.Encode(sun_cos_zenith, h);
    var transmit = _transmit_lut.Sample(uv); // * float(uv.y <= 1.);
    return transmit;
  }
};

}
