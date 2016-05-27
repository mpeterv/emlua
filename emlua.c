#include <emscripten.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

typedef struct emlua_constant {
  const char *name;
  /* For now only numeric constants are supported. */
  long long value;
} emlua_constant;

typedef struct emlua_function {
  /* Function wrapper names are prefixed with "em". */
  const char *name;
  /* Space-separated JS types, as passed to cwrap(). "state" stands for lua_State *. */
  const char *types;
} emlua_function;

#include "emlua_bindings.c"

EMSCRIPTEN_KEEPALIVE
int emlua_getnumconstants(void) {
  return sizeof(emlua_constants) / sizeof(emlua_constant);
}

EMSCRIPTEN_KEEPALIVE
const char *emlua_getconstantname(int index) {
  return emlua_constants[index].name;
}

EMSCRIPTEN_KEEPALIVE
int emlua_getconstantvalue(int index) {
  return emlua_constants[index].value;
}

EMSCRIPTEN_KEEPALIVE
int emlua_getnumfunctions(void) {
  return sizeof(emlua_functions) / sizeof(emlua_function);
}

EMSCRIPTEN_KEEPALIVE
const char *emlua_getfunctionname(int index) {
  return emlua_functions[index].name;
}

EMSCRIPTEN_KEEPALIVE
const char *emlua_getfunctiontypes(int index) {
  return emlua_functions[index].types;
}
