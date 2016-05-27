#!/usr/bin/env python
import collections
import re

def write_constants(out, lua_version):
    out.write("EMSCRIPTEN_KEEPALIVE\n")
    out.write("emlua_constant emlua_constants[] = {\n")
    
    with open("lists/lua5{}/constants".format(lua_version)) as constants_file:
        for line in constants_file:
            constant_name = line.rstrip()
            out.write('{{"{}", {}}},\n'.format(constant_name, constant_name))

    out.write("};\n")

c_js_types = {
    "void": "null",
    "int": "number",
    "char": "number",
    "long": "number",
    "size_t": "number",
    "char *": "string",
    "lua_State *": "state",
    "lua_Alloc": "number",
    "lua_CFunction": "number",
    "lua_KFunction": "number",
    "lua_Reader": "number",
    "lua_Writer": "number",
    "lua_Hook": "number",
    "lua_Integer": "number",
    "lua_Number": "number",
    "lua_Unsigned": "number",
    "lua_KContext": "number"
}

def get_js_type(c_type):
    if c_type.startswith("const "):
        c_type = c_type[len("const "):]

    if c_type in c_js_types:
        return c_js_types[c_type]

    if c_type.endswith("*"):
        return "number"

class Function(object):
    def __init__(self, function_line):
        line_match = re.match(r"^(.*\W)(\w+)\s*\((.*)\);$", function_line)
        self._ret_type = line_match.group(1).strip()
        js_ret_type = get_js_type(self._ret_type)
        self._name = line_match.group(2)
        self._full_args = line_match.group(3)

        self._js_types = [js_ret_type]
        self._arg_names = []

        for typed_arg in self._full_args.split(", "):
            if typed_arg == "void":
                break
            elif typed_arg == "..." or typed_arg.endswith("[]"):
                self.supported = False
                return

            arg_match = re.match(r"^(.*\W)(\w+)$", typed_arg)
            js_arg_type = get_js_type(arg_match.group(1).strip())
            self._js_types.append(js_arg_type)
            self._arg_names.append(arg_match.group(2))

        self.supported = True

    def append_to_function_list(self, out):
        out.write('{{"{}", "{}"}},\n'.format(self._name, " ".join(self._js_types)))

    def write_emlua_function(self, out):
        out.write("EMSCRIPTEN_KEEPALIVE\n")
        out.write("{} em{}({}) {{\n".format(self._ret_type, self._name, self._full_args))

        if self._ret_type == "void":
            out.write("  {}({});\n".format(self._name, ", ".join(self._arg_names)))
        else:
            out.write("  return {}({});\n".format(self._name, ", ".join(self._arg_names)))

        out.write("}\n")

def write_functions(out, lua_version):
    out.write("emlua_function emlua_functions[] = {\n")
    functions = []

    with open("lists/lua5{}/functions".format(lua_version)) as functions_file:
        for line in functions_file:
            function = Function(line.rstrip())

            if function.supported:
                functions.append(function)
                function.append_to_function_list(out)

    out.write("};\n")

    for function in functions:
        function.write_emlua_function(out)

def write_bindings(out, lua_version):
    out.write("#if LUA_VERSION_NUM == 50{}\n".format(lua_version))
    write_constants(out, lua_version)
    write_functions(out, lua_version)
    out.write("#endif\n")

def main():
    with open("emlua_bindings.c", "w") as out:
        out.write("/* Generated by ./gen_bindings.py. */\n")
        out.write("#include <emscripten.h>\n")
        out.write('#include "lua.h"\n')
        out.write('#include "lualib.h"\n')
        out.write('#include "lauxlib.h"\n')

        for lua_version in ["1", "2", "3"]:
            write_bindings(out, lua_version)

if __name__ == "__main__":
    main()