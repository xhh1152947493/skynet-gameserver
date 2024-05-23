import re

proto_file_content = """
"""

input = "../resources/def/proto/"
output = "../../Servers/game/config/lua/pb_enum.lua"

files = ["common_def.proto"]


def generate_lua_code(proto_content):
	messages = re.findall(r'enum\s+(\w+)\s+{([^}]*)}', proto_content)

	lua_code = "-- Generate by tools, Do not Edit.\n\n"

	for message_name, message_content in messages:
		fields = re.findall(r'(\w+)\s*=\s*(\d+);\s*(?:\/\/\s*(.*))?', message_content)
		lua_code += f'_G.{message_name} = {{\n'

		for field_name, field_number, filed_content in fields:
			lua_code += f"\t{field_name} = {field_number},"
			if filed_content:
				lua_code += f" -- {filed_content} \n"
			else:
				lua_code += f"\n"
		lua_code += "}"	

	return lua_code


if __name__ == '__main__':
	for file in files:
		with open(input + file, "r", encoding="utf-8") as f:
			proto_file_content += f.read()
			proto_file_content += "\n"

	result_lua_code = generate_lua_code(proto_file_content)
	print(result_lua_code)
	with open(output, "w", encoding="utf-8") as f:
		f.write(result_lua_code)
