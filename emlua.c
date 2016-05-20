#include <emscripten.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

struct emlua_constant {
  const char *name;
  int value;
};

static struct emlua_constant emlua_constants[] = {
  {"version_num", LUA_VERSION_NUM},
  {"registryindex", LUA_REGISTRYINDEX},
  {"tnil", LUA_TNIL},
  {"tboolean", LUA_TBOOLEAN},
  {"tnumber", LUA_TNUMBER},
  {"tstring", LUA_TSTRING},
  {"ttable", LUA_TTABLE},
  {"tfunction", LUA_TFUNCTION},
  {"tuserdata", LUA_TUSERDATA},
  {"tlightuserdata", LUA_TLIGHTUSERDATA},
  {"tthread", LUA_TTHREAD},
  {"errerr", LUA_ERRERR},
  {"errfile", LUA_ERRFILE},
  {"errgcmm", LUA_ERRGCMM},
  {"errmem", LUA_ERRMEM},
  {"errrun", LUA_ERRRUN},
  {"errsyntax", LUA_ERRSYNTAX},
  {"hookcall", LUA_HOOKCALL},
  {"hookcount", LUA_HOOKCOUNT},
  {"hookret", LUA_HOOKRET},
  {"hooktailcall", LUA_HOOKTAILCALL},
  {"maskcall", LUA_MASKCALL},
  {"maskcount", LUA_MASKCOUNT},
  {"maskline", LUA_MASKLINE},
  {"maskret", LUA_MASKRET}
};

EMSCRIPTEN_KEEPALIVE
int emlua_getnumconstants(void) {
  return sizeof emlua_constants / sizeof (struct emlua_constant);
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
int emlua_getnumupvalues(lua_State *L) {
  lua_Debug ar;
  lua_getinfo(L, ">u", &ar);
  return ar.nups;
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushcurrentfunction(lua_State *L) {
  lua_Debug ar;
  lua_getstack(L, 0, &ar);
  lua_getinfo(L, "f", &ar);
}

EMSCRIPTEN_KEEPALIVE
lua_State *emlua_newstate(void) {
  return luaL_newstate();
}

EMSCRIPTEN_KEEPALIVE
void *emlua_newuserdata(lua_State *L, size_t size) {
  return lua_newuserdata(L, size);
}

EMSCRIPTEN_KEEPALIVE
int emlua_newmetatable(lua_State *L, const char *tname) {
  return luaL_newmetatable(L, tname);
}

EMSCRIPTEN_KEEPALIVE
void emlua_setmetatable(lua_State *L, int index) {
  lua_setmetatable(L, index);
}

EMSCRIPTEN_KEEPALIVE
const char *emlua_getupvalue(lua_State *L, int funcindex, int n) {
  return lua_getupvalue(L, funcindex, n);
}

EMSCRIPTEN_KEEPALIVE
lua_CFunction emlua_atpanic(lua_State *L, lua_CFunction panicf) {
  return lua_atpanic(L, panicf);
}

EMSCRIPTEN_KEEPALIVE
void emlua_openlibs(lua_State *L) {
  luaL_openlibs(L);
}

EMSCRIPTEN_KEEPALIVE
const void *emlua_topointer(lua_State *L, int index) {
  return lua_topointer(L, index);
}

EMSCRIPTEN_KEEPALIVE
void *emlua_testudata(lua_State *L, int arg, const char *tname) {
  return luaL_testudata(L, arg, tname);
}

EMSCRIPTEN_KEEPALIVE
void *emlua_checkudata(lua_State *L, int arg, const char *tname) {
  return luaL_checkudata(L, arg, tname);
}

EMSCRIPTEN_KEEPALIVE
int emlua_gettop(lua_State *L) {
  return lua_gettop(L);
}

EMSCRIPTEN_KEEPALIVE
void emlua_settop(lua_State *L, int index) {
  lua_settop(L, index);
}

EMSCRIPTEN_KEEPALIVE
void emlua_newtable(lua_State *L) {
  lua_newtable(L);
}

EMSCRIPTEN_KEEPALIVE
void emlua_gettable(lua_State *L, int index) {
  lua_gettable(L, index);
}

EMSCRIPTEN_KEEPALIVE
void emlua_settable(lua_State *L, int index) {
  lua_settable(L, index);
}

EMSCRIPTEN_KEEPALIVE
void emlua_getfield(lua_State *L, int index, const char *k) {
  lua_getfield(L, index, k);
}

EMSCRIPTEN_KEEPALIVE
void emlua_setfield(lua_State *L, int index, const char *k) {
  lua_setfield(L, index, k);
}

EMSCRIPTEN_KEEPALIVE
void emlua_setglobal(lua_State *L, const char *name) {
  lua_setglobal(L, name);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushnil(lua_State *L) {
  return lua_pushnil(L);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushboolean(lua_State *L, int b) {
  return lua_pushboolean(L, b);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushnumber(lua_State *L, lua_Number n) {
  return lua_pushnumber(L, n);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushinteger (lua_State *L, lua_Integer n) {
  return lua_pushinteger(L, n);
}

EMSCRIPTEN_KEEPALIVE
const char *emlua_pushlstring(lua_State *L, const char *s, size_t len) {
  return lua_pushlstring(L, s, len);
}

EMSCRIPTEN_KEEPALIVE
const char *emlua_pushstring(lua_State *L, const char *s) {
  return lua_pushstring(L, s);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushcclosure(lua_State *L, lua_CFunction fn, int n) {
  return lua_pushcclosure(L, fn, n);
}

EMSCRIPTEN_KEEPALIVE
int emlua_pushthread(lua_State *L) {
  return lua_pushthread(L);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushvalue(lua_State *L, int index) {
  lua_pushvalue(L, index);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pushglobaltable(lua_State *L) {
  lua_pushglobaltable(L);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isnone(lua_State *L, int index) {
  return lua_isnone(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isnil(lua_State *L, int index) {
  return lua_isnil(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isnoneornil(lua_State *L, int index) {
  return lua_isnoneornil(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isboolean(lua_State *L, int index) {
  return lua_isboolean(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isnumber(lua_State *L, int index) {
  return lua_isnumber(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isstring(lua_State *L, int index) {
  return lua_isstring(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_istable(lua_State *L, int index) {
  return lua_istable(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isfunction(lua_State *L, int index) {
  return lua_isfunction(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_iscfunction (lua_State *L, int index) {
  return lua_iscfunction(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isuserdata(lua_State *L, int index) {
  return lua_isuserdata(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_islightuserdata(lua_State *L, int index) {
  return lua_islightuserdata(L, index);
}

EMSCRIPTEN_KEEPALIVE
int emlua_isthread(lua_State *L, int index) {
  return lua_isthread(L, index);
}

EMSCRIPTEN_KEEPALIVE
const char *emlua_tostring(lua_State *L, int index) {
  return lua_tostring(L, index);
}

EMSCRIPTEN_KEEPALIVE
void emlua_pop(lua_State *L, int n) {
  lua_pop(L, n);
}

EMSCRIPTEN_KEEPALIVE
int emlua_loadstring(lua_State *L, const char *s) {
  return luaL_loadstring(L, s);
}

EMSCRIPTEN_KEEPALIVE
void emlua_call(lua_State *L, int nargs, int nresults) {
  lua_call(L, nargs, nresults);
}

EMSCRIPTEN_KEEPALIVE
int emlua_pcall(lua_State *L, int nargs, int nresults, int msgh) {
  return lua_pcall(L, nargs, nresults, msgh);
}

EMSCRIPTEN_KEEPALIVE
void emlua_close(lua_State *L) {
  lua_close(L);
}
