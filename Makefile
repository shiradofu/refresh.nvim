.PHONY: $(shell egrep -o ^[a-zA-Z_-]+: $(MAKEFILE_LIST) | sed 's/://')

TEMPFILE = .test_output.tmp

nvim: deps
	@nvim --headless --noplugin -u tests/init.vim -c "PlenaryBustedDirectory tests" -c 'q' | tee $(TEMPFILE)
	@# Update exit status to refllect test results
	@FAILED=$$(tail -n 1 $(TEMPFILE) | grep 'Tests Failed'); rm -f $(TEMPFILE); [ -z "$$FAILED" ]

deps:
	@mkdir -p vendor
ifeq (,$(wildcard ./vendor/plenary.nvim))
	git clone https://github.com/nvim-lua/plenary.nvim.git ./vendor/plenary.nvim
endif

server:
	@./tests/test.sh
