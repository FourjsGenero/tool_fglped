-- reads in a schema file and writes the result to the 
-- global fglped_columns,fglped_tables arrays
IMPORT FGL fglped_utils

PUBLIC DEFINE fglped_columns DYNAMIC ARRAY OF RECORD
  table_name STRING,
  field_name STRING,
  field_type SMALLINT,
  field_length SMALLINT
END RECORD
  
PUBLIC DEFINE fglped_wiz_columns DYNAMIC ARRAY OF RECORD
  table_name STRING,
  field_name STRING
END RECORD

PUBLIC DEFINE fglped_tables DYNAMIC ARRAY OF STRING

FUNCTION fglped_readTables(schemaFile)
  DEFINE schemaFile STRING
  DEFINE ch base.channel
  DEFINE prevTabName STRING
  DEFINE sch RECORD
    tab_name STRING,
    col_name STRING,
    col_type SMALLINT,
    col_length SMALLINT
  END RECORD,
  i SMALLINT

  IF schemaFile IS NULL THEN
    RETURN FALSE
  END IF
  CALL fglped_columns.clear()
  CALL fglped_tables.clear()
  LET ch = base.channel.create()
  WHENEVER ERROR CONTINUE
  CALL ch.openFile(schemaFile, "r")
  WHENEVER ERROR STOP
  IF STATUS!=0 THEN
    CALL myerror( "error: could not open schema file '"||schemaFile||"'")
  END IF
  CALL ch.setdelimiter("^")
  LET i=0
  LET prevTabName=NULL
  WHILE ch.read(sch)
    IF sch.tab_name.getIndexOf("sys",1)==1 THEN
      CONTINUE WHILE
    END IF
    LET i=i+1
    LET fglped_columns[i].table_name=sch.tab_name
    LET fglped_columns[i].field_name=sch.col_name
    LET fglped_columns[i].field_type=sch.col_type
    LET fglped_columns[i].field_length=sch.col_length
    IF prevTabName IS NULL OR sch.tab_name <> prevTabName THEN
      LET fglped_tables[fglped_tables.getLength()+1]=sch.tab_name
      LET prevTabName=sch.tab_name
    END IF
  END WHILE
  CALL ch.close()
  IF fglped_tables.getLength()==0 THEN
    CALL myerror("did not found any tables in fglped_readTables")
  END IF
  RETURN TRUE
END FUNCTION
