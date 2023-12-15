allow_defined_top = true
unused_args = false
max_line_length = 999

read_globals = {
  string = {fields = {"split", "trim"}},
  table = {fields = {"copy", "getn"}},
}

globals = {
  "minetest", "player_api", "vector", "armor"
}
