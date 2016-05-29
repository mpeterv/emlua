# emlua

Yet another port of Lua to JavaScript using [Emscripten](http://kripken.github.io/emscripten-site/).
Demo using Lua 5.3: http://mpeterv.github.io/emlua-demo/.

## Features

* Compatible with Lua 5.1, Lua 5.2 and Lua 5.3.
* Provides rather complete bindings for Lua C API, although functions that take or return pointers
  other than `lua_State *` are not very useful. Creating wrappers for them is a goal.
* Allows binding arbitrary JavaScript values to full userdata and tables, so that it's possible to
  write any Lua <-> JS interoperability layer.
* Allows pushing JavaScript functions disguised as Lua C functions.

## Building

* Activate Emscripten tools.
* Optional: `cd` into `lua`, run `make clean`, checkout Lua version to use, `cd` back.
* Run `make`, producing `emlua.js`.

## Testing

There are no real tests yet, but some example code is in `test.js`, run it using Node.js.

## Reference

```js
var emlua = require('./emlua.js'); // Or <script src="emlua.js"></script> in browser
```

### emlua.state()

Creates a new Lua state, equivalent to `luaL_newstate()` C API function. This state
contains C API functions that normally start with `lua_`, as well as constants starting
with `LUA_`. The functions automatically pass the state as the first argument when needed.
Names of functions and constants are lowercased and stripped of `lua_` prefix.

```js
var state = emlua.state();
state.pushstring('Lua version number is ' + state.version_num);
console.log(state.tostring(-1)); // Lua version number is 503
```

### state.aux

Container for C API functions from auxiliary library (their names normally start with `luaL_`),
as well as constants starting with `LUAL_`.

```js
state.aux.openlibs();
state.aux.loadstring('print("Hello emlua!")');
state.call(0, 0); // Hello emlua!
```

### state.util.setjsvalue(index, value)

Associates a JavaScript value with a Lua table or full userdata at an index.
Returns `true` on success and `false` on failure (if the Lua value has wrong type).

### state.util.getjsvalue(index)

Retrieves JavaScript value associated with Lua value at an index.
Returns `undefined` if no value is associated.

### state.util.pushjsclosure(func, upvalues)

Equivalent to `lua_pushcclosure` for JavaScript functions. Pushes a C function
that delegates to `func` when called from Lua. `func` is called with one argument, emlua state
object, which can be used to access arguments and upvalues using C API bindings.

```js
state.pushstring('foo');
state.util.pushjsclosure(function(st) {
  console.log('Argument: ' + st.tostring(1) + ', upvalue: ' + st.tostring(st.upvalueindex(1)));
}, 1)
state.pushstring('bar');
state.call(1, 0); // Argument: bar, upvalue: foo
```

### state.util.pushjsfunction(func)

Equivalent to `lua_pushcfunction` for JavaScript functions.

### state.util.tojsfunction(index)

Retrieves JavaScript function associated with a C function at an index.
Returns `undefined` if the Lua value is not a function or has no corresponding JavaScript function.

### state.util.testudata(index, name)

An implementation of `luaL_testudata` that exists even when using Lua 5.1.

### state.pointer

C pointer of this Lua State as a number.
