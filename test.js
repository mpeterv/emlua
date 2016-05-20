var emlua = require('./emlua.js');
var state = new emlua.lua_State();
state.atpanic(function(st) {
  console.log('Panic: error in Lua:');
  console.log(st.tostring(-1));
  process.exit(1);
});
state.openlibs();
state.newtable();
state.pushjsfunction(function(st) {
  console.log(st.tostring(1));
});
state.setfield(-2, 'log');
state.setglobal('console');
state.loadstring('console.log("Printing with console.log()"); print("Printing with print()");');
state.call(0, 0);
state.pushjsfunction(function(st) {
  console.log('Error in Lua caught by pcall error handler:');
  console.log(st.tostring(-1));
  return 1;
})
state.loadstring('print("This error should be caught by pcall error handler."); (nil)();');
state.pcall(0, 0, -2);
state.loadstring('print("This error should be caught by panic error handler."); (nil)();');
state.call(0, 0);
state.close();
