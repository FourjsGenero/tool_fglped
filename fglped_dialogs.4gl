IMPORT os
IMPORT FGL fglped_md_filedlg
IMPORT FGL fglped_fileutils

FUNCTION fglped_filedlg()
  DEFINE fname STRING
  DEFINE r1 FILEDLG_RECORD
  IF _isLocal() THEN
    CALL ui.interface.frontCall("standard","openfile",[os.Path.pwd(),"Form Files","*.per","Please choose a form"],[fname])
  ELSE
    LET r1.title="Please choose a form"
    LET r1.types[1].description="Form files (*.per)"
    LET r1.types[1].suffixes="*.per"
    LET r1.types[2].description="All files (*.*)"
    LET r1.types[2].suffixes="*.*"
    LET fname= filedlg_open(r1.*)
  END IF
  RETURN fname
END FUNCTION

FUNCTION fglped_dirdlg(path)
  DEFINE path STRING
  DEFINE fname STRING
  DEFINE r1 FILEDLG_RECORD
  LET r1.title="Please choose a directory"
  LET r1.defaultpath=path
  LET r1.opt_choose_directory=TRUE
  LET r1.types[1].description="Form files (*.per)"
  LET r1.types[1].suffixes="*.per"
  LET fname= filedlg_open(r1.*)
  RETURN fname
END FUNCTION

FUNCTION fglped_saveasdlg(fname)
  DEFINE fname STRING
  DEFINE r1 FILEDLG_RECORD
  DEFINE ext STRING
  LET r1.title="Save as"
  LET r1.defaultfilename=fname
  LET r1.types[1].description="Form files (*.per)"
  LET r1.types[1].suffixes="*.per"
  LET r1.types[2].description="All files (*.*)"
  LET r1.types[2].suffixes="*.*"
  LET fname= filedlg_save(r1.*)
  IF fname IS NULL THEN
    RETURN NULL
  END IF
  IF (ext:=file_extension(fname)) IS NULL OR ext<>".per" THEN
    LET fname=fname,".per"
  END IF
  RETURN fname
END FUNCTION

FUNCTION fglped_schemadlg(schemaFile)
  DEFINE schemaFile STRING
  DEFINE fname STRING
  DEFINE r1 FILEDLG_RECORD
  LET r1.defaultfilename=schemaFile
  LET r1.title="Please choose a schema file"
  LET r1.types[1].description="Form files (*.sch)"
  LET r1.types[1].suffixes="*.sch"
  LET r1.types[2].description="All files (*.*)"
  LET r1.types[2].suffixes="*.*"
  LET fname= filedlg_open(r1.*)
  RETURN fname
END FUNCTION

