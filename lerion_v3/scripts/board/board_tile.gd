class_name BoardTile
extends RefCounted
## Datele unei căsuțe de pe traseu. Etapa 2 va adăuga tipul de recompensă și valoarea de bază.

const KIND_START := &"start"
const KIND_NORMAL := &"normal"

var index: int = 0
## Poziția 3D a centrului căsuței (pe sol).
var position: Vector3 = Vector3.ZERO
## Direcția de mers (unitară, în planul XZ).
var forward: Vector3 = Vector3.FORWARD
var kind: StringName = KIND_NORMAL
## Clădirea cea mai apropiată (dacă e la cel mult zone_max_distance), altfel &"none".
var zone_building_id: StringName = &"none"
var zone_distance: float = INF


func yaw() -> float:
	return atan2(forward.x, forward.z)
