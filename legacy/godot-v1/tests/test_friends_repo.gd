extends FriendsRepository
## Repository folosit doar de teste (un prieten fictiv, NU apare în joc).

func is_demo() -> bool:
	return false

func list_friends() -> Array:
	return [{"id": 99, "name": "Test", "levels": {"palat": 4, "obs": 2}, "island": 1, "online": true, "visited_me": true}]

func get_city(_id: int) -> Dictionary:
	return {"name": "Test", "levels": {"palat": 4, "obs": 2}}
