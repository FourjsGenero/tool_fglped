GLOBALS
DEFINE fglped_columns DYNAMIC ARRAY OF RECORD
  table_name STRING,
  field_name STRING,
  field_type SMALLINT,
  field_length SMALLINT
END RECORD
  
DEFINE fglped_wiz_columns DYNAMIC ARRAY OF RECORD
  table_name STRING,
  field_name STRING
END RECORD

DEFINE fglped_tables DYNAMIC ARRAY OF STRING
END GLOBALS
