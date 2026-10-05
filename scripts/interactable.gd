class_name Interactable
extends StaticBody3D
## Something the player can aim at and use: terminals, the pilot seat.

signal used(by: Node)

var prompt := "Use"


func _init(p_prompt := "Use", size := Vector3.ONE, solid := false) -> void:
	prompt = p_prompt
	collision_layer = Vox.L_INTERACT | (Vox.L_WORLD if solid else 0)
	collision_mask = 0
	Vox.add_shape(self, Vector3.ZERO, size)


func interact(by: Node) -> void:
	used.emit(by)
