.SUFFIXES:
.PHONY: test format

test:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()" -c qall

format:
	stylua .
