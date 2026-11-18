class_name Sea
extends RefCounted
## The sea's one question: where the wind blows, and how well a ship
## heading some way can use it. The wind swings slowly round over minutes.
## Running before it is quick, a beam reach quickest, close-hauled slow,
## and straight into it (in irons) barely moving at all.

const LEVEL := 0.0

static func wind_angle() -> float:
	var t := Time.get_ticks_msec() * 0.001
	return 0.8 + sin(t * 0.0045) * 1.3 + sin(t * 0.0011 + 2.0) * 1.9

## The way the wind blows toward, flat.
static func wind() -> Vector3:
	var a := wind_angle()
	return Vector3(sin(a), 0.0, cos(a))

## 0 (no drive) .. 1 (best point of sail) for a ship heading `fwd`.
static func efficiency(fwd: Vector3) -> float:
	var deg := rad_to_deg(acos(clampf(fwd.normalized().dot(wind()), -1.0, 1.0)))
	var pts := [[0.0, 0.78], [45.0, 0.93], [90.0, 1.0], [120.0, 0.85], [140.0, 0.5], [155.0, 0.2], [180.0, 0.12]]
	for k in pts.size() - 1:
		if deg <= float(pts[k + 1][0]):
			var f := (deg - float(pts[k][0])) / (float(pts[k + 1][0]) - float(pts[k][0]))
			return lerpf(float(pts[k][1]), float(pts[k + 1][1]), f)
	return 0.12

static func point_of_sail(fwd: Vector3) -> String:
	var deg := rad_to_deg(acos(clampf(fwd.normalized().dot(wind()), -1.0, 1.0)))
	if deg < 35.0:
		return "RUNNING"
	if deg < 110.0:
		return "REACHING"
	if deg < 148.0:
		return "CLOSE-HAULED"
	return "IN IRONS"
