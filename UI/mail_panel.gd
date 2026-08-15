extends Control
class_name MailPanel
## 信件面板：收到信自动弹出，点领取收礼物

@onready var text_label: Label = $Panel/TextLabel

func _ready() -> void:
	$Panel/Claim.pressed.connect(_on_claim_pressed)

func show_mail(mail: Dictionary) -> void:
	text_label.text = mail.get("text", "一封空信")
	visible = true

func _on_claim_pressed() -> void:
	MailSystem.claim()
	visible = false
	Global.show_message("信件已领取")
