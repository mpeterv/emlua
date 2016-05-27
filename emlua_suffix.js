var liblua = Module;

var getNumConstants = liblua.cwrap('emlua_getnumconstants', 'number', []);
var getConstantName = liblua.cwrap('emlua_getconstantname', 'string', ['number']);
var getConstantValue = liblua.cwrap('emlua_getconstantvalue', 'number', ['number']);

var constants = {};
var numConstants = getNumConstants();

for (var i = 0; i < numConstants; i++) {
  constants[getConstantName(i)] = getConstantValue(i);
}

var getNumFunctions = liblua.cwrap('emlua_getnumfunctions', 'number', []);
var getFunctionName = liblua.cwrap('emlua_getfunctionname', 'string', ['number']);
var getFunctionTypes = liblua.cwrap('emlua_getfunctiontypes', 'string', ['number']);

var functions = {};
var numFunctions = getNumFunctions();

function toCWrapType(type) {
  if (type === 'state') {
    return 'number';
  } else if (type === 'null') {
    return null;
  } else {
    return type;
  }
}

function createFunctionWrapper(i) {
  var name = getFunctionName(i);
  var types = getFunctionTypes(i).split(' ');
  var retType = types[0];
  var argTypes = types.slice(1);
  var rawWrapper = liblua.cwrap('em' + name, toCWrapType(retType), argTypes.map(toCWrapType))

  function wrapper() {
    var args = Array.prototype.slice.call(arguments);

    for (var i = 0; i < argTypes.length; i++) {
      if (argTypes[i] === 'state' && typeof argTypes[i] !== 'number') {
        args[i] = args[i].pointer;
      }
    }

    var ret = rawWrapper.apply(this, args);

    if (retType === 'state') {
      return new luaState(ret);
    } else {
      return ret;
    }
  }

  wrapper.isStatic = argTypes[0] !== 'state';
  functions[name] = wrapper;
}

for (var i = 0; i < numFunctions; i++) {
  createFunctionWrapper(i);
}

var utilFunctions = {};

/*
* setjsvalue() and getjsvalue() functions allow assigning
* a JS value to a Lua table or userdata and then retrieving it.
* A weak table in registry maps Lua values to userdata containing
* a numeric key. This key is used in JS to map to corresponding JS
* values. The anchor userdata removes that key-value pair when
* it's collected by Lua.
* Keys are integers issued sequentially, so it's possible to run
* out of them. It should be possible to use strings as keys
* as an improvement. Additionally, JS values can be mapped back
* to keys to reuse them.
*/

var jsValues = {};
var nextKey = 0;
var jsAnchorsRegistryKey = "JSANCHORS";
var jsAnchorsName = "Javascript value anchors table";
var jsAnchorName = "Javascript value anchor";

var jsAnchorGC = liblua.Runtime.addFunction(function(statePointer) {
  var state = new luaState(statePointer);
  var anchorPointer = state.aux.checkudata(1, jsAnchorName);
  var key = liblua.getValue(anchorPointer, 'double');
  delete jsValues[key];
  return 0;
});

utilFunctions.setjsvalue = function(state, index, value) {
  var hostType = state.type(-1);

  if (hostType != state.ttable && hostType != state.tuserdata) {
    return false;
  }

  state.aux.checkstack(5, 'setjsvalue');
  state.pushvalue(index);
  state.getfield(state.registryindex, jsAnchorsRegistryKey);

  if (state.istable(-1) === 0) {
    state.pop(1);
    state.newtable();

    if (state.aux.newmetatable(jsAnchorsName) === 1) {
      state.pushstring('k');
      state.setfield(-2, '__mode');
    }

    state.setmetatable(-2);
    state.pushvalue(-1);
    state.setfield(state.registryindex, jsAnchorsRegistryKey);
  }

  state.pushvalue(-2);
  var anchorPointer = state.newuserdata(8);
  liblua.setValue(anchorPointer, nextKey, 'double');

  if (state.aux.newmetatable(jsAnchorName) === 1) {
    state.pushcfunction(jsAnchorGC);
    state.setfield(-2, '__gc');
  }

  state.setmetatable(-2);
  state.settable(-3);
  jsValues[nextKey] = value;
  nextKey++;
  state.pop(2);
  return true;
}

utilFunctions.getjsvalue = function(state, index) {
  var jsValue;
  var origTop = state.gettop();
  state.aux.checkstack(3, "getjsvalue");
  state.pushvalue(index);
  state.getfield(state.registryindex, jsAnchorsRegistryKey);

  if (state.istable(-1) === 1) {
    state.pushvalue(-2);
    state.gettable(-2);
    var anchorPointer = state.util.testudata(-1, jsAnchorName);

    if (anchorPointer !== 0) {
      var key = liblua.getValue(anchorPointer, 'double');

      if (jsValues.hasOwnProperty(key)) {
        jsValue = jsValues[key];
      }
    }
  }

  state.settop(origTop);
  return jsValue;
}

/*
* pushjsclosure() and pushjsfunction() functions allow
* pushing a JS callable to Lua stack. It appears as a C function
* from Lua. When it's called, a wrapper calls associated JS function
* passing state object as the only argument. It can retrieve
* arguments and upvalues using regular C API.
* Because of Emscripten limitations it's impossible to convert arbitrary JS
* functions to C pointers (space must be reserved during compilation).
* Therefore, a wrapper is used instead, with JS function associated
* to a userdata upvalue. To ensure that JS function can access exactly
* its upvalues, the outer wrapper has to call another wrapper, which has
* the upvalues. This inner wrapper is another upvalue of the outer wrapper,
* and takes userdata with JS function as an extra argument.
* tojsfunction() function retrieves JS function corresponding to Lua C function
* at an index.
*/

var jsFuncName = "Javascript function proxy";

var jsFuncOuterWrapper = liblua.Runtime.addFunction(function(statePointer) {
  var state = new luaState(statePointer);
  var numArgs = state.gettop();
  state.pushvalue(state.upvalueindex(1));
  state.insert(1);
  state.pushvalue(state.upvalueindex(2));
  state.call(numArgs + 1, state.multret);
  return state.gettop();
});

var jsFuncInnerWrapper = liblua.Runtime.addFunction(function(statePointer) {
  var state = new luaState(statePointer);
  var jsFunc = state.util.getjsvalue(-1);
  state.pop(1);
  return jsFunc(state);
});

utilFunctions.pushjsclosure = function(state, func, upvalues) {
  state.aux.checkstack(3, 'pushjsclosure');
  state.pushcclosure(jsFuncInnerWrapper, upvalues);
  state.newuserdata(0);
  state.aux.newmetatable(jsFuncName);
  state.setmetatable(-2);
  state.util.setjsvalue(-1, func);
  state.pushcclosure(jsFuncOuterWrapper, 2);
}

utilFunctions.pushjsfunction = function(state, func) {
  state.util.pushjsclosure(func, 0);
}

utilFunctions.tojsfunction = function(state, index) {
  if (state.iscfunction(index) === 0) {
    return;
  }

  var origTop = state.gettop();
  state.aux.checkstack(1, 'tojsfunction');
  state.getupvalue(index, 2);

  if (state.gettop() === origTop) {
    return;
  }

  var jsValue;

  if (state.util.testudata(-1, jsFuncName) !== 0) {
    jsValue = state.util.getjsvalue(-1);
  }

  state.pop(1);
  return jsValue;
}

utilFunctions.testudata = function(state, index, name) {
  var userdataPointer = state.touserdata(index);

  if (userdataPointer !== 0) {
    state.aux.checkstack(2, 'testudata');

    if (state.getmetatable(index) === 1) {
      state.aux.getmetatable(name);

      if (state.rawequal(-1, -2) === 0) {
        userdataPointer = 0;
      }

      state.pop(2);
      return userdataPointer;
    }
  }

  return 0;
}

function storeBinding(base, name, value) {
  name = name.toLowerCase();

  if (name.startsWith('lual_')) {
    name = name.slice('lual_'.length);
    base = base.aux;
  } else {
    name = name.slice('lua_'.length);
  }

  base[name] = value;
}

function luaState(statePointer) {
  this.pointer = statePointer;
  this.aux = {};
  this.util = {};

  var constantNames = Object.keys(constants);

  for (var i = 0; i < constantNames.length; i++) {
    var name = constantNames[i];
    var value = constants[name];
    storeBinding(this, name, value);
  }

  var functionNames = Object.keys(functions);

  for (var i = 0; i < functionNames.length; i++) {
    var name = functionNames[i];
    var wrapper = functions[name];

    if (!wrapper.isStatic) {
      wrapper = wrapper.bind(this, this);
    }

    storeBinding(this, name, wrapper);
  }

  var utilFunctionNames = Object.keys(utilFunctions);

  for (var i = 0; i < utilFunctionNames.length; i++) {
    var name = utilFunctionNames[i];
    this.util[name] = utilFunctions[name].bind(this, this);
  }
}

emlua.state = functions.luaL_newstate;
emlua.constants = constants;
emlua.functions = functions;
emlua.emscripten = liblua;

if (typeof module !== 'undefined' && module.exports) {
  module.exports = emlua;
}

})();
