SHELL=/bin/bash

all:
	@ant

test: test_clean
	@echo 'vunit (python)'
	@./bin/vunit -d build/test -r $$PWD -p plugin/*.vim -t 'test/pass/**/*.vim'
	@echo 'ant (java)'
	@ant test

test_clean:
	@rm -r build/test 2> /dev/null || true

clean:
	@rm -f `find . -name '*.pyc'`
	@rm -r build 2> /dev/null || true
