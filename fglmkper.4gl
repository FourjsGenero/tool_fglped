IMPORT FGL fglped_schema
IMPORT FGL fglped_fileutils
IMPORT FGL fglped_utils
IMPORT FGL fglped_schema
--
-- current variables in use

-- FGLT_DATABASE
-- FGLT_TABLES
-- FGLT_DETAIL_LAYOUT
-- FGLT_TABLE_LAYOUT
-- FGLT_DETAIL_ATTRIBUTES
-- FGLT_TABLE_ATTRIBUTES
-- FGLT_SCREEN_RECORD

CONSTANT C_NUM_ROWS_TABLE = 10
CONSTANT C_MAX_TABLE_COLUMN_WIDTH = 20
CONSTANT C_MAX_LABEL_WIDTH = 20
CONSTANT C_MAX_COLUMN_WIDTH = 40

CONSTANT DATATYPE_CHAR       =      0
CONSTANT DATATYPE_SMALLINT   =      1
CONSTANT DATATYPE_INT        =      2
CONSTANT DATATYPE_FLOAT      =      3
CONSTANT DATATYPE_SMALLFLOAT =      4
CONSTANT DATATYPE_DECIMAL    =      5
CONSTANT DATATYPE_SERIAL     =      6
CONSTANT DATATYPE_DATE       =      7
CONSTANT DATATYPE_MONEY      =      8
CONSTANT DATATYPE_DATETIME   =     10
--CONSTANT DATATYPE_BYTE      =     11
--CONSTANT DATATYPE_TEXT       =     12
CONSTANT DATATYPE_VARCHAR    =     13
CONSTANT DATATYPE_INTERVAL   =     14
--CONSTANT DATATYPE_NCHAR      =     15
--CONSTANT DATATYPE_END        =     15

DEFINE replace_errstr STRING
DEFINE match DYNAMIC ARRAY OF RECORD
  t CHAR,
  match STRING,
  replace STRING
END RECORD
DEFINE minWidth DYNAMIC ARRAY OF RECORD
  t CHAR,
  match STRING,
  width SMALLINT
END RECORD
DEFINE maxWidth DYNAMIC ARRAY OF RECORD
  t CHAR,
  match STRING,
  width SMALLINT
END RECORD


DEFINE ident ARRAY[3] OF RECORD
  c CHAR,
  nb SMALLINT
END RECORD

DEFINE col DYNAMIC ARRAY OF RECORD
  table_name STRING,            -- customer
  field_name STRING,            -- customer_name
  field_type SMALLINT,          -- 0
  field_strtype STRING,         -- CHAR(30)
  field_length SMALLINT,        -- 80
  field_width SMALLINT,         -- 10   the physical width of a columns
  table, detail RECORD
    field_columnWidth SMALLINT,
    field_visibleWidth SMALLINT,
    field_label STRING,           -- Name
    field_ident STRING,           -- f000
    field_placeholder STRING,     -- [f000      ]
    field_attribute STRING      -- f000 = customer.customer_name ....
  END RECORD
END RECORD

DEFINE columns DYNAMIC ARRAY OF RECORD
  star SMALLINT,
  table STRING,
  column STRING,
  found SMALLINT
END RECORD

DEFINE template STRING
DEFINE countNumRows SMALLINT


DEFINE fgltDatabase STRING
DEFINE fgltTables STRING
DEFINE fgltDetailLayout STRING
DEFINE fgltTableLayout STRING
DEFINE fgltDetailAttributes STRING
DEFINE fgltTableAttributes STRING
DEFINE fgltScreenRecord STRING

DEFINE outfile STRING


MAIN
  DEFINE i SMALLINT
  DEFINE resource STRING

  IF num_args()=0 THEN
    CALL usage()
  END IF

  CALL fglmkper_init()

  LET i=1
  WHILE i<= num_args()
    IF arg_val(i)="-s" THEN
      LET fgltDatabase=arg_val(i+1)
      LET i=i+2
    ELSE
      IF arg_val(i)="-t" THEN
        LET template=arg_val(i+1)
        LET i=i+2
      ELSE
        IF arg_val(i)="-c" THEN
          LET countNumRows=arg_val(i+1)
          LET i=i+2
        ELSE
          IF arg_val(i)="-o" THEN
            LET outfile=arg_val(i+1)
            LET i=i+2
          ELSE
            IF arg_val(i)="-r" THEN
              LET resource=arg_val(i+1)
              LET i=i+2
            ELSE
              LET i=i+1
            END IF
          END IF
        END IF
      END IF
    END IF
  END WHILE
  LET i=1
  WHILE i<= num_args()
    IF arg_val(i) MATCHES "-*" THEN
      LET i=i+2
    ELSE
      IF NOT extractColumns(arg_val(i)) THEN
        DISPLAY "error: could not parse columns"
        CALL usage()
      END IF
      LET i=i+1
    END IF
  END WHILE
  IF columns.getLength()=0 THEN
    DISPLAY "error: no columns specified"
    CALL usage()
  END IF

  IF fgltDatabase IS NULL THEN 
    CALL displayError( "error: database name is empty") 
  END IF
  IF template IS NULL THEN 
    LET template="detail.tpl"
  END IF
  CALL res_init(resource)

  IF NOT generateForm() THEN
    CALL displayError( "error: generation of form failed" )
  END IF
END MAIN

FUNCTION generateForm()
  DEFINE schemaFile STRING
  DEFINE i,j SMALLINT
  DEFINE table_1Width, detail_1Width SMALLINT
  DEFINE table_2Width, detail_2Width SMALLINT
  DEFINE detailMinWidth, tableMinWidth SMALLINT

  -- read the schema file and fill table array
  LET schemaFile=getSchema()
  IF schemaFile IS NULL THEN
    RETURN FALSE
  END IF
  IF NOT fglped_readTables(schemaFile) THEN
    RETURN FALSE
  END IF
  CALL col.clear()
  LET j=1
  FOR i=1 TO fglped_columns.getLength()
    IF getColumnsElement(fglped_columns[i].table_name, fglped_columns[i].field_name) THEN
      INITIALIZE col[j].* TO NULL
      LET col[j].table_name   = fglped_columns[i].table_name
      LET col[j].field_name   = fglped_columns[i].field_name
      LET col[j].field_type   = fglped_columns[i].field_type
      LET col[j].field_length = fglped_columns[i].field_length
      LET j=j+1
    END IF
  END FOR
  FOR i=1 TO columns.getLength()
    IF NOT columns[i].found THEN
      CALL displayError( "error: column '"||columns[i].table||"."||columns[i].column|| "' does not exist in schema '"||fgltDatabase||"'")
    END IF
  END FOR

  FOR i=1 TO col.getLength()

    -- get string representation of the datatype
    LET col[i].field_strtype=col[i].table_name||"."||col[i].field_name||" "||str_type(col[i].field_type, col[i].field_length)

    -- get the physical width
    CALL get_len(col[i].field_type, col[i].field_length) 
        RETURNING col[i].field_width, col[i].field_strType

    -- get visible width
    LET col[i].table.field_visibleWidth=col[i].field_width
    IF col[i].table.field_visibleWidth > C_MAX_TABLE_COLUMN_WIDTH THEN
      LET col[i].table.field_visibleWidth=C_MAX_TABLE_COLUMN_WIDTH
    END IF

    LET col[i].detail.field_visibleWidth=col[i].field_width
    IF col[i].detail.field_visibleWidth > C_MAX_COLUMN_WIDTH THEN
      LET col[i].detail.field_visibleWidth = C_MAX_COLUMN_WIDTH 
    END IF

    -- get labels
    LET col[i].detail.field_label=getLabel(col[i].field_width, C_MAX_LABEL_WIDTH, col[i].table_name, col[i].field_name)
    LET col[i].table.field_label=getLabel(col[i].field_width, C_MAX_TABLE_COLUMN_WIDTH, col[i].table_name, col[i].field_name)

    -- count 1 character width fields ( Just in case not enough a-z identifiers )
    CASE col[i].detail.field_visibleWidth
      WHEN 1
        LET detail_1Width=detail_1Width+1
      WHEN 2
        LET detail_2Width=detail_2Width+1
    END CASE
    CASE col[i].table.field_visibleWidth
      WHEN 1
        LET table_1Width=table_1Width+1
      WHEN 2
        LET table_2Width=table_2Width+1
    END CASE
  END FOR

  -- check if we have enough identifiers
  IF detail_1Width>=26 THEN   -- overflow on [a]
    LET detailMinWidth=2
    LET detail_2Width=detail_2Width+detail_1Width
  END IF
  IF detail_2Width>=936 THEN  -- overflow on [a0] 26 * 36
    LET detailMinWidth=3
  END IF

  IF table_1Width>=26 THEN   -- overflow on [a]
    LET tableMinWidth=2
    LET table_2Width=table_2Width+table_1Width
  END IF
  IF table_2Width>=936 THEN  -- overflow on [a0] 26 * 36
    LET tableMinWidth=3
  END IF

  --identifiers and placeholder detail
  CALL initIdent()
  FOR i=1 TO col.getLength()

    -- have to resize field, if not enough 1 width identifiers
    IF col[i].detail.field_visibleWidth < detailMinWidth THEN
      LET col[i].detail.field_visibleWidth = detailMinWidth
    END IF

    CALL getIdent(col[i].detail.field_visibleWidth)
                 RETURNING col[i].detail.field_ident
    CALL getPlaceholder(col[i].detail.field_visibleWidth, col[i].detail.field_ident)
                 RETURNING col[i].detail.field_placeholder

  END FOR

  --identifiers and placeholder table
  CALL initIdent()
  FOR i=1 TO col.getLength()
    IF col[i].table.field_visibleWidth < tableMinWidth THEN
      LET col[i].table.field_visibleWidth = tableMinWidth
    END IF

    CALL getIdent(col[i].table.field_visibleWidth)
                 RETURNING col[i].table.field_ident
    CALL getPlaceholder(col[i].table.field_visibleWidth, col[i].table.field_ident)
                 RETURNING col[i].table.field_placeholder
  END FOR

  IF NOT createLayout() THEN
    DISPLAY "DBG: createLayout"
    RETURN FALSE
  END IF
  IF NOT createAttributes() THEN
    DISPLAY "DBG: createAttributes"
    RETURN FALSE
  END IF
  IF NOT write4gl() THEN
    RETURN FALSE
  ELSE
    RETURN TRUE
  END IF
END FUNCTION

FUNCTION write4gl()
  DEFINE infile STRING
  DEFINE buffer DYNAMIC ARRAY OF STRING
  DEFINE i SMALLINT
  DEFINE resdir STRING

  LET resdir=file_join(base.Application.getProgramDir(),"resource")
  LET infile=file_join(resdir,template)
  IF NOT replace_readbuffer(infile,buffer) THEN
    DISPLAY replace_geterr()
    RETURN FALSE
  END IF
  CALL replace_string_in_buffer("FGLT_DATABASE", fgltDatabase, buffer, TRUE, TRUE)
  CALL replace_string_in_buffer("FGLT_TABLES", fgltTables, buffer, TRUE, TRUE)
  CALL replace_string_in_buffer("FGLT_DETAIL_LAYOUT", fgltDetailLayout, buffer, TRUE, TRUE)
  CALL replace_string_in_buffer("FGLT_TABLE_LAYOUT", fgltTableLayout, buffer, TRUE, TRUE)
  CALL replace_string_in_buffer("FGLT_DETAIL_ATTRIBUTES", fgltDetailAttributes, buffer, TRUE, TRUE)
  CALL replace_string_in_buffer("FGLT_TABLE_ATTRIBUTES", fgltTableAttributes, buffer, TRUE, TRUE)
  CALL replace_string_in_buffer("FGLT_SCREEN_RECORD", fgltScreenRecord, buffer, TRUE, TRUE)
  IF outfile IS NOT NULL THEN
    IF NOT replace_writebuffer(buffer,outfile) THEN
      DISPLAY replace_geterr()
      RETURN FALSE
    END IF
  ELSE
    FOR i=1 TO buffer.getLength()
      DISPLAY buffer[i]
    END FOR
    RETURN TRUE
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION initIdent()
  LET ident[1].c="a" LET ident[1].nb=0
  LET ident[2].c="a" LET ident[2].nb=0
  LET ident[3].c="f" LET ident[3].nb=0
END FUNCTION

FUNCTION fglmkper_init()
  LET countNumRows=C_NUM_ROWS_TABLE
END FUNCTION

--
-- load and fill table array
--
FUNCTION readTable()
  DEFINE schemaFile STRING
  DEFINE ch base.channel
  DEFINE sch RECORD
    tab_name STRING,
    col_name STRING,
    col_type SMALLINT,
    col_length SMALLINT
  END RECORD,
  i SMALLINT

  LET schemaFile=getSchema()
  IF schemaFile IS NULL THEN
    CALL displayError( "error: could not find schema file '"||fgltDatabase||"'")
  END IF

  -- read schema file and fill
  CALL col.clear()
  LET ch = base.channel.create()
  WHENEVER ERROR CONTINUE
  CALL ch.openFile(schemaFile, "r")
  WHENEVER ERROR STOP
  IF STATUS!=0 THEN
    CALL displayError( "error: could not open schema file '"||schemaFile||"'")
  END IF
  CALL ch.setdelimiter("^")
  LET i=0
  WHILE ch.read(sch)
    IF getColumnsElement(sch.tab_name, sch.col_name) THEN
      LET i=i+1
      LET col[i].table_name=sch.tab_name
      LET col[i].field_name=sch.col_name
      LET col[i].field_type=sch.col_type
      LET col[i].field_length=sch.col_length

    END IF
  END WHILE
  CALL ch.close()
  FOR i=1 TO columns.getLength()
    IF NOT columns[i].found THEN
      CALL displayError( "error: column '"||columns[i].table||"."||columns[i].column|| "' does not exist in schema '"||fgltDatabase||"'")
      RETURN FALSE
    END IF
  END FOR
  RETURN TRUE
END FUNCTION

FUNCTION getSchema()
  DEFINE fileName STRING
  DEFINE dbpath STRING
  DEFINE a DYNAMIC ARRAY OF STRING
  DEFINE i SMALLINT

  -- try in current dir
  LET fileName=fgltDatabase, ".sch"
  IF NOT file_exists(fileName) THEN
    -- try in DBPATH
    LET dbpath=fgl_getenv("DBPATH")
    CALL explode(a, dbpath, file_get_pathvar_separator())
    FOR i =1 TO a.getLength()
      LET fileName=file_join(a[i], fgltDatabase||".sch")
      --DISPLAY "DBG trying ", fileName
      IF file_exists(fileName) THEN
        EXIT FOR
      END IF
    END FOR
  END IF

  RETURN fileName
END FUNCTION

FUNCTION explode( a, s, delimiter )
  DEFINE s STRING
  DEFINE delimiter CHAR
  DEFINE a DYNAMIC ARRAY OF STRING
  DEFINE tok base.StringTokenizer
  DEFINE i SMALLINT

  LET tok=base.StringTokenizer.create(s, delimiter)

  LET i=0
  WHILE tok.countTokens() 
    LET i=i+1
    LET a[i]=tok.nextToken()
  END WHILE
END FUNCTION

FUNCTION displayError(s)
  DEFINE s STRING
  DISPLAY s
  EXIT PROGRAM 1
END FUNCTION

{
FUNCTION getColType(col_type, col_length) 
  DEFINE col_type, col_length SMALLINT
  DEFINE field_type STRING
  DEFINE field_num_char SMALLINT

  RETURN field_type, field_num_char
END FUNCTION

FUNCTION getColLength(col_type, col_length)
  DEFINE col_type, col_length SMALLINT
  DEFINE field_length SMALLINT

  RETURN field_length
END FUNCTION
}

FUNCTION createLayout()
  DEFINE i  SMALLINT
  DEFINE detailLabelWidth SMALLINT
  DEFINE detailFieldWidth SMALLINT
  DEFINE header STRING
  DEFINE columnWidth SMALLINT
  DEFINE s STRING


  -- get max width's
  LET detailLabelWidth=0
  LET detailFieldWidth=0
  FOR i=1 TO col.getLength()
    IF col[i].detail.field_label.getLength() > detailLabelWidth THEN
      LET detailLabelWidth = col[i].detail.field_label.getLength()
    END IF
    IF col[i].detail.field_visibleWidth > detailFieldWidth THEN
      LET detailFieldWidth = col[i].detail.field_visibleWidth
    END IF
  END FOR

  -- get detail layout
  FOR i=1 TO col.getLength()
    LET fgltDetailLayout=fgltDetailLayout, col[i].detail.field_label
    LET fgltDetailLayout=fgltDetailLayout, 
          getSpaces(detailLabelWidth-col[i].detail.field_label.getLength()+1)
    LET fgltDetailLayout=fgltDetailLayout, col[i].detail.field_placeholder, "\n"
  END FOR
  --DISPLAY fgltDetailLayout

  -- get table layout
  LET header=" "
  FOR i=1 TO col.getLength()
    IF col[i].table.field_label.getLength() > 
       col[i].table.field_placeholder.getLength() THEN
      LET columnWidth=col[i].table.field_label.getLength()
    ELSE
      LET columnWidth=col[i].table.field_placeholder.getLength()
    END IF
    LET columnWidth=columnWidth+2
    LET header=header, col[i].table.field_label, 
           getSpaces(columnWidth-col[i].table.field_label.getLength())
    LET fgltTableLayout=fgltTableLayout, col[i].table.field_placeholder
    LET fgltTableLayout=fgltTableLayout,
        getSpaces(columnWidth-col[i].table.field_placeholder.getLength())
  END FOR
  LET s= header, "\n"
  FOR i = 1 TO countNumRows
    LET s=s, fgltTableLayout, "\n"
  END FOR
  LET fgltTableLayout=s
  RETURN TRUE
END FUNCTION

FUNCTION createAttributes()
  DEFINE i SMALLINT
  DEFINE s STRING
  DEFINE tmp STRING

  {
  FOR i=2 TO col.getLength()
    LET fgltScreenRecord=fgltScreenRecord, ",\n      ",
          col[i].table_name,".",col[i].field_name
  END FOR
  LET fgltScreenRecord=fgltScreenRecord, "\n"
  }

  LET fgltScreenRecord= columns[1].table,".",columns[1].column
  FOR i=1 TO columns.getLength()
    IF i>1 THEN
      LET fgltScreenRecord=fgltScreenRecord, ", \n",
            columns[i].table,".",columns[i].column
    END IF
    IF tmp IS NULL OR tmp!= columns[i].table THEN
      LET tmp=columns[i].table
      LET fgltTables=fgltTables,"\n",tmp
    END IF
  END FOR

  LET fgltTableAttributes=NULL
  LET fgltDetailAttributes=NULL

  FOR i=1 TO col.getLength()
    -- detail
    LET tmp=col[i].table_name,".",col[i].field_name, " ", col[i].field_strType

    LET s=col[i].detail.field_ident,"=",col[i].table_name,".",col[i].field_name

     -- get maxWidth from resource
    LET col[i].detail.field_visibleWidth= maxWidth("D", s, col[i].field_width)
    LET col[i].table.field_visibleWidth= maxWidth("T", s, col[i].field_width)

     -- get attributes from resource
    LET fgltDetailAttributes=fgltDetailAttributes, attributeReplace("D", tmp, s)

    LET s=col[i].table.field_ident,"=",col[i].table_name,".",col[i].field_name

     -- get attributes from resource
    LET fgltTableAttributes=fgltTableAttributes, attributeReplace("T", tmp, s)

    -- append a semicolon if everything is done
    LET fgltTableAttributes=fgltTableAttributes,";\n"
    LET fgltDetailAttributes=fgltDetailAttributes,";\n"
  END FOR

  RETURN TRUE
END FUNCTION

FUNCTION getPlaceholder(width, ident)
  DEFINE width SMALLINT
  DEFINE ident STRING
  DEFINE placeholder STRING
  DEFINE i SMALLINT

  LET placeholder="[", ident
  FOR i=1 TO width-ident.getLength()
    LET placeholder=placeholder," "
  END FOR
  LET placeholder=placeholder,"]"
  RETURN placeholder
END FUNCTION

FUNCTION getIdent(width)
  DEFINE width SMALLINT
  DEFINE is STRING

  CASE width
    WHEN 1
      LET is=ident[1].c
      LET ident[1].c=ASCII(fgl_keyval(ident[1].c)+1)
      RETURN is
    WHEN 2
      IF ident[2].nb>=10 THEN
        LET ident[2].nb=0
        LET ident[2].c=ASCII(fgl_keyval(ident[2].c)+1)
      END IF
      LET is=ident[2].c, ident[2].nb USING "&"
      LET ident[2].nb=ident[2].nb+1
      RETURN is
    WHEN 3
      IF ident[3].nb>=10 THEN
        LET ident[3].nb=0
        LET ident[3].c=ASCII(fgl_keyval(ident[3].c)+1)
      END IF
      LET is=ident[3].c, ident[3].nb USING "&&"
      LET ident[3].nb=ident[3].nb+1
      RETURN is
  OTHERWISE
      IF ident[3].nb>=100 THEN
        LET ident[3].nb=0
        LET ident[3].c=ASCII(fgl_keyval(ident[3].c)+1)
      END IF
      LET is=ident[3].c, ident[3].nb USING "&&&"
      LET ident[3].nb=ident[3].nb+1
      RETURN is
  END CASE
END FUNCTION

FUNCTION get_len(type, len)
  DEFINE type, len, onlyType SMALLINT
  DEFINE strtype STRING

  LET onlyType=( type MOD 256)

  IF onlytype = DATATYPE_CHAR THEN  -- CHAR 
    GOTO return_get_len
  END IF

  IF onlytype=DATATYPE_INT OR onlytype = DATATYPE_SERIAL THEN    -- INT SERIAL
    LET len=11
    GOTO return_get_len
  END IF
  IF onlytype = DATATYPE_SMALLINT THEN                  -- SMALLINT
    LET len= 6
    GOTO return_get_len
  END IF
  IF onlytype=DATATYPE_FLOAT OR onlytype=DATATYPE_SMALLFLOAT THEN
    LET len= 14
    GOTO return_get_len
  END IF

  IF onlytype = DATATYPE_DECIMAL OR onlytype=DATATYPE_MONEY THEN    -- decimal money
    LET len= andbit(len,255) + 2
    GOTO return_get_len
  END IF
  IF onlytype=DATATYPE_DATE THEN
    LET len= 10
    GOTO return_get_len
  END IF
  IF onlytype=DATATYPE_VARCHAR OR                     -- varchar
     onlytype=201 THEN                   -- varchar
    LET len= andbit(len,255)
    GOTO return_get_len
  END IF
  IF onlytype=DATATYPE_DATETIME THEN                   -- datetime
    LET len= ( (andbit(len,15)*2) - (andbit(len/16,15)*2) +1 )
    GOTO return_get_len
  END IF
  IF onlytype=DATATYPE_INTERVAL THEN
    LET len= 10
    GOTO return_get_len
  END IF
  { FIXME: Handle TEXT and BYTE data types.
    WHEN onlytype = DATATYPE_BYTE
      LET strtype =  "BYTE"
    WHEN onlytype = DATATYPE_TEXT
      LET strtype =  "TEXT"
   }

LABEL error_get_len:
   DISPLAY "error: unknown datatype number ", onlyType USING "<<<<<&"
   RETURN 20, strtype

LABEL return_get_len:
  RETURN len, strtype

END FUNCTION

--
-- binary "and" bit per bit
--
FUNCTION andbit(num1,num2)

  DEFINE 
    num1 INTEGER,
    num2 INTEGER,
    res  INTEGER,
    mod1 SMALLINT,
    mod2 SMALLINT,
    pow  INTEGER

  LET res = 0
  LET pow = 1
  WHILE num1 != 0 AND num2 != 0
    LET mod1 = num1 MOD 2
    LET mod2 = num2 MOD 2
    LET res  = res + ( mod1 AND mod2 )*pow
    LET num1 = num1/2
    LET num2 = num2/2
    LET pow  = pow*2
  END WHILE
  RETURN res
END FUNCTION #andbit

--
-- build a label based on field name
-- replace "_" by space
-- return max_width characters from the label
--
FUNCTION getLabel(width, max_width, table, name)
  DEFINE width, max_width SMALLINT
  DEFINE table, name STRING 
  DEFINE tmp STRING
  DEFINE lab STRING
  DEFINE sblabel base.StringBuffer

  IF width > max_width THEN
    LET width=max_width
  END IF

  LET tmp=table, "_*"
  IF name MATCHES tmp THEN
    LET lab=name.subString(table.getLength()+2, name.getLength())
  ELSE
    LET lab=name
  END IF
  IF lab.getLength()>width THEN
    IF lab.getLength() > max_width THEN
      LET lab=lab.subString(1,max_width)
    END IF
  END IF
  LET lab=UPSHIFT(lab.subString(1,1)), lab.subString(2,lab.getLength())

  -- replace "_" by " "
  LET sblabel=base.StringBuffer.create()
  CALL sblabel.append(lab)
  CALL sblabel.replace("_"," ",0)
  LET lab=sblabel.toString()

  RETURN lab
END FUNCTION

FUNCTION getSpaces(num)
  DEFINE s STRING
  DEFINE i,num SMALLINT

  FOR i=1 TO num
    LET s=s," "
  END FOR
  RETURN s
END FUNCTION

FUNCTION usage()

  DISPLAY  "\n
Usage: fglmkper -s <schema> \[-t <template>] \[-o <output>] \"column [column  ...]\"\n
  -s schema : database schema
  -c columns  : space seperated list of columns\n
                i.e: customer.*  state.sname ... \n
  -t template : the name of a template-file in resource directory\n
                default: record.tpl\n
  -o output   : write output to file <output>\n "
  EXIT PROGRAM 1
END FUNCTION

FUNCTION extractColumns(src)
  DEFINE src STRING
  DEFINE s STRING
  DEFINE tok base.StringTokenizer
  DEFINE i SMALLINT

  LET tok=base.StringTokenizer.create(src," ")
  FOR i=1 TO tok.countTokens() 
    LET s=tok.nextToken()
    LET s=s.trimRight()
    IF s IS NOT NULL THEN
      CALL addColumn(s)
    END IF
  END FOR
  RETURN TRUE

END FUNCTION
FUNCTION addColumn(s)
  DEFINE s STRING

  CALL columns.appendElement()
  LET columns[columns.getLength()].star=( s MATCHES "*.\\*" )
  LET columns[columns.getLength()].table=s.subString(1,s.getIndexOf(".",1)-1)
  LET columns[columns.getLength()].column=s.subString(s.getIndexOf(".",1)+1, s.getLength())
  LET columns[columns.getLength()].found=0
  --DISPLAY "DBG adding: ",s, " .* is '", columns[columns.getLength()].star, "'"
END FUNCTION

FUNCTION getColumnsElement(tab_name, col_name)
  DEFINE tab_name, col_name STRING
  DEFINE i SMALLINT

  FOR i=1 TO columns.getLength()
    IF columns[i].table=tab_name THEN
      IF columns[i].star OR columns[i].column=col_name THEN
        LET columns[i].found=TRUE
        RETURN TRUE
      END IF
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

################################################################################
## FUNCTION str_type : Return type in a string
## Parameters :
##  type : Type 
##  len  : Length
## Returnings :
##  string type
##############################################################################

FUNCTION str_type(type,len)

    DEFINE type     INTEGER,
           onlytype INTEGER,
           len      INTEGER,
           strtype  VARCHAR(512)

 LET strtype = NULL

 LET onlytype = (type MOD 256)
 CASE
   WHEN onlytype = DATATYPE_CHAR
     LET strtype =  "CHAR(",len USING "<<<&",")"
   WHEN onlytype = DATATYPE_SMALLINT
     LET strtype =  "SMALLINT"
   WHEN onlytype = DATATYPE_INT
     LET strtype =  "INTEGER"
   WHEN onlytype = DATATYPE_FLOAT
     LET strtype =  "FLOAT(",len USING "<<<&",")"
   WHEN onlytype = DATATYPE_SMALLFLOAT
     LET strtype =  "SMALLFLOAT"
   WHEN onlytype = DATATYPE_DECIMAL
     IF andbit(len,255) = 255  THEN
       LET strtype =  "DECIMAL(",andbit(len/256,255) USING "<<<&",")"
     ELSE
       LET strtype =  "DECIMAL(",andbit(len/256,255) USING "<<<&",",",
				 andbit(len,255) USING "<<<&",")"
     END IF
   WHEN onlytype = DATATYPE_SERIAL
     LET strtype =  "SERIAL"
   WHEN onlytype = DATATYPE_DATE
     LET strtype =  "DATE"
   WHEN onlytype = DATATYPE_MONEY
     IF andbit(len,255) = 255  THEN
       LET strtype =  "MONEY(",andbit(len/256,255) USING "<<<&",")"
     ELSE
       LET strtype =  "MONEY(",andbit(len/256,255) USING "<<<&",",",
			       andbit(len,255) USING "<<<&",")"
     END IF
   WHEN onlytype = DATATYPE_DATETIME
     LET strtype =  "DATETIME ",dtqualifer(len,TRUE) CLIPPED," TO ",
                                dtqualifer(len,FALSE)
   WHEN onlytype = 11
     LET strtype =  "BYTE"
   WHEN onlytype = 12
     LET strtype =  "TEXT"
   WHEN onlytype = DATATYPE_VARCHAR
     LET strtype =  "VARCHAR(",andbit(len,255) USING "<<<&",",",
		               andbit(len/256,255) USING "<<<&",")"
   WHEN onlytype = DATATYPE_INTERVAL
     LET strtype =  "INTERVAL ",dtqualifer(len,TRUE) CLIPPED," TO ",
                                dtqualifer(len,FALSE)
 END CASE

 #IF  (type >= 256)  THEN
 #  LET strtype = strtype CLIPPED," NOT NULL"
 #END IF

 RETURN strtype

END FUNCTION #str_type 

FUNCTION dtqualifer(len, dtfirst)

    DEFINE len     INTEGER,
           dtfirst SMALLINT,
           qual    VARCHAR(50),
           comp    SMALLINT

 LET comp = len
 LET qual = NULL

 IF dtfirst THEN
   LET comp = andbit(comp/16,15)
 ELSE
   LET comp = andbit(comp,15)
 END IF

 CASE
   WHEN comp = 0
     LET qual = "YEAR"
   WHEN comp = 2
     LET qual = "MONTH"
   WHEN comp = 4
     LET qual = "DAY"
   WHEN comp = 6
     LET qual = "HOUR"
   WHEN comp = 8
     LET qual = "MINUTE"
   WHEN comp = 10
     LET qual = "SECOND"
   WHEN comp = 11
     LET qual = "FRACTION(1)"
   WHEN comp = 12
     IF dtfirst THEN
       LET qual = "FRACTION"
     ELSE
       LET qual = "FRACTION(2)"
     END IF
   WHEN comp = 13
     IF dtfirst THEN
       LET qual = "FRACTION"
     ELSE
       LET qual = "FRACTION(3)"
     END IF
   WHEN comp = 14
     LET qual = "FRACTION(4)"
   WHEN comp = 15
     LET qual = "FRACTION(5)"
   OTHERWISE
     LET qual = NULL
     EXIT CASE
 END CASE

 RETURN qual

END FUNCTION # dtqualifer 

--this part contains some functions for reading a textfile into a buffer
--array, making text substitutions in the buffer 
--and writing out the buffer to a textfile
--to be not dependent on "sed"

FUNCTION replace_geterr()
  RETURN replace_errstr
END FUNCTION

FUNCTION replace_readbuffer(infile,buffer)
  DEFINE infile STRING
  DEFINE buffer DYNAMIC ARRAY OF STRING
  DEFINE linestr STRING
  DEFINE ch_src base.Channel
  DEFINE i,mystatus INTEGER
  CALL buffer.clear()
  LET  ch_src=base.channel.create()
  WHENEVER ERROR CONTINUE
  CALL ch_src.openFile(infile,"r")
  LET mystatus=status
  WHENEVER ERROR STOP
  IF mystatus < 0 THEN
    LET replace_errstr= "can't open : "||infile||" for read"
    RETURN 0
  END IF
  LET i=1
  WHILE (linestr:=ch_src.readline()) IS NOT NULL
    LET buffer[i]=linestr
    LET i=i+1
  END WHILE
  CALL ch_src.close()
  RETURN 1
END FUNCTION

FUNCTION replace_writebuffer(buffer,outfile)
  DEFINE buffer DYNAMIC ARRAY OF STRING
  DEFINE outfile STRING
  DEFINE ch_dest base.Channel
  DEFINE i,len INTEGER
  LET  ch_dest=base.channel.create()
  CALL ch_dest.openFile(outfile,"w")
  IF status < 0 THEN
    LET replace_errstr= "can't open : "||outfile||" for write"
    RETURN 0
  END IF
  LET len=buffer.getLength()
  FOR i=1 TO len
    CALL ch_dest.writeline(buffer[i])
  END FOR
  CALL ch_dest.close()
  RETURN 1
END FUNCTION


--finds a given string at the given start position in the
--linestr string and returns if it is an word (identifier) or just
--a string portion
FUNCTION replace_find_string (linestr, tofind , pos, matchcase)
  DEFINE linestr ,tofind STRING
  DEFINE pos,matchcase,found,foundword INTEGER
  DEFINE leftChar , rightChar String
  IF matchcase THEN
    LET found=linestr.getIndexOf(tofind,pos)
  ELSE
    LET found=getIndexOfI(linestr,tofind,pos)
  END IF
  LET foundword=1
  --try to find out if the left side has whitespace or
  IF found > 1 THEN
    LET leftchar=linestr.getCharAt(found-1)
    IF NOT isDelimiterChar(leftChar) THEN
      LET foundword=0
    END IF -- not isDelimiterChar()
  END IF -- found > 1
  IF found >= 1 AND found+tofind.getLength()<linestr.getLength() THEN
    LET rightChar=linestr.getCharAt(found+tofind.getLength())
    --DISPLAY "rightChar is :",rightChar
    IF NOT isDelimiterChar(rightChar) THEN
      LET foundword=0
    END IF -- not isDelimiterChar()
  END IF -- found > 1
  RETURN found,foundword
END FUNCTION

--FUNCTION generate_spaces(numspaces)
--  DEFINE numspaces,i INTEGER
--  DEFINE spacestr base.StringBuffer
--  LET spacestr=base.StringBuffer.create()
--  FOR i=1 TO numspaces
--    CALL spacestr.append(" ")
--  END FOR
--  RETURN spacestr.toString()
--END FUNCTION

FUNCTION generate_spaces(numspaces)
  DEFINE numspaces,i INTEGER
  DEFINE spacestr STRING
  FOR i=1 TO numspaces
    LET spacestr=spacestr.append(" ")
  END FOR
  RETURN spacestr
END FUNCTION

--replaces all occurences of 'toreplacestr' with 'replacestr' in a
--dynamic array of strings
FUNCTION replace_string_in_buffer(toreplacestr,replacestr,buffer,matchcase,wordonly) 
  DEFINE toreplacestr, replacestr STRING
  DEFINE buffer DYNAMIC ARRAY OF STRING
  DEFINE matchcase,wordonly INTEGER
  DEFINE i,j,len,found,foundword,hasnewline INTEGER
  DEFINE idxnl,chars_in_while,rlen INTEGER
  DEFINE linestr,str1,str2,spaces,part STRING
  LET len=buffer.getLength()
  IF replacestr.getIndexOf("\n",1)>0 THEN
    LET hasnewline=1
  END IF
  FOR i=1 TO len
    LET linestr=buffer[i]
    CALL replace_find_string(linestr,toreplacestr,1,matchcase) RETURNING found,foundword
    WHILE found<>0
      IF (NOT wordonly) OR (foundword AND wordonly) THEN
        LET str1=linestr.subString(1,found-1)
        LET str2=linestr.subString(found+toreplacestr.getLength(),linestr.getLength())
        --LET linestr=sfmt("%1%2%3", str1, replacestr, str2)
        IF hasnewline THEN
          --we want to indent the subsequent lines with the same level as the 
          --length of str1
          LET spaces=generate_spaces(str1.getLength())
          LET chars_in_while=0
          LET rlen=replacestr.getLength()
          LET j=0
          WHILE (idxnl:=replacestr.getIndexOf("\n",1))>0
            LET part=replacestr.subString(1,idxnl)
            LET chars_in_while=chars_in_while+part.getLength()
            IF j=0 THEN
              LET linestr=str1, part
            ELSE
              LET linestr=linestr,spaces,part
            END IF
            LET replacestr=replacestr.subString(idxnl+1,replacestr.getLength())
            LET j=j+1
          END WHILE
          IF j>1 THEN
            LET linestr=linestr,spaces
          END IF
          IF chars_in_while<rlen THEN
            LET linestr=linestr,spaces,replacestr
          END IF
          --finally add the rest
          LET linestr=linestr,str2
          
        ELSE
          LET linestr=str1, replacestr, str2
        END IF
      END IF
      CALL replace_find_string(linestr,toreplacestr,found+toreplacestr.getLength(),matchcase) RETURNING found,foundword

    END WHILE
    LET buffer[i]=linestr
  END FOR
END FUNCTION

--reads in the buffer, calls the substitution and writes out the buffer
--infile may be the same as outfile
FUNCTION replace_string_in_file(toreplacestr,replacestr,infile,outfile,
                                matchcase,wordonly)
  DEFINE toreplacestr, replacestr, infile, outfile STRING
  DEFINE matchcase,wordonly INTEGER
  DEFINE buffer DYNAMIC ARRAY OF STRING
  IF NOT replace_readbuffer(infile,buffer) THEN
    RETURN 0
  END IF
  CALL replace_string_in_buffer(toreplacestr,replacestr,buffer,matchcase,wordonly) 
  RETURN replace_writebuffer(buffer,outfile) 
END FUNCTION



FUNCTION res_init(resource)
  DEFINE resource STRING
  DEFINE s STRING
  DEFINE ch base.channel

  IF resource IS NULL THEN
    LET resource=file_join(base.Application.getProgramDir(), "resource")
    LET resource=file_join(resource,"default.res")
  END IF

  -- load template and initialize m array
  LET ch=base.channel.create()
  CALL ch.openFile(resource, "r")
  WHILE (s:=ch.readLine()) IS NOT NULL
    LET s=s.trim()
    CASE
      WHEN s MATCHES "MATCH *"
        CALL match.appendElement()
        CALL parse(s.subString(6,s.getLength())) RETURNING match[match.getLength()].*
      WHEN s MATCHES "MAX_WIDTH *"
        CALL maxWidth.appendElement()
        CALL parse(s.subString(10,s.getLength())) RETURNING maxWidth[maxWidth.getLength()].*
      WHEN s MATCHES "MIN_WIDTH *"
        CALL minWidth.appendElement()
        CALL parse(s.subString(10,s.getLength())) RETURNING minWidth[minWidth.getLength()].*
    END CASE
  END WHILE
END FUNCTION

--
-- t = type of requested replacemen
--      T table
--      D detail form
-- s = define of variable in string representation "customer.customer_name CHAR(3)"
-- raw = definition of the field. f000=customer.customer_name
--
FUNCTION attributeReplace(t, s, raw )
  DEFINE t CHAR
  DEFINE s, raw, ns STRING
  DEFINE i SMALLINT
  DEFINE tr STRING

  LET ns=raw
  FOR i=1 TO match.getLength()
    IF t=match[i].t OR match[i].t="B" THEN
      LET tr=match[i].replace
      IF s MATCHES match[i].match THEN
        IF tr NOT MATCHES "*%1*" THEN
          DISPLAY "error: invalid entry in 'default.res' '",
                   match[i].match, "' '",
                   match[i].replace, "'"
          EXIT PROGRAM (-1)
        END IF
        LET ns=tr.subString(1, tr.getIndexOf("%1",1)-1), 
            ns, tr.subString(tr.getIndexOf("%1",1)+2,tr.getLength())
      END IF
    END IF
  END FOR
  RETURN ns
END FUNCTION

--
-- t = type of requested replacemen
--      T table
--      D detail form
-- s = define of variable in string representation "customer.customer_name CHAR(3)"
-- raw = definition of the field. f000=customer.customer_name
-- width = number of characters in form
--
FUNCTION maxWidth(t, s, width)
  DEFINE t CHAR
  DEFINE s STRING
  DEFINE i SMALLINT
  DEFINE width SMALLINT

  FOR i=1 TO maxWidth.getLength()
    IF t=maxWidth[i].t OR maxWidth[i].t="B" THEN
      IF s MATCHES maxWidth[i].match THEN
        LET width=maxWidth[i].width
      END IF
    END IF
  END FOR
  RETURN width
END FUNCTION

FUNCTION parse(line)
  DEFINE line, t, expr, value STRING
  DEFINE s,e SMALLINT

  -- type
  LET line=line.trim()
  LET s=line.getIndexOf("'",1)
  LET e=line.getIndexOf("'",s+1)
  LET t=line.subString(s+1,e-1)
  LET line=line.subString(e+1, line.getLength())

  -- expression
  LET line=line.trimLeft()
  LET s=line.getIndexOf("'",1)
  LET e=line.getIndexOf("'",s+1)
  LET expr=line.subString(s+1,e-1)
  LET line=line.subString(e+1, line.getLength())

  -- value
  LET line=line.trimLeft()
  LET s=line.getIndexOf("'",1)
  LET e=line.getIndexOf("'",s+1)
  LET value=line.subString(s+1,e-1)

  RETURN t, expr, value
END FUNCTION

