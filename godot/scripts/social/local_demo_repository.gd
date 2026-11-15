class_name LocalDemoRepository
extends FriendsRepository
## Implementarea locală, fără server: nicio bulă nu e un jucător real.
## Ecranul arată doar sloturi goale „Invită un prieten", marcate DEMO.


func is_demo() -> bool:
	return true
