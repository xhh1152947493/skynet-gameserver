import re

proto_file_content = """
"""

input = "../resources/def/proto/"
output = "../../Servers/game/config/lua/pb_struct.lua"

files = ["db.proto", "game_msg.proto"]


def generate_lua_code(proto_content):
	messages = re.findall(r'message\s+(\w+)\s+{([^}]*)}', proto_content)

	lua_code = "-- Generate by tools, Do not Edit.\nlocal mgr = {}\n\n"

	for message_name, message_content in messages:
		fields = re.findall(r'(\w+)\s+(\w+)\s*=\s*(\d+);\s*(?:\/\/\s*(.*))?', message_content)
		lua_code += f"function mgr.{message_name}()\n"
		lua_code += "\treturn {\n"

		for field_type, field_name, field_number, filed_content in fields:
			if field_type == "int32":
				lua_code += f"\t\t{field_name} = 0,"
			elif field_type == "int64":
				lua_code += f"\t\t{field_name} = 0,"
			elif field_type == "bool":
				lua_code += f"\t\t{field_name} = false,"
			elif field_type == "string":
				lua_code += f'\t\t{field_name} = "",'
			else:
				lua_code += f"\t\t{field_name} = mgr.{field_type}(),"

			if filed_content:
				lua_code += f" -- {filed_content} \n"
			else:
				lua_code += f"\n"

		lua_code += "\t}\n"
		lua_code += "end\n\n"

	lua_code += "return mgr\n"

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
