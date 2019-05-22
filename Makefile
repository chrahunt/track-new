.PHONY: all

all:
	mkdir -p build
	cd build && \
		cmake .. -G "Unix Makefiles" -DCMAKE_MODULE_PATH=$$PWD/../.venv/lib/python3.7/site-packages/skbuild/resources/cmake && \
		make
