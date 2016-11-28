#+ File open/save dialog box
#+ Provided in the utility library.
#+

IMPORT os
IMPORT FGL fglped_fileutils
IMPORT FGL fgldialog

PUBLIC TYPE FILEDLG_RECORD RECORD
    title STRING,
    defaultfilename STRING,
    defaultpath STRING,
    opt_choose_directory SMALLINT, -- if this is set the user can only choose directories
    opt_create_dirs SMALLINT,  -- allows the creation of a new subdirectory
    opt_delete_files SMALLINT, -- allows to delete files when running the dialog
    types DYNAMIC ARRAY OF RECORD -- list for the file type combobox
      description STRING, -- string to display
      suffixes STRING -- pipe separated string of all possible suffixes for one entry
                      -- example "*.per|*.4gl"
    END RECORD
END RECORD

DEFINE _filedlg_list DYNAMIC ARRAY OF RECORD
                    eimage STRING, -- Used to detect the type!!!
                    entry STRING, -- Filename or Dirname
                    esize INT,
                    emodt STRING,
                    etype STRING -- C_DIRECTORY or "*.xxx File"
                END RECORD

DEFINE _flat_files DYNAMIC ARRAY OF STRING

DEFINE last_opendlg_directory STRING
DEFINE last_savedlg_directory STRING
DEFINE m_r FILEDLG_RECORD
CONSTANT C_DIRECTORY="Directory"
CONSTANT C_OPEN="open"
CONSTANT C_SAVE="save"

#+ Opens a file dialog to open a file.
#+ @returnType String
#+ @return The selected file path, or NULL is canceled.
#+ @param r the record describing the dialog
#
FUNCTION filedlg_open(r)
  DEFINE r FILEDLG_RECORD
  DEFINE t, fn STRING
  IF _isLocal() THEN
    CALL ui.interface.frontCall("standard","openfile",[os.Path.pwd(),
      r.types[1].description,
      r.types[1].suffixes,
      r.title],[fn])
  ELSE
    IF r.defaultpath IS NULL THEN
      IF last_opendlg_directory IS NULL THEN
        LET last_opendlg_directory = "."
      END IF
      LET r.defaultpath = last_opendlg_directory
    END IF
    IF r.title IS NOT NULL THEN
      LET t = r.title
    ELSE
      IF r.opt_choose_directory THEN
        LET t = "Open Directory"
      ELSE
        LET t = "Open File"
      END IF
    END IF
    LET fn = _filedlg_doDlg(C_OPEN,t,r.*)
    IF fn IS NOT NULL THEN
      LET last_opendlg_directory = file_get_dirname(fn)
    END IF
  END IF
  RETURN fn
END FUNCTION

#+ Opens a file dialog to save a file.
#+ @returnType String
#+ @return The selected file path, or NULL is canceled.
#+ @param r The record describing the dialog
#
FUNCTION filedlg_save(r)
  DEFINE r FILEDLG_RECORD
  DEFINE t, fn STRING
  IF _isLocal() THEN
    CALL ui.interface.frontCall("standard","savefile",[os.Path.pwd(),
      r.types[1].description,
      r.types[1].suffixes,
      r.title],[fn])
  ELSE
    IF r.defaultpath IS NULL THEN
      IF last_savedlg_directory IS NULL THEN
        LET last_savedlg_directory = "."
      END IF
      LET r.defaultpath = last_savedlg_directory
    END IF
    IF r.title IS NOT NULL THEN
      LET t = r.title
    ELSE
      LET t = "Save File"
    END IF
    LET fn = _filedlg_doDlg(C_SAVE,t,r.*)
    IF fn IS NOT NULL THEN
      LET last_savedlg_directory = file_get_dirname(fn)
    END IF
  END IF
  RETURN fn
END FUNCTION

------------------- internal _filedlg_xxx functions ----------------------------

FUNCTION _filedlg_fetch_filenames(d,currpath,typelist,currfile)
  DEFINE d ui.Dialog
  DEFINE currpath STRING
  DEFINE typelist STRING
  DEFINE currfile STRING
  DEFINE i,len,found INT
  LET currpath=file_normalize_dir(currpath)
  CALL _filedlg_getfiles_int(currpath,typelist) 
  LET len=_filedlg_list.getLength()
  --jump to the current file
  LET currfile=file_get_short_filename(currfile)
  IF d IS NULL THEN
    RETURN
  END IF
  FOR i=1 TO len
    IF currfile=_filedlg_list[i].entry THEN
      LET found=1
      CALL d.setCurrentRow("sr",i)
      EXIT FOR
    END IF
  END FOR
  IF NOT found THEN
    CALL d.setCurrentRow("sr",1)
  END IF
  --CALL update_row(d.getCurrentRow("sr")) RETURNING dummy
END FUNCTION

FUNCTION _filedlg_doDlg(dlgtype,title,r)
  DEFINE dlgtype STRING
  DEFINE title STRING
  DEFINE r FILEDLG_RECORD
  DEFINE currpath, path, filename, ftype, dirname, filepath STRING
  DEFINE delfilename, errstr STRING
  DEFINE doContinue, i INT
  DEFINE cb ui.ComboBox
  DEFINE form ui.Form
  DEFINE win ui.Window

  LET m_r.* = r.*

  OPEN WINDOW _filedlg WITH FORM "fglped_md_filedlg" ATTRIBUTES(TEXT=title)

  CALL fgl_settitle(title)

  LET currpath = r.defaultpath
  LET filename = r.defaultfilename
  DISPLAY BY NAME filename

  IF currpath="." THEN 
    LET currpath=file_pwd()
  END IF
  IF filename IS NOT NULL THEN
    LET dirname = file_get_dirname(filename)
    IF dirname  IS NOT NULL AND dirname  <> currpath THEN
      LET currpath = dirname 
    END IF
    LET filename = file_get_short_filename(filename)
  END IF
  DISPLAY currpath TO currpath
  LET cb = ui.ComboBox.forName("formonly.ftype")
  IF cb IS NULL THEN
     DISPLAY "ERROR:form field \"ftype\" not found in form filedlg"
     EXIT PROGRAM
  END IF
  CALL cb.clear()
  FOR i=1 TO r.types.getLength()
    CALL cb.addItem(r.types[i].suffixes,r.types[i].description)
  END FOR
  IF r.types.getLength()>0 THEN
    LET ftype=r.types[1].suffixes
  END IF
  CALL ui.Dialog.setDefaultUnbuffered(TRUE)
  OPTIONS FIELD ORDER CONSTRAINED
  OPTIONS INPUT WRAP
  DIALOG 
    DISPLAY ARRAY _filedlg_list TO sr.* 
      BEFORE ROW 
        LET filename=update_row(arr_curr(),filename)
      ON ACTION del
        LET delfilename=_filedlg_list[arr_curr()].entry
        IF _filedlg_mbox_yn("Confirm delete",sfmt("Really delete '%1'?",delfilename),"question") THEN
          IF NOT file_delete(file_join(currpath,delfilename)) THEN
            CALL _filedlg_mbox_ok("Error",sfmt("Can't delete %1",filename),"stop")
          END IF
          CALL _filedlg_fetch_filenames(DIALOG,currpath,ftype,NULL)
        END IF
    END DISPLAY

    INPUT BY NAME filename,ftype ATTRIBUTES(WITHOUT DEFAULTS)
      ON CHANGE ftype
        CALL _filedlg_fetch_filenames(DIALOG,currpath,ftype,NULL)
    END INPUT

    BEFORE DIALOG
      CALL _filedlg_fetch_filenames(DIALOG,currpath,ftype,filename)
      LET win = ui.Window.getCurrent()
      LET form = win.getForm()
      DISPLAY "File:" TO lfn
      IF dlgtype=C_SAVE THEN
        CALL form.setElementText("accept","Save")
      END IF
      IF r.opt_choose_directory THEN
        DISPLAY "Directory:" TO lfn
        CALL DIALOG.setFieldActive("formonly.ftype",0)
        DISPLAY "foo" TO ftype
      END IF
      IF dlgtype=C_SAVE OR r.opt_choose_directory THEN
        NEXT FIELD filename
      END IF

    ON ACTION arrayselect 
      --nasty trick ,because Tables doubleclick actions are not
      --automagically locally associated with the <Return> key,
      --we have to check here if we are really in the table
      IF (NOT _filedlg_focusInTable("sr")) OR (NOT r.opt_choose_directory) THEN
        GOTO doaccept
      END IF
      LET doContinue=FALSE
      LET filepath = file_join(currpath,_filedlg_list[arr_curr()].entry)
      --IF r.opt_choose_directory THEN
      IF file_exists(filepath) AND file_is_dir(filepath) THEN
        --switch  the directory and refill the array
        LET currpath=file_normalize_dir(filepath)
        CALL _filedlg_fetch_filenames(DIALOG,filepath,ftype,"..")
        DISPLAY BY NAME currpath
        IF r.opt_choose_directory THEN
          LET filename=update_row(arr_curr(),filename)
        ELSE
          LET filename=""
        END IF
      END IF
    ON ACTION accept
LABEL doaccept:
      LET doContinue=FALSE
      IF _filedlg_focusInTable("sr") THEN
        --we are in the display array
        IF r.opt_choose_directory AND _filedlg_list[arr_curr()].entry==".." THEN
          LET filepath = currpath
        ELSE
          LET filepath = file_join(currpath,_filedlg_list[arr_curr()].entry)
        END IF
      ELSE
        --not in display array
        IF (file_on_windows() AND filename.getCharAt(2)==":") OR 
           (filename.getCharAt(1)= file_get_separator()) THEN
           --we detected an absolute filename
          LET filepath=filename
        ELSE
          LET filepath = file_join(currpath,filename)
        END IF
      END IF
      IF file_exists(filepath) AND file_is_dir(filepath) THEN
        --switch  the directory and refill the array
        LET currpath=file_normalize_dir(filepath)
        IF NOT r.opt_choose_directory THEN
          CALL _filedlg_fetch_filenames(DIALOG,filepath,ftype,"..")
          DISPLAY BY NAME currpath
          LET filename=""
          LET doContinue=1
        ELSE
          LET filepath=currpath
        END IF
      END IF
      IF NOT doContinue AND dlgtype = C_OPEN THEN
        IF NOT file_exists(filepath) THEN
          LET errstr=SFMT(%"File or directory '%1' does not exist!",
                          file_get_short_filename(filepath))
          CALL _filedlg_mbox_ok("Error", errstr, "stop")
          ERROR errstr
          LET doContinue=1
        END IF
      END IF
      IF NOT doContinue AND dlgtype = C_SAVE THEN
        LET dirname=file_get_dirname(filepath) 
        IF NOT file_exists(dirname) THEN
          CALL _filedlg_mbox_ok("Error", SFMT(%"directory '%1' does not exist!",filepath), "stop")
          LET doContinue=1
        END IF
      END IF
      IF NOT doContinue THEN
        EXIT DIALOG
      END IF
    ON ACTION cancel
      LET filepath=NULL
      EXIT DIALOG
    ON ACTION move_up
      LET path = file_get_dirname(currpath)
      DISPLAY BY NAME currpath
      CALL _filedlg_fetch_filenames(DIALOG,path,ftype,currpath)
      IF file_normalize_dir(path)<>file_normalize_dir(currpath) THEN
        LET filename=""
        DISPLAY BY NAME filename
      END IF
      LET currpath=file_normalize_dir(path)
      DISPLAY BY NAME currpath
  END DIALOG
  CLOSE WINDOW _filedlg
  RETURN filepath
END FUNCTION

FUNCTION update_row(row,filename)
  DEFINE row INT
  DEFINE filename STRING
  DEFINE entry STRING
  IF row=0 THEN
    RETURN filename
  END IF
  LET entry = _filedlg_list[row].entry
  IF entry = ".." THEN
     LET entry=""
  END IF
  IF m_r.opt_choose_directory OR _filedlg_list[row].etype<>C_DIRECTORY THEN
    LET filename=entry
    DISPLAY BY NAME filename 
  END IF
  RETURN filename
END FUNCTION

FUNCTION _filedlg_intypelist(typelist,type)
  DEFINE typelist STRING
  DEFINE type STRING
  DEFINE st base.StringTokenizer
  LET st = base.StringTokenizer.create(typelist,"|")
  WHILE st.hasMoreTokens()
    IF st.nextToken()==type THEN RETURN TRUE END IF
  END WHILE
  RETURN FALSE
END FUNCTION


FUNCTION _filedlg_checktypeandext(typelist,fname)
  DEFINE typelist, fname STRING
  DEFINE e STRING
  IF _filedlg_intypelist(typelist,"*") THEN
     RETURN TRUE
  END IF
  LET e = file_extension(fname)
  IF e IS NOT NULL THEN
     IF _filedlg_intypelist(typelist,"*.*") THEN
        RETURN TRUE
     END IF
     IF _filedlg_intypelist(typelist,"*"||e) THEN
        RETURN TRUE
     END IF
  END IF
  RETURN FALSE
END FUNCTION

FUNCTION _filedlg_mbox_ok(title,message,icon)
  DEFINE title, message, icon STRING
  CALL fgl_winMessage(title,message,icon)
END FUNCTION

FUNCTION _filedlg_mbox_yn(title,message,icon)
  DEFINE title, message, icon STRING
  DEFINE r STRING
  LET r = fgl_winQuestion(title,message,"yes","yes|no",icon,0)
  RETURN ( r == "yes" )
END FUNCTION

FUNCTION _filedlg_getfiles_int(dirpath,typelist) 
  DEFINE dirpath, typelist STRING
  DEFINE dh, isdir INTEGER
  DEFINE fname, pname, size STRING
  CALL _filedlg_list.clear()
  CALL _flat_files.clear()
  LET dh = os.Path.diropen(dirpath)
  IF dh == 0 THEN 
    RETURN
  END IF
  WHILE TRUE
      LET fname = os.Path.dirnext(dh)
      IF fname IS NULL THEN 
        EXIT WHILE 
      END IF
      IF fname == "." THEN
         CONTINUE WHILE
      END IF
      LET pname = file_join(dirpath,fname)
      LET isdir=file_is_dir(pname)
      IF isdir THEN
         LET size = NULL
      ELSE
         LET size = os.Path.size(pname)
      END IF
      CALL _filedlg_appendEntry(isdir,fname,typelist,size,os.Path.mtime(pname))
  END WHILE
  CALL os.Path.dirclose(dh)
  IF m_r.opt_choose_directory  THEN
    MESSAGE sfmt("%1 %2 files in %3",_flat_files.getLength(),typelist,dirpath)
  END IF

END FUNCTION

FUNCTION _filedlg_appendEntry(isdir,name,typelist,size,modDate)
  DEFINE isdir INT
  DEFINE name STRING
  DEFINE typelist STRING
  DEFINE size INT
  DEFINE modDate STRING
  DEFINE type,image,ext STRING
  DEFINE len INT
  IF isdir THEN
    LET ext=""
    LET type=C_DIRECTORY
    LET image="folder"
  ELSE
    LET ext = file_extension(name)
    LET type = SFMT(%"%1-File",ext)
    LET image="file"
  END IF
  --exclude directories and fglped temp files
  IF name="." OR name.getIndexOf(".@",1)<>0 THEN
    RETURN
  ELSE IF NOT isdir AND NOT _filedlg_checktypeandext(typelist,name) THEN
    RETURN
  END IF
  END IF
  IF m_r.opt_choose_directory AND NOT isdir THEN 
    CALL _flat_files.appendElement()
    LET len=_filedlg_list.getLength()
    LET _flat_files[len] = name
  ELSE
    CALL _filedlg_list.appendElement()
    LET len=_filedlg_list.getLength()
    LET _filedlg_list[len].entry  = name
    LET _filedlg_list[len].etype  = type
    LET _filedlg_list[len].eimage = image
    LET _filedlg_list[len].esize  = size
    LET _filedlg_list[len].emodt  = modDate
  END IF
END FUNCTION


--helper function to detect the focus in a display array because
--fgl_dialog_getfieldname() doesn't work exactly at the moment
FUNCTION _filedlg_focusInTable(tabName)
  DEFINE tabName STRING
  DEFINE root,currWinNode,tabNode om.DomNode
  DEFINE doc om.DomDocument
  DEFINE currWinId,focusId INT
  DEFINE nl om.NodeList
  LET root=ui.Interface.getRootNode()
  LET currWinId= root.getAttribute("currentWindow")
  LET focusId=root.getAttribute("focus")
  LET doc  =ui.Interface.getDocument()
  LET currWinNode =doc.getElementById(currWinId)
  LET nl = currWinNode.selectByPath(SFMT("//Table[@tabName=\"%1\"]",tabName))
  IF nl.getLength()=0 THEN
    --did not find table
    RETURN 0
  END IF
  LET tabNode=nl.item(1)
  IF tabNode.getId()=focusId THEN
    RETURN 1
  END IF
  LET tabNode= doc.getElementById(focusId)
  RETURN 0
END FUNCTION

FUNCTION _getClientIP()
  DEFINE a,b String
  DEFINE p Integer
  LET a=fgl_getenv("FGLSERVER")
  LET p=a.getIndexOf(":",1)
  LET b=a.subString(1,p-1)
  RETURN b
END FUNCTION

FUNCTION _isLocal()
  DEFINE ip,fename STRING
  CALL ui.Interface.frontcall("standard","feinfo", ["fename"],[fename])
  IF (fename = "GDC" OR fename="Genero Desktop Client") THEN
    LET ip=_getClientIP()
    IF ip IS NULL OR ip=="localhost" OR ip="127.0.0.1" THEN
      RETURN TRUE
    END IF
  END IF
  RETURN FALSE
END FUNCTION
