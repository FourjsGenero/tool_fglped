--aborts the program and prints a short error message before
FUNCTION myerror(err)
  DEFINE err STRING
  DISPLAY "ERROR:",err
  EXIT PROGRAM 1
END FUNCTION

--case insensitive version of string.getIndexOf
FUNCTION getIndexOfI(src,pattern,idx)
  DEFINE src,pattern STRING
  DEFINE idx INTEGER
  LET src=src.toLowerCase()
  LET pattern=pattern.toLowerCase()
  RETURN src.getIndexOf(pattern,idx)
END FUNCTION

--checks if the given character is a delimiter character in .per and .4gl
--source code
FUNCTION isDelimiterChar(ch)
  DEFINE ch,delimiters String
  DEFINE idx Integer
  IF ch IS NULL THEN
    RETURN 1
  END IF
  LET delimiters=" \t()[]{}:,;.?!\"'-+/*=&%$^:#~|@\n\r"
  LET idx = delimiters.getIndexOf(ch,1)
  RETURN idx<>0
END FUNCTION
