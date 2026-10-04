extends Node
## În fața blocului, după ce te-a adus Head Witch pe mătură (marcajul `marcaj_zbor`, pus în sefa_vrajitoare.gd):
##  - baba nu mai e pe bancă (`baba` dispare), iar autobuzul nu mai vine (vezi sosire_autobuz.gd);
##  - prima dată te trezești: stai întins pe iarbă lângă alee, deschizi ochii (clipești de câteva ori), te uiți
##    puțin la cer și te ridici. Apoi pune `marcaj_trezit` și sarcina `sarcina_noua`.
## În meniul principal (curtea e doar fundal, fără jucător) nu face nimic.

@export var marcaj_zbor := "a_zburat_acasa"
@export var marcaj_trezit := "s_a_trezit_la_bloc"
@export var sarcina_noua := "Go home and rest."
@export var baba: Node3D
## Unde te trezești și încotro te uiți după ce te ridici (radiani).
@export var loc_trezire := Vector3(-4.6, 0.1, 9.6)
@export var unghi_trezire := -2.4

var _negru: ColorRect


func _ready() -> void:
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator == null or not Stare.e_marcat(marcaj_zbor):
		return
	if is_instance_valid(baba):
		baba.queue_free()
	if Stare.e_marcat(marcaj_trezit):
		return
	await _trezeste(jucator)


func _trezeste(jucator: Node3D) -> void:
	var cap: Node3D = jucator.get_node("Cap")
	var inaltime_ochi := cap.position.y
	jucator.global_position = loc_trezire
	jucator.rotation.y = unghi_trezire
	# întins pe spate: ochii la o palmă de pământ, privirea spre cer, capul căzut într-o parte
	cap.position.y = 0.22
	cap.rotation = Vector3(1.25, 0.0, 0.45)
	Stare.meniu_deschis = true
	var strat := CanvasLayer.new()
	strat.layer = 19  # sub Tranzitie (20): numele locului apare peste ochii închiși
	add_child(strat)
	_negru = ColorRect.new()
	_negru.color = Color.BLACK
	_negru.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strat.add_child(_negru)
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	# clipești: ochii se deschid greu, se închid la loc, apoi rămân deschiși
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_negru, "modulate:a", 0.45, 0.5)
	tween.tween_property(_negru, "modulate:a", 1.0, 0.25)
	tween.tween_interval(0.5)
	tween.tween_property(_negru, "modulate:a", 0.25, 0.4)
	tween.tween_property(_negru, "modulate:a", 0.9, 0.2)
	tween.tween_property(_negru, "modulate:a", 0.0, 0.7)
	await tween.finished
	await get_tree().create_timer(1.0).timeout
	# te ridici: întâi în capul oaselor, apoi în picioare
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cap, "rotation", Vector3(0.1, 0.0, 0.08), 0.9)
	tween.parallel().tween_property(cap, "position:y", 0.75, 0.9)
	tween.tween_property(cap, "position:y", inaltime_ochi, 0.9)
	tween.parallel().tween_property(cap, "rotation", Vector3.ZERO, 0.9)
	await tween.finished
	strat.queue_free()
	Stare.meniu_deschis = false
	Stare.marcheaza(marcaj_trezit)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
