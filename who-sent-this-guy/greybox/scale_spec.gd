extends RefCounted
## Independent proportion study, using the 2026-11-15 delivery-game revision.
## Vector3 dimensions are always width X, height Y, length Z. Origins are at ground level.

const PERSON_HEIGHT := 1.2
const CROUCH_HEIGHT := 0.85
const PERSON_DIAMETER := 0.8
const PERSON_VISUAL_WIDTH := 0.96
const HEAD_DIAMETER := 0.8
const BODY_RADIUS := 0.16
const ARM_RADIUS := 0.09
const ARM_X := PERSON_VISUAL_WIDTH / 2.0 - ARM_RADIUS
const LEG_RADIUS := 0.07
const LEG_X := 0.12
const FOOT_SIZE := Vector3(0.20, 0.12, 0.28)
const STANDING_EYE := 1.02
const CROUCHING_EYE := 0.70
const TRUCK_SIZE := Vector3(3.0, 3.5, 8.8)
const BED_SIZE := Vector2(2.7, 5.8)
const BED_FLOOR := 0.7
const BED_CLEAR_HEIGHT := 2.68
const CABIN_LENGTH := 2.2
const PARTITION_DOOR_SIZE := Vector2(1.1, 1.9)
const REAR_DOOR_SIZE := Vector2(1.8, 2.0)
const SITE_SIZE := Vector2(100.0, 80.0)
const ZONE_SIZE := 14.0
const ROAD_WIDTH := 6.0
const LANE_WIDTH := ROAD_WIDTH / 2.0
const STRAIGHT_LENGTH := 30.0
const BUMP_HEIGHT := 0.12

# Construction choices where the document supplies no subdivision or placement.
const WALL_THICKNESS := 0.1
const SIDE_WALL_THICKNESS := (TRUCK_SIZE.x - BED_SIZE.x) / 2.0
const FLOOR_THICKNESS := 0.12
const BED_REAR := TRUCK_SIZE.z / 2.0 - WALL_THICKNESS
const BED_FRONT := BED_REAR - BED_SIZE.y
const BED_CENTER_Z := (BED_FRONT + BED_REAR) / 2.0
const PARTITION_Z := BED_FRONT - WALL_THICKNESS / 2.0
const CABIN_FRONT := -TRUCK_SIZE.z / 2.0 + WALL_THICKNESS
const CABIN_REAR := CABIN_FRONT + CABIN_LENGTH
# Visual construction samples only. Vehicle dynamics are not implemented here.
const WHEELBASE := 5.8
const TRACK := 2.7 # Track + tire width = 3 m, including both outer tire faces.
const WHEEL_RADIUS := 0.35
const FRONT_AXLE_Z := -3.4
const TIRE_WIDTH := 0.30
const RAMP_RUN := 2.1
const TURN_CENTER_RADIUS := 20.0
const BUMP_LENGTH := 2.4
const LOAD_CENTER := Vector3(-STRAIGHT_LENGTH / 2.0 - TURN_CENTER_RADIUS, 0.0, TURN_CENTER_RADIUS + ZONE_SIZE / 2.0)
const UNLOAD_CENTER := -LOAD_CENTER
const TRUCK_POSITION := LOAD_CENTER + Vector3(0.0, 0.0, -0.5)
const PERSON_A_POSITION := TRUCK_POSITION + Vector3(TRUCK_SIZE.x / 2.0 + 0.9, 0.0, (CABIN_FRONT + CABIN_REAR) / 2.0)
const PERSON_B_POSITION := TRUCK_POSITION + Vector3(0.0, BED_FLOOR, (CABIN_FRONT + CABIN_REAR) / 2.0 - 0.2)

const CARGO_TYPES := ["chicken_cage", "chicken_cage", "fish_tank", "fish_tank", "bomb", "bomb"]
const CARGO_IDS := ["C1", "C2", "F1", "F2", "X1", "X2"]
const CARGO_SIZES := {
	"chicken_cage": Vector3(0.8, 0.7, 0.6),
	"fish_tank": Vector3(0.9, 0.75, 0.65),
	"bomb": Vector3(0.65, 0.65, 0.65),
}
const CARGO_MASSES := {"chicken_cage": 18.0, "fish_tank": 35.0, "bomb": 45.0}
const GROUND_POSITIONS := [
	TRUCK_POSITION + Vector3(4.0, 0.0, -1.2), TRUCK_POSITION + Vector3(5.0, 0.0, -1.2),
	TRUCK_POSITION + Vector3(4.0, 0.0, 0.0), TRUCK_POSITION + Vector3(5.0, 0.0, 0.0),
	TRUCK_POSITION + Vector3(5.0, 0.0, 1.3), TRUCK_POSITION + Vector3(4.0, 0.0, 1.9),
]
# Relative to the truck. Left-side livestock and tanks, right-side bombs.
# The narrowest shared passage is X=-0.45 to +0.70: 1.15 m for a 0.96 m visual body.
const BED_POSITIONS := [
	Vector3(-0.95, BED_FLOOR, BED_FRONT + 0.60),
	Vector3(-0.95, BED_FLOOR, BED_FRONT + 1.35),
	Vector3(-0.90, BED_FLOOR, BED_FRONT + 2.175),
	Vector3(-0.90, BED_FLOOR, BED_FRONT + 2.975),
	Vector3(1.025, BED_FLOOR, BED_FRONT + 0.80),
	Vector3(1.025, BED_FLOOR, BED_FRONT + 2.85),
]

static func cargo_position(index: int, layout: int) -> Vector3:
	if layout in [0, 3, 4]:
		return GROUND_POSITIONS[index]
	var local: Vector3 = BED_POSITIONS[index]
	if layout == 2 and index < 2:
		local = Vector3(-0.95, BED_FLOOR + index * 0.7, BED_FRONT + 0.60)
	return TRUCK_POSITION + local

static func person_position(index: int, layout: int) -> Vector3:
	if index >= person_count(layout):
		return TRUCK_POSITION + Vector3(0, -10, 0)
	if layout == 4:
		return TRUCK_POSITION + Vector3((index - 1) * PERSON_VISUAL_WIDTH, BED_FLOOR, BED_CENTER_Z)
	if layout == 3:
		var offsets := [Vector3(-0.65, BED_FLOOR, BED_FRONT + 0.9),
			Vector3(0.65, BED_FLOOR, BED_FRONT + 0.9),
			Vector3(-0.65, BED_FLOOR, BED_REAR - 0.9),
			Vector3(0.65, BED_FLOOR, BED_REAR - 0.9)]
		return TRUCK_POSITION + offsets[index]
	if index == 0:
		return PERSON_A_POSITION
	if layout in [0, 5]:
		if index == 1:
			return PERSON_B_POSITION
		return TRUCK_POSITION + Vector3(-0.65 if index == 2 else 0.65,
			BED_FLOOR, BED_CENTER_Z + 0.6)
	var rear_positions := [Vector3(0.125, BED_FLOOR, BED_FRONT + 0.55),
		Vector3(0.125, BED_FLOOR, BED_FRONT + 2.50), Vector3(0.125, BED_FLOOR, BED_REAR - 0.70)]
	return TRUCK_POSITION + rear_positions[index - 1]

static func person_count(layout: int) -> int:
	if layout == 4:
		return 3 # Deliberately over-wide static sample: 2.88 m does not fit a 2.70 m cabin.
	return 2 if layout == 5 else 4

static func person_yaw(index: int, layout: int) -> float:
	if layout == 4:
		return 0.0
	return [-PI / 2.0, PI, -PI / 2.0, PI / 2.0, 0.0][index]

static func person_profile(crouched: bool) -> Dictionary:
	return {
		"head_y": (CROUCH_HEIGHT if crouched else PERSON_HEIGHT) - HEAD_DIAMETER / 2.0,
		"body_height": 0.32 if crouched else 0.36,
		"body_y": 0.16 if crouched else 0.25,
		"arm_height": 0.18 if crouched else 0.24,
		"arm_y": 0.17 if crouched else 0.29,
		"hand_y": 0.10 if crouched else 0.17,
		"leg_height": 0.14 if crouched else 0.18,
		"leg_y": 0.09 if crouched else 0.14,
	}
