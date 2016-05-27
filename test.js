var emlua = require('./emlua.js');

var state = emlua.state();
state.aux.openlibs();

state.newtable();
state.util.pushjsfunction(function(st) {
  console.log(st.tostring(1));
});
state.setfield(-2, 'log');
state.setglobal('console');

state.aux.loadstring('console.log("Printing with console.log()"); print("Printing with print()");');
state.call(0, 0);

state.util.pushjsfunction(function(st) {
  console.log('Error in Lua caught by pcall error handler:');
  console.log(st.tostring(-1));
  return 1;
})
state.aux.loadstring('print("This error should be caught by pcall error handler."); (nil)();');
state.pcall(0, 0, -2);

state.close();

state = emlua.state();

state.newtable();
state.util.setjsvalue(-1, console);
state.util.getjsvalue(-1).log('Printing with console attached to a Lua table');

function func(st) {
  console.log('LUA_VERSION_NUM = ' + st.tointeger(st.upvalueindex(1)));
  st.pushstring('A string from JS');
  return 1;
}

state.pushinteger(state.version_num);
state.util.pushjsclosure(func, 1);

if (state.util.tojsfunction(-1) !== func) {
  throw new Error('tojsfunction failed');
}

state.call(0, 1);
console.log('Returned from JS function: ' + state.tostring(-1));

state.close();
