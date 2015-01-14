all: test

test: test-js

test-js: test-bin/test.js
	node test-bin/test.js

test-bin/test.js: test/Test.hx src
	haxe -cp src -cp test -main Test -js test-bin/test.js

src: src/*

.PHONY: all test test-js src
.SUFFIXES:
