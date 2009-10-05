builddir = .build

VIMBALL = $(builddir)/buffer-select.vba

FILES = \
	plugin/now/buffer-select.vim

MANIFEST = $(builddir)/Manifest

.PHONY: build clean install package

build: $(builddir) $(VIMBALL)

clean:
	-rm $(VIMBALL) $(VIMBALL).gz $(MANIFEST) 2> /dev/null
	-rmdir $(builddir) 2> /dev/null

install: build
	ex -N --cmd 'set eventignore=all' -c 'so %' -c 'quit!' $(VIMBALL)

package: $(VIMBALL).gz

$(builddir):
	mkdir $@

%.vba: $(MANIFEST) $(FILES)
	ex -N -c "%MkVimball! $@ ." -c 'quit!' $<

%.gz: %
	gzip -c $< > $@

$(MANIFEST): Makefile
	for f in $(FILES); do echo $$f; done > $@
