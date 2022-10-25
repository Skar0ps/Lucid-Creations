extends Control

signal prompt_inject_requested(tokens)

var model_id_map := {"Any model": 0}

onready var model_select = $"%ModelSelect"
onready var stable_horde_models := $"%StableHordeModels"
onready var model_info = $"%ModelInfo"
onready var model_trigger = $"%ModelTrigger"
onready var model_info_card = $"%ModelInfoCard"
onready var model_info_label = $"%ModelInfoLabel"


func _ready():
	# warning-ignore:return_value_discarded
	stable_horde_models.connect("models_retrieved",self, "_on_models_retrieved")
	# warning-ignore:return_value_discarded
	stable_horde_models.connect("request_failed",self, "_on_request_failed")
	# warning-ignore:return_value_discarded
	stable_horde_models.connect("request_warning",self, "_on_request_warning")
	# warning-ignore:return_value_discarded
	model_info.connect("pressed", self, "_on_model_info_pressed")
	# warning-ignore:return_value_discarded
	model_trigger.connect("pressed", self, "_on_model_trigger_pressed")
#	connect("item_selected",self,"_on_item_selected") # Debug
	model_info_label.connect("meta_clicked",self, "_on_model_info_meta_clicked")
	model_select.connect("item_selected",self,"_on_model_changed")
	init_refresh_models()


func get_selected_model() -> String:
	for model_name in model_id_map:
		if model_id_map[model_name] == model_select.selected:
			return(model_name)
	push_error("Current selection does not match a model in the model_id_map!")
	return('')


func init_refresh_models() -> void:
	stable_horde_models.get_models()


func _on_models_retrieved(model_names: Array, model_reference: Dictionary):
	model_select.clear()
	model_id_map = {"Any model": 0}
#	print_debug(model_names, model_reference)
	model_select.add_item("Any model")
	# We start at 1 because "Any model" is 0
	for iter in range(model_names.size()):
		var model_name = model_names[iter]
		# We ignore unknown model names
		if not model_reference.empty() and not model_reference.has(model_name):
			continue
		var id = iter + 1
		model_id_map[model_name] = id
		var model_fmt = {
			"model_name": model_name,
		}
		var model_entry = "{model_name}"
		if not model_reference.empty():
			model_fmt["style"] = model_reference[model_name].get("style",'')
			model_entry = "{model_name} ({style})"
		model_select.add_item(model_entry.format(model_fmt))
	set_previous_model()
#	print_debug(model_reference)
	_on_model_changed()


func set_previous_model() -> void:
	var config_models = globals.config.get_value("Parameters", "models", ["stable_diffusion"])
	var previous_selection: String
	if config_models.empty():
		previous_selection = "Any model"
	else:
		previous_selection = config_models[0]
	model_select.selected = 0
	for idx in range(model_select.get_item_count()):
#		if get_item_text(idx) == previous_selection:
		if model_select.get_item_id(idx) == model_id_map.get(previous_selection,-1):
			model_select.selected = idx
			break


func get_selected_model_reference() -> Dictionary:
	var model_reference : Dictionary = stable_horde_models.model_reference.get_model_info(get_selected_model())
	return(model_reference)


func _on_request_initiated():
	init_refresh_models()

#func _on_item_selected(_index):
#	print_debug(get_selected_model())


func _on_model_info_pressed() -> void:
	var model_name = get_selected_model()
	if model_name == "Any model":
		model_info_label.bbcode_text = """This option will cause each image in your request to be fulfilled by workers running any model.
As such, the result tend to be quite random as the image can be sent to something specialized which requires more specific triggers."""
	else:
		var model_reference := get_selected_model_reference()
		if model_reference.empty():
			model_info_label.bbcode_text = "No model info could not be retrieved at this time."
		else:
			var fmt = {
				"description": model_reference['description'],
				"version": model_reference['version'],
				"style": model_reference['style'],
				"trigger": model_reference.get('trigger'),
				"homepage": model_reference.get('homepage'),
			}
			var label_text = "Description: {description}\nVersion: {version}\n".format(fmt)\
					+ "Style: {style}".format(fmt)
			if fmt['trigger']:
				label_text += "\nTrigger token(s): '{trigger}'".format(fmt)
			if fmt['homepage']:
				label_text += "\nHomepage: [url=homepage]{homepage}[/url]".format(fmt)
			model_info_label.bbcode_text = label_text
	model_info_card.popup()
	model_info_card.rect_global_position = get_global_mouse_position() + Vector2(30,0)



func _on_model_info_meta_clicked(meta):
	match meta:
		"homepage":
			var model_reference := get_selected_model_reference()
			# warning-ignore:return_value_discarded
			OS.shell_open(model_reference['homepage'])

func _on_model_trigger_pressed() -> void:
	var model_reference := get_selected_model_reference()
	emit_signal("prompt_inject_requested", model_reference['trigger'])


func _on_model_changed(_selected_item = null) -> void:
	var model_reference := get_selected_model_reference()
	if model_reference.empty() and get_selected_model() != "Any model":
		model_info.disabled = true
	else:
		model_info.disabled = false
	if model_reference.get('trigger'):
		model_trigger.disabled = false
	else:
		model_trigger.disabled = true