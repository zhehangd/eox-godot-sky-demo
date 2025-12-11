module intersection;

namespace isect {

public struct RaySphereEquation {
  typealias Delta = Optional<float>;
  typealias RangePair = float2[2];

  float _k;
  float _d;

  public __init(float3 srt, float3 dir) {
    _k = -dot(srt, dir);
    _d = sqrt(dot(srt, srt) - _k * _k);
  }

  public func MinDistance() -> float {
    return _d;
  } 

  public func MinRayPosition() -> float {
    return _k;
  }

  public func SphereDelta(float r) -> Delta {
    Optional<float> ret;
    var v = r * r - _d * _d;
    if (v > 0.0) { ret = sqrt(v); }
    return ret;
  }

  public func SphereHit(float r) -> bool {
    var del = SphereDelta(r);
    bool hit;
    if (!del.hasValue) {
      hit = false;
    } else if (_k - del.value > 0.0) {
      hit = true;
    } else if (_k + del.value > 0.0) {
      hit = _k > 0.0;
    }
    return hit;
  }

  public func LayerRange(
      Delta del_btm, Delta del_top, Delta del_earth,
      float2 clamp_range = float2(0., 1. / 0.)) -> RangePair {
    let dmin = clamp_range.x;
    let dmax = clamp_range.y;
    RangePair ret = {float2(0.), float2(0.)};
    if (!del_top.hasValue) {
      // The top sphere has no intersection, it means that the ray is completely
      // outside the layer.
    } else if (!del_btm.hasValue) {
      // The bottom sphere has no intersection, it means that the start point is
      // inside the layer. The intersection range is continuous and is given
      // by the two roots.
      ret[0] = clamp(float2(_k - del_top.value, _k), dmin, dmax);
      ret[1] = clamp(float2(_k, _k + del_top.value), dmin, dmax);
    } else {
      // Intersect both
      ret[0] = clamp(float2(_k - del_top.value, _k - del_btm.value), dmin, dmax);
      ret[1] = clamp(float2(_k + del_btm.value, _k + del_top.value), dmin, dmax);
    }
    if (del_earth.hasValue) {
      // The surface of the planet may block the second segment of the ray.
      // This happens in two cases:
      // 1. the ray hits the surface from outside.
      // 2. the ray starts from inside the planet and looks downwards.
      // If the ray starts from inside the planet but looks upwards, we assume
      // that the viewer is inside a pit and can see through the planet surface.
      if ((_k - del_earth.value > 0.0) || _k > 0.0) {
        ret[1] = float2(0.0);
      }
    }
    return ret;
  }

  public func LayerRangeDist(RangePair p) -> float {
    return p[0].y - p[0].x + p[1].y - p[1].x;
  }
};

// Defines necessary parameters of a ray for sphere intersection tests,
// and provide functions to perform these intersection tests.
public struct SphereRay {

  // K and D2 describe the properties of the point on the ray closest to
  // the origin, where K is the signed distance to the start point, and
  // D2 is the squared distance from that point to the origin.
  float K;
  float D2;

  public __init(float3 srt, float3 dir) {
    K = -dot(srt, dir);
    D2 = dot(srt, srt) - K * K;
  }

  // Computes the interval of intersection with a sphere of radius r.
  // The resulting float2 contains the near and far intersection distances
  // k so that srt + dir * k is inside the sphere. If there is no
  // intersection, the returned interval will have non-positive length.
  public func ComputeSphereIntersection(float r) -> float2 {
    let d = sqrt(max(0., r * r - D2));
    return K + float2(-d, d);
  }

  // Computes the interval of intersection with a spherical shell of non-zero
  // thickness and a smaller sphere that blocks the ray. `re` defines the
  // radius of blocking sphere, `ra` and `rb` define the radii of the inner
  // and outer spheres of the shell respectively. The result is concatenated
  // by two intervals, each may be empty.
  public func ComputeSkyLayerIntersection(float re, float ra, float rb) -> float4 {
    let da = ComputeSphereIntersection(ra);
    let db = ComputeSphereIntersection(rb);
    let sn = max(0.0, float2(db.x, da.x));
    let sp = max(0.0, float2(da.y, db.y));
    var segs = float4(sn.x, sn.y, sp.x, sp.y);
    if (D2 < (re * re)) {
      if (K > 0.) {
        segs.zw = 0.;
      } else {
        segs.xy = 0.;
      }
    }
    return segs;
  }
};

public func ComputeSphereShellIntersectionRange(
    float re, float ra, float3 srt, float3 dir) -> float2 {
  let eq = RaySphereEquation(srt, dir);
  var del_a = eq.SphereDelta(ra);
  var del_e = eq.SphereDelta(re);
  // The outer shell has no intersection, it means that the ray is completely
  // outside the layer.
  if (!del_a.hasValue) {
    return float2(0.0);
  }
  // The inner shell has no intersection, it means that the start point is
  // inside the layer. The intersection range is continuous and is given
  // by the two roots.
  if (!del_e.hasValue) {
    return max(0.0, eq.MinRayPosition() + float2(-del_a.value, del_a.value));
  }
  // Otherwise, the intersection range is split into two segments.
  // Currently, we assume only the positive segment is needed.
  // It is ok if we are under the layer.
  if (dir.y < 0.0) { return float2(0.0, 0.0); }
  return max(0.0, eq.MinRayPosition() + float2(del_e.value, del_a.value));
}

}