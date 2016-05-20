var liblua = require('./liblua.js');

var newState = liblua.cwrap('emlua_newstate', 'number', []);
var getNumConstants = liblua.cwrap('emlua_getnumconstants', 'number', []);
var getConstantName = liblua.cwrap('emlua_getconstantname', 'string', ['number']);
var getConstantValue = liblua.cwrap('emlua_getconstantvalue', 'number', ['number']);

var constants = [];
var numConstants = getNumConstants();

for (var i = 0; i < numConstants; i++) {
  constants[getConstantName(i)] = getConstantValue(i);
}

var jsValues = {};
var nextKey = 0;
var jsAnchorsRegistryKey = "JSANCHORS";
var jsAnchorsName = "Javascript value anchors table";
var jsAnchorName = "Javascript value anchor";
var panicFuncRegistryKey = "JSPANICFUNC"

var jsPanicCall = liblua.Runtime.addFunction(function(statePointer) {
  var state = new lua_State(statePointer);
  state.getfield(constants.registryindex, panicFuncRegistryKey);
  var func = state.tojsfunction(-1);
  state.pop(1);
  func(state);
  return 0;
});

var jsFuncCall = liblua.Runtime.addFunction(function(statePointer) {
  var state = new lua_State(statePointer);
  state.internal.pushcurrentfunction();
  var func = state.tojsfunction(-1);
  state.pop(1);
  return func(state);
});

var jsAnchorGC = liblua.Runtime.addFunction(function(statePointer) {
  var state = new lua_State(statePointer);
  var anchorPointer = state.checkudata(1, jsAnchorName);
  var key = liblua.getValue(anchorPointer, 'double');
  delete jsValues[key];
  return 0;
});

function lua_State(statePointer) {
  statePointer = statePointer || newState();

  this.getjsvalue = function(index) {
    var jsValue;
    var origTop = this.gettop();
    this.pushvalue(index);
    this.getfield(constants.registryindex, jsAnchorsRegistryKey);

    if (this.istable(-1) === 1) {
      this.pushvalue(-2);
      this.gettable(-2);
      var anchorPointer = this.testudata(-1, jsAnchorName);

      if (anchorPointer !== 0) {
        var key = liblua.getValue(anchorPointer, 'double');

        if (jsValues.hasOwnProperty(key)) {
          jsValue = jsValues[key];
        }
      }
    }

    this.settop(origTop);
    return jsValue;
  }

  this.setjsvalue = function(index, value) {
    if (this.isuserdata(-1) !== 1 || this.islightuserdata(-1) === 1) {
      return false;
    }

    this.pushvalue(index);
    this.getfield(constants.registryindex, jsAnchorsRegistryKey);

    if (this.istable(-1) === 0) {
      this.pop(1);
      this.newtable();

      if (this.newmetatable(jsAnchorsName) === 1) {
        this.pushstring('k');
        this.setfield(-2, '__mode');
      }

      this.setmetatable(-2);
      this.pushvalue(-1);
      this.setfield(constants.registryindex, jsAnchorsRegistryKey);
    }

    this.pushvalue(-2);
    var anchorPointer = this.newuserdata(8);
    liblua.setValue(anchorPointer, nextKey, 'double');

    if (this.newmetatable(jsAnchorName) === 1) {
      this.internal.pushcclosure(jsAnchorGC, 0);
      this.setfield(-2, '__gc');
    }

    this.setmetatable(-2);
    this.settable(-3);
    jsValues[nextKey] = value;
    nextKey++;
    this.pop(2);
    return true;
  }

  this.pushjsclosure = function(func, n) {
    this.newuserdata(0);
    this.setjsvalue(-1, func);
    this.internal.pushcclosure(jsFuncCall, n + 1);
  }

  this.pushjsfunction = function(func) {
    this.pushjsclosure(func, 0);
  }

  this.tojsfunction = function(index) {
    this.pushvalue(index);
    var upvalues = this.internal.getnumupvalues();
    this.getupvalue(index, upvalues);
    var func = this.getjsvalue(-1);
    this.pop(1);
    return func;
  }

  this.atpanic = function(panicFunc) {
    var oldPanicPointer = this.internal.atpanic(jsPanicCall);
    var oldPanicFunc;

    if (oldPanicPointer === jsPanicCall) {
      this.getfield(constants.registryindex, panicFuncRegistryKey);
      oldPanicFunc = this.tojsfunction(-1);
    }

    this.pushjsfunction(panicFunc);
    this.setfield(constants.registryindex, panicFuncRegistryKey);
    return oldPanicFunc;
  }

  function registerApiFunc(state, name, retType, argTypes) {
    argTypes.unshift('number');
    state[name] = liblua.cwrap('emlua_' + name, retType, argTypes).bind(state, statePointer);
  }

  this.internal = {};
  registerApiFunc(this.internal, 'pushcclosure', null, ['number', 'number']);
  registerApiFunc(this.internal, 'pushcurrentfunction', null, []);
  registerApiFunc(this.internal, 'getnumupvalues', null, []);
  registerApiFunc(this.internal, 'atpanic', 'number', ['number']);

  registerApiFunc(this, 'newuserdata', 'number', ['number']);
  registerApiFunc(this, 'newmetatable', 'number', ['string']);
  registerApiFunc(this, 'setmetatable', null, ['number']);
  registerApiFunc(this, 'openlibs', null, []);
  registerApiFunc(this, 'getupvalue', 'string', ['number', 'number']);
  registerApiFunc(this, 'topointer', 'number', ['number']);
  registerApiFunc(this, 'testudata', 'number', ['number', 'string']);
  registerApiFunc(this, 'checkudata', 'number', ['number', 'string']);
  registerApiFunc(this, 'gettop', 'number', []);
  registerApiFunc(this, 'settop', null, ['number']);
  registerApiFunc(this, 'newtable', null, []);
  registerApiFunc(this, 'gettable', null, ['number']);
  registerApiFunc(this, 'settable', null, ['number']);
  registerApiFunc(this, 'getfield', null, ['number', 'string']);
  registerApiFunc(this, 'setfield', null, ['number', 'string']);
  registerApiFunc(this, 'setglobal', null, ['string']);
  registerApiFunc(this, 'pushnil', null, []);
  registerApiFunc(this, 'pushboolean', null, ['number']);
  registerApiFunc(this, 'pushnumber', null, ['number']);
  registerApiFunc(this, 'pushinteger', null, ['number']);
  registerApiFunc(this, 'pushlstring', 'string', ['string', 'number']);
  registerApiFunc(this, 'pushstring', 'string', ['string']);
  registerApiFunc(this, 'pushthread', 'number', []);
  registerApiFunc(this, 'pushvalue', null, ['number']);
  registerApiFunc(this, 'pushglobaltable', null, []);
  registerApiFunc(this, 'isnone', 'number', ['number']);
  registerApiFunc(this, 'isnil', 'number', ['number']);
  registerApiFunc(this, 'isnoneornil', 'number', ['number']);
  registerApiFunc(this, 'isboolean', 'number', ['number']);
  registerApiFunc(this, 'isnumber', 'number', ['number']);
  registerApiFunc(this, 'isstring', 'number', ['number']);
  registerApiFunc(this, 'istable', 'number', ['number']);
  registerApiFunc(this, 'isfunction', 'number', ['number']);
  registerApiFunc(this, 'iscfunction', 'number', ['number']);
  registerApiFunc(this, 'isuserdata', 'number', ['number']);
  registerApiFunc(this, 'islightuserdata', 'number', ['number']);
  registerApiFunc(this, 'isthread', 'number', ['number']);
  registerApiFunc(this, 'tostring', 'string', ['number']);
  registerApiFunc(this, 'pop', null, ['number']);
  registerApiFunc(this, 'loadstring', 'number', ['string']);
  registerApiFunc(this, 'call', null, ['number', 'number']);
  registerApiFunc(this, 'pcall', 'number', ['number', 'number', 'number']);
  registerApiFunc(this, 'close', null, []);
}

exports.lua_State = lua_State;
exports.constants = constants;
