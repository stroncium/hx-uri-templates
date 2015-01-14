all: test

test: test-js

test-js: test-bin/test.js
	node test-bin/test.js

test-bin/test.js: test/Test.hx
	haxe -cp src -cp test -main Test -js test-bin/test.js

.PHONY: all test test-js
.SUFFIXES:
