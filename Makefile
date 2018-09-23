%.42f: %.per
	fglform -M $<

%.42m: %.4gl
	fglcomp -M $<

FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))
MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))

all: $(MODS) $(FORMS)

fglmkper.42m: fglped_fileutils.42m \
  fglped_utils.42m \
  fglped_schema.42m

fglped.42m: fglped_md_wizard.42m \
  fglped_utils.42m \
  fglped_dialogs.42m \
  fglped_fileutils.42m

fglped_dialogs.42m: fglped_md_filedlg.42m \
  fglped_fileutils.42m

fglped_install.42m: fglped_fileutils.42m

fglped_md_filedlg.42m: fglped_fileutils.42m

fglped_md_wizard.42m: fglped_schema.42m \
  fglped_utils.42m

fglped_schema.42m: fglped_utils.42m

clean::
	rm -f *.42?
