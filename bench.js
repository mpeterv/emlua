var emlua = require('./emlua.js');
var fs = require('fs');
var util = require('util');

var state = emlua.state();
state.aux.openlibs();
var src = fs.readFileSync(process.argv[2], {encoding: 'utf8'});
state.aux.loadstring(src);
var start_time = process.hrtime();
state.call(0, 0);
var diff_time = process.hrtime(start_time);
var diff_time_seconds = diff_time[0] + diff_time[1] / Math.pow(10, 9);
console.log(util.format('Completed in %d seconds', diff_time_seconds))
