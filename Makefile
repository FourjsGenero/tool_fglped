FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))

PROGMOD=fglped.42m fglmkper.42m fglped_install.42m

all: $(PROGMOD) $(FORMS)

%.42f: %.per
	fglform -M $<

%.42m: %.4gl
	fglcomp -M $<

clean::
	rm -f *.42?
