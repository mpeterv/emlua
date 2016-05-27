all: emlua.js

emlua_bindings.c:
	./gen_bindings.py

lua/src/liblua.a:
	make -C lua/src liblua.a CC=emcc AR="emar rcu" RANLIB=emranlib

emlua.js: emlua.c emlua_bindings.c lua/src/liblua.a emlua_prefix.js emlua_suffix.js
	emcc -O2 emlua.c lua/src/liblua.a -o emlua.js -I lua/src \
		-s RESERVED_FUNCTION_POINTERS=3 --memory-init-file 0 \
		--pre-js emlua_prefix.js --post-js emlua_suffix.js

clean:
	make -C lua clean
	$(RM) emlua_bindings.c emlua.js

.PHONY: all clean
