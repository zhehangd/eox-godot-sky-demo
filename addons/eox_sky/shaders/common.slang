module common;

public static const float kPi = radians(180.0);
public static const float kInf = 1.0 / 0.0;

public func MapRangeLinear(
    float v, float omin, float omax, float nmin, float nmax) -> float {
  return nmin + (v - omin) / (omax - omin) * (nmax - nmin);
}

public struct VolumeResult {
  // Transmittance. It contributes to the final radiance by multiplying the
  // background radiance.
  public float3 transmit = float3(1.);
  // Emission. It contributes to the final radiance directly.
  public float3 emission = float3(0.);

  // Visibility is used as a weight, for mixing properties like position and
  // motion vector of volumes. Typically it is assigned with the transmittance
  // of the volume, but no color. For example, it can be the maximum of
  // transmittance RGB. Naturally, visibility is merged like transmittance.
  public float visibility = 1.0;
  public float weight = 0.0;
  public float pos = 0.0; // k of ray srt+dir*k, weighted by visibility.

  // from near to far
  [mutating]
  public func Merge(VolumeResult vol) -> void {
    emission += vol.emission * transmit;
    transmit *= vol.transmit;
    pos += vol.pos * visibility;
    weight += vol.weight * visibility;
    visibility *= vol.visibility;
  }
};

public struct SkyLightSource {
  public float3 dir;
  public float3 radiance;
};

public struct SkyRayCommon {
  // Position of the viewer and the start point of the ray.
  public float3 srt;
  // Direction of the ray. A unit vector is required.
  public float3 dir;
  // Random number between 0 and 1 for offsetting the ray position
  public float offset;
};

// Provide global integration information
// How they are interpreted and updated is up to implementations.
public struct SkyRayContext {
  // Total distance to be integrated (all segments belong to the same context).
  // Typically set the controller and remain constant during integration.
  public float total_dist = 0.0;
  // Distance that has been processed before the current segment.
  // Typically updated by each integrator.
  public float curr_dist = 0.0;
  // Total steps allowed to be used.
  // Typically set the controller and remain constant during integration.
  public int total_steps = 0;
  // Steps that have been used before the current segment.
  // Typically updated by each integrator.
  public int curr_steps = 0;
};

public interface ISkyIntegrator {
  public func Integrate(
      SkyRayCommon base, float2 range, inout SkyRayContext ctx) -> VolumeResult;
};

// public struct PlanetParams {
//   // Planet radius
//   public float radius = 6371.;
//   // This is where atmosphere ends
//   public float atmosphere_altitude = 60.;
//   // This is where fog and haze end and clouds start.
//   public float cloud_altitude = 1.5;
//   // This is where clouds end
//   public float cloud_thickness = 4.0;

//   // aurora altitude > atmosphere top altitude
//   // aurora thickness
//   public float4 pad0;
// };