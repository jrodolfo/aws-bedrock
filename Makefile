.PHONY: help check test test-image test-text

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make help        Show this help message' \
		'  make check       Run shell syntax checks' \
		'  make test        Run all tests' \
		'  make test-image  Run image generator tests' \
		'  make test-text   Run text generator tests'

check:
	zsh -n generate-image.sh
	zsh -n generate-text.sh
	zsh -n tests/test-generate-image.sh
	zsh -n tests/test-generate-text.sh

test: check test-image test-text

test-image:
	./tests/test-generate-image.sh

test-text:
	./tests/test-generate-text.sh
