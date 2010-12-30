SHELL=/bin/bash

all:
	@ant

test: test_clean
	@./bin/vunit -d build/test -t 'test/**/*.vim'

test_clean:
	@rm -r build/test 2> /dev/null || true

clean:
	@rm -f `find . -name '*.pyc'`
	@rm -r build 2> /dev/null || true
