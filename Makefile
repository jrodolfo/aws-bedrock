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
	bash -n generate-image.sh
	bash -n generate-text.sh
	bash -n tests/test-generate-image.sh
	bash -n tests/test-generate-text.sh

test: check test-image test-text

test-image:
	bash ./tests/test-generate-image.sh

test-text:
	bash ./tests/test-generate-text.sh
