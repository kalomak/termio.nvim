.SUFFIXES:
.PHONY: deps test test-bash test-fish doc-deps documentation format

deps:
	@mkdir -p deps
	@[ -d deps/mini.test ] || git clone --depth 1 https://github.com/nvim-mini/mini.test deps/mini.test

test: deps
	XDG_STATE_HOME="$(CURDIR)/tmp/test-state" TERMIO_TEST_BACKEND="$(BACKEND)" nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()" -c qall

test-bash: deps
	XDG_STATE_HOME="$(CURDIR)/tmp/test-state" TERMIO_TEST_BACKEND="$(BACKEND)" TERMIO_TEST_SHELL=bash nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()" -c qall

test-fish: deps
	XDG_STATE_HOME="$(CURDIR)/tmp/test-state" TERMIO_TEST_BACKEND="$(BACKEND)" TERMIO_TEST_SHELL=fish nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()" -c qall

doc-deps:
	@mkdir -p deps
	@[ -d deps/mini.doc ] || git clone --depth 1 https://github.com/nvim-mini/mini.doc deps/mini.doc

documentation: doc-deps
	nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "set rtp+=deps/mini.doc" \
		-c "lua require('mini.doc').setup()" \
		-c "lua require('mini.doc').generate({ 'lua/termio/init.lua', 'lua/termio/api.lua', 'lua/termio/config.lua' }, 'doc/termio.txt')" \
		-c "qa!"

format:
	stylua .
