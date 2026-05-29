extends Node

func _ready():
	pass
	print("\nTESTE GERAL SAVEMANAGER\n")
	
	print("1. Criar jogador ")
	var id = SaveManager.create_player("Matheus", 1)
	print("Jogador criado com id: ", id)
	

	print("\n 2. Buscar jogador")
	var player = SaveManager.get_player(id)
	print("Nome: ", player["nome"], " | Level: ", player["level"], " | XP: ", player["xp"])
	
	print("\n 3. Missão com 1 estrela ")
	var r1 = SaveManager.complete_mission(id, "bioma1_nivel1", 1)
	print("+", r1["xp_ganho"], " XP | +", r1["moedas_ganhas"], " moedas | Level up: ", r1["level_up"])
	
	print("\n-4. Mesma missão com 3 estrelas ")
	var r2 = SaveManager.complete_mission(id, "bioma1_nivel1", 3)
	print("+", r2["xp_ganho"], " XP | +", r2["moedas_ganhas"], " moedas | Level up: ", r2["level_up"])
	

	print("\n 5. Tentar salvar nota pior (deve ignorar) ")
	SaveManager.save_progress(id, "bioma1_nivel1", 1)
	
	print("\n 6. Comprar item")
	var compra = SaveManager.buy_item(id, "chapeu_astronauta", 10)
	print("Sucesso: ", compra["sucesso"])
	
	print("\n7. Comprar item duplicado (deve bloquear) ")
	var compra2 = SaveManager.buy_item(id, "chapeu_astronauta", 10)
	print("Sucesso: ", compra2["sucesso"], " | Motivo: ", compra2["motivo"])
	
	print("\n 8. Comprar sem moedas suficientes ")
	var compra3 = SaveManager.buy_item(id, "capa_robo", 99999)
	print("Sucesso: ", compra3["sucesso"], " | Motivo: ", compra3["motivo"])
	
	print("\n 9. Inventário")
	var itens = SaveManager.get_inventory(id)
	for item in itens:
		print("Item: ", item["item_id"], " | Equipado: ", item["equipado"])
	
	print("\n 10. Estado final ")
	var final = SaveManager.get_player(id)
	print("Nome: ", final["nome"])
	print("Level: ", final["level"], " | XP: ", final["xp"])
	print("Moedas: ", final["moedas"])
	
	print("\n FIM DO TESTE\n")
