extends RefCounted
## Lets the final-scoring scene run on its own for testing: a finished random game.


static func play_random() -> void:
	Game.new_game()
	var s = Game.state
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while not s.is_game_over():
		# every turn starts with a card, so the card history has something to show
		if not s.flip_and_draw().is_empty():
			var choice := -1
			if s.card_needs_choice():
				var options := s.card_choice_options()
				for k in options.size():
					if options[k]["available"]:
						choice = k
						break
			s.resolve_turn_card(choice)
		while s.buys_left() > 0:
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
