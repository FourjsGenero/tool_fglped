%.42f: %.per
	fglform -M $<

%.42m: %.4gl
	fglcomp -M $<

FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))
MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))

all: $(MODS) $(FORMS)


clean::
	rm -f *.42?
