extends RefCounted
## Lets the final-scoring scene run on its own for testing: a finished random game.


static func play_random() -> void:
	Game.new_game()
	var s = Game.state
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while not s.is_game_over():
		while s.purchases < 2:
			while s.can_take_loan():
				s.take_loan()
			var slots := []
			for i in s.shop.size():
				if s.can_afford(i):
					slots.append(i)
			var empty := []
			for c in s.current_player().cells.size():
				if s.current_player().cells[c] == null:
					empty.append(c)
			s.buy_and_place(slots[rng.randi() % slots.size()], empty[rng.randi() % empty.size()])
		s.end_turn()
