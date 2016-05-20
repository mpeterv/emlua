all: liblua.js

liblua.a:
	make -C lua/src liblua.a CC=emcc AR="emar rcu" RANLIB=emranlib
	mv lua/src/liblua.a liblua.a

liblua.js: emlua.c liblua.a
	emcc -O2 emlua.c liblua.a -o liblua.js -I lua/src -s RESERVED_FUNCTION_POINTERS=3

clean:
	make -C lua clean
	$(RM) liblua.a liblua.js liblua.js.mem

.PHONY: all clean
