IMPORT FGL fglped_fileutils
MAIN
  IF file_on_windows() THEN
    IF file_exists("CVS") AND file_is_dir("CVS") AND 
      file_exists(file_join("..",file_join("..",file_join("..","version.h")))) 
        THEN
      --install brute force everything under windows because our fglped.bat
      --isn't as clever as on UNIX
      CALL myrun("copy /Y fglped*.* %FGLDIR%\\demo\\Tools\\fglped")
      CALL myrun("copy /Y Makefile %FGLDIR%\\demo\\Tools\\fglped")
    END IF
    CALL myrun("copy /Y fglped.bat %FGLDIR%\\bin")
  ELSE
    CALL myrun("cp fglped.sh $FGLDIR/bin/fglped;chmod 755 $FGLDIR/bin/fglped")
  END IF
END MAIN

FUNCTION myrun(cmd)
  DEFINE cmd STRING
  DEFINE code INT
  RUN cmd RETURNING code
  IF code THEN
    DISPLAY "FAILED:",cmd
  END IF
END FUNCTION
