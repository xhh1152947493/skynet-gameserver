import re

input = "../resources/def/toml/msg_type.toml"
output = "../../Servers/game/config/lua/message_def.lua"

pattern_outer = re.compile(r'{\s*begin\s*=\s*(\d+),\s*fields\s*=\s*\[([\s\S]*?)\]\s*}', re.MULTILINE)
pattern_inner = re.compile(r'{\s*name\s*=\s*"([^"]+)",\s*msg\s*=\s*"([^"]+)",\s*comment\s*=\s*"([^"]+)"\s*}')

content = """
-- Generate by tools, Do not Edit.

_G.MESSAGE_TYPE = {
%s
}

"""

if __name__ == '__main__':
	with open(input, "r", encoding="utf-8") as f:
		text = f.read()

	tmps = ""
	matches = pattern_outer.findall(text)
	for match in matches:
		begin, fields = match[0], match[1]
		matches_inner = pattern_inner.findall(fields)
		i = 0
		for match_inner in matches_inner:
			name = match_inner[0]
			msg = match_inner[1]
			comment = match_inner[2]
			tmps += f'\t{name} = {{ID = {int(begin) + i}, Msg = "{msg}"}}, -- {comment}\n'
			i += 1
		tmps += "\n"

	with open(output, "w", encoding="utf-8") as f:
		s = content % tmps
		f.write(s)
		print(s)
