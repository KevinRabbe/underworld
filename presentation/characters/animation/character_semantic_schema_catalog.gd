extends RefCounted

const SemanticRoleSchema := preload("res://core/content/schema/semantic_role_schema.gd")
const SemanticRoleSchemaRegistry := preload("res://core/content/schema/semantic_role_schema_registry.gd")

const ANIMATION_ROLES: Array[String] = [
	"animation_role.locomotion.idle",
	"animation_role.locomotion.walk_forward",
	"animation_role.locomotion.walk_backward",
	"animation_role.locomotion.strafe_left",
	"animation_role.locomotion.strafe_right",
	"animation_role.locomotion.sprint",
	"animation_role.locomotion.jump_start",
	"animation_role.locomotion.fall",
	"animation_role.locomotion.land",
	"animation_role.action.attack.light_01",
	"animation_role.action.attack.heavy_01",
	"animation_role.action.tool_use",
	"animation_role.action.dodge.forward",
	"animation_role.action.dodge.backward",
	"animation_role.action.dodge.left",
	"animation_role.action.dodge.right",
	"animation_role.action.parry",
	"animation_role.action.block",
	"animation_role.reaction.hit.front",
	"animation_role.reaction.death",
]

const RIG_ROLES: Array[String] = [
	"rig_role.root",
	"rig_role.pelvis",
	"rig_role.spine.lower",
	"rig_role.spine.upper",
	"rig_role.chest",
	"rig_role.neck",
	"rig_role.head",
	"rig_role.clavicle.left",
	"rig_role.upper_arm.left",
	"rig_role.forearm.left",
	"rig_role.hand.left",
	"rig_role.clavicle.right",
	"rig_role.upper_arm.right",
	"rig_role.forearm.right",
	"rig_role.hand.right",
	"rig_role.thigh.left",
	"rig_role.calf.left",
	"rig_role.foot.left",
	"rig_role.thigh.right",
	"rig_role.calf.right",
	"rig_role.foot.right",
	"rig_role.socket.hand.left",
	"rig_role.socket.hand.right",
	"rig_role.socket.back",
	"rig_role.socket.hip.left",
	"rig_role.socket.hip.right",
]


static func build_registry():
	var schemas: Array = []
	for role_id in ANIMATION_ROLES:
		schemas.append(SemanticRoleSchema.new().configure(role_id))
	for role_id in RIG_ROLES:
		schemas.append(SemanticRoleSchema.new().configure(role_id))
	var registry = SemanticRoleSchemaRegistry.new()
	registry.index_schemas(schemas)
	return registry
