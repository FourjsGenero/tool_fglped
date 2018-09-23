OPTIONS SHORT CIRCUIT
IMPORT os
IMPORT FGL fgldialog
IMPORT FGL fglped_md_wizard
IMPORT FGL fglped_md_filedlg
IMPORT FGL fglped_dialogs
IMPORT FGL fglped_fileutils
IMPORT FGL fglped_utils
IMPORT FGL fglped_schema

--holds the result of the compiler output
DEFINE compile_arr DYNAMIC ARRAY OF STRING
--current line,column
DEFINE m_cline,m_ccol INT
DEFINE m_sc_open INT
DEFINE m_error_line STRING
DEFINE m_formNode om.DomNode
DEFINE m_srcfile STRING
--DEFINE m_init INT
DEFINE m_formedit INT
DEFINE m_title STRING
DEFINE m_checked INT
DEFINE m_opt_cursor INT
--DEFINE m_canvasRect om.DomNode
--DEFINE m_currNode om.DomNode
DEFINE m_formVersion INT
DEFINE m_client_version FLOAT
DEFINE m_infiledlg INT --file dialog running ?
DEFINE m_lineno INT
DEFINE m_replace_src STRING
DEFINE m_replace_cursor INT
DEFINE m_showform_failed INT
DEFINE m_screen_closed INT
DEFINE m_user_styles STRING --user style file name
DEFINE m_style STRING --user selected Window Style
DEFINE m_browseidx INT
DEFINE m_toggle_text INT
DEFINE m_raiseId INT
DEFINE m_clientOnMac INT
DEFINE m_showWeb INT

DEFINE m_gasdir STRING
DEFINE m_port INT
DEFINE m_isMac BOOLEAN
DEFINE m_gbcdir,m_gbcname STRING
DEFINE m_appname STRING
DEFINE m_tmpWebForm STRING


--- searchdialog
DEFINE srch_search STRING
DEFINE srch_wholeword,srch_matchcase Integer
DEFINE srch_updown STRING
DEFINE srch_replace STRING
DEFINE srch_replaceall SMALLINT
DEFINE srch_hist_arr DYNAMIC ARRAY OF STRING
DEFINE srch_repl_arr DYNAMIC ARRAY OF STRING
CONSTANT WIZGEN="__wizgen__"
--used attribute names
CONSTANT A_STYLE="style"
CONSTANT A_VERSION="version"
CONSTANT A_NAME="name"
CONSTANT A_VALUE="value"
CONSTANT A_SAMPLE="sample"
CONSTANT A_SQLTYPE="sqlType"
--our preview style constant
CONSTANT S_PREVIEW="fglped_preview"
CONSTANT S_PREVIEW_GBC="fglped_preview_gbc"
--error word
CONSTANT S_ERROR="Error"
--error image
CONSTANT IMG_ERROR="stop"

MAIN
  DEFINE pname,fname,browsedir,pedpath STRING
  DEFINE code INT
  DEFINE first_window INT
  OPTIONS FIELD ORDER FORM
  LET m_port=6395 --default GAS port is 6394
  LET m_gasdir=fgl_getenv("FGLASDIR")
  --IF os.Path.exists(m_gasdir) THEN
  --  LET m_showWeb=TRUE
  --END IF

  IF (pedpath:=fgl_getenv("FGLPEDPATH")) IS NOT NULL THEN
    LET m_user_styles=file_join(pedpath,"user.4st")
  ELSE
    LET m_user_styles="user.4st"
  END IF
  CALL ui.Interface.loadStyles("fglped")
  LET m_opt_cursor=1
  LET first_window=TRUE
  IF num_args()>0 THEN
    LET pname=arg_val(1)
    IF pname="-browse" THEN
      LET browsedir="."
      IF num_args()>1 THEN
        LET browsedir=arg_val(2)
      END IF
      LET m_screen_closed=TRUE
      CLOSE WINDOW screen
      LET fname=browse(browsedir)
      IF fname IS NULL THEN
        RETURN
      END IF
    ELSE
      LET fname=basename(pname)
    END IF
  END IF
  CALL checkClientVersion()
  CALL edit_form(fname) RETURNING code
END MAIN

--main INPUT to edit the form, everything is called from here
FUNCTION edit_form(fname)
  DEFINE fname STRING
  DEFINE src,src_copy,copy2 STRING
  DEFINE idx,changed,init INTEGER
  DEFINE compmess,tmpname STRING
  DEFINE cname,wizdir STRING
  DEFINE ccursor,cursor,opt,directpreview, goto_def INT
  DEFINE ans,saveasfile,open_copy,browsedirname STRING
  --DEFINE old_style STRING
  IF m_screen_closed THEN
    OPEN WINDOW screen WITH FORM "fglped"
  ELSE
    OPEN FORM f FROM "fglped"
    DISPLAY FORM f
  END IF
  CALL setClientOnMac()
  IF isGBC() THEN
    CALL hideSideBar()
  END IF
  LET idx=1
  LET changed=1
  IF fname IS NULL THEN
    LET m_srcfile=NULL
    --LET src=file_new()
    LET src=file_new()
  ELSE
    LET m_srcfile=fname
    IF file_extension(fname) IS NULL THEN
      LET m_srcfile = fname,".per"
    END IF
    LET src=file_read(m_srcfile)
    IF src IS NULL THEN
      IF (ans:=fgl_winquestion("fglped",sfmt("The file \"%1\" cannot be found, create new?",m_srcfile),"yes","yes|no|cancel","question",0))="cancel" THEN
        RETURN 1
      END IF
      LET src=file_new()
      IF ans="yes" THEN
        CALL my_write(m_srcfile,src)
      ELSE
        LET m_srcfile=""
      END IF
    END IF
  END IF
 
  LET tmpname=setCurrForm(m_srcfile,tmpname)
  LET src_copy=src
  LET copy2=src
  INPUT BY NAME src WITHOUT DEFAULTS ATTRIBUTE(NAME="theinput")
    BEFORE INPUT
      LET init=0
      --CALL DIALOG.setActionActive("cancel",0)
      --CALL DIALOG.setActionHidden("cancel",1)
      CALL DIALOG.setActionActive("accept",0)
      CALL DIALOG.setActionHidden("accept",1)
      CALL DIALOG.setActionHidden("fglfed_select",1)
      IF isGBC() THEN
        CALL addAcceleratorsToTopMenu()
        CALL DIALOG.setActionActive("find",0)
        CALL DIALOG.setActionActive("findnext",0)
        CALL DIALOG.setActionActive("replace",0)
        CALL DIALOG.setActionActive("replaceagain",0)
        CALL DIALOG.setActionActive("undolastreplace",0)
        CALL DIALOG.setActionActive("fglfed_select",0)
        CALL DIALOG.setActionActive("jump_to_def",0)
        CALL DIALOG.setActionHidden("jump_to_def",1)
        CALL DIALOG.setActionActive("viewerr",0)
        CALL DIALOG.setActionHidden("viewerr",1)
        CALL DIALOG.setActionActive("findword",0)
        CALL DIALOG.setActionHidden("findword",1)
        CALL DIALOG.setActionActive("toggle_text",0)
        CALL DIALOG.setActionHidden("toggle_text",1)
      END IF
      IF NOT isGDC() THEN
        CALL deactivateIdleAction()
      END IF
    BEFORE FIELD src
      IF cursor>0 THEN
        CALL my_setcursor(cursor)
      END IF
    ON ACTION jump_to_def
      LET goto_def=TRUE
      GOTO doViewErr
    ON ACTION viewerr
      LET goto_def=FALSE
LABEL doViewErr:
      LET src=fetchSrc(get_fldbuf(src))
      LET tmpname= getTmpFileName(m_srcfile,".per")
      LET compmess = previewForm(tmpname,src,ccursor,0,opt)
      IF compmess IS NOT NULL THEN
        CALL show_compile_error(src,1,tmpname)
      ELSE
        IF goto_def THEN
          CALL do_finddef(src,my_cursor())
        END IF
      END IF
      LET copy2=src
    ON ACTION preview
      LET directpreview=1
      LET opt=0
LABEL dopreview:
      MESSAGE ""
      LET src=fetchSrc(get_fldbuf(src))
      LET tmpname= getTmpFileName(m_srcfile,".per")
      IF init OR directpreview THEN
        LET compmess=previewForm(tmpname,src,my_cursor(),1,opt)
        LET copy2=src
        LET directpreview=0
      ELSE
        LET copy2=""
      END IF
    --ON ACTION choose_style
    --  LET old_style=m_style
    --  IF choose_style() AND checkChanged(old_style,m_style) THEN
    --    GOTO dopreview
    --  END IF
    ON ACTION toggle_text
      LET m_toggle_text = NOT m_toggle_text
      GOTO dopreview
    ON ACTION new
      LET src = fetchSrc(get_fldbuf(src))
      IF (ans:=checkFileSave(src,src_copy))="cancel" THEN CONTINUE INPUT END IF
      LET src=file_new()
      LET src_copy=""
      CALL display_by_name_src(src)
      CALL close_sc_window()
      LET tmpname=setCurrForm("",tmpname)
      IF NOT isGBC() THEN
        CALL showform(opt,"fglped_empty.42f",1,0)
        LET init=0
        GOTO dopreview
      END IF
    ON ACTION newfromwiz
      LET src = fetchSrc(get_fldbuf(src))
      IF (ans:=checkFileSave(src,src_copy))="cancel" THEN CONTINUE INPUT END IF
      IF ans="no" THEN LET src=src_copy END IF
      LET open_copy=src
      CALL dowizard() RETURNING src,wizdir
      IF src IS NOT NULL THEN
        LET src_copy=""
        LET tmpname=setCurrForm(file_join(wizdir,WIZGEN),tmpname)
        CALL display_by_name_src(src)
        CALL close_sc_window()
        LET init=1
        GOTO dopreview
      ELSE
        LET src = open_copy
        CALL display_by_name_src(src)
        LET copy2 = NULL
      END IF
    ON ACTION browse
      LET src = fetchSrc(get_fldbuf(src))
      IF (ans:=checkFileSave(src,src_copy))="cancel" THEN CONTINUE INPUT END IF
      IF ans="no" THEN 
        LET src=src_copy 
        CALL display_by_name_src(src)
      END IF
      LET open_copy = src
      LET src_copy = src
      LET browsedirname=file_get_dirname(m_srcfile);
      --LET browsedirname=fglped_dirdlg(browsedirname)
      LET cname=browse(browsedirname)
      IF cname IS NOT NULL THEN
        GOTO doOpen
      ELSE
        LET src = open_copy
        CALL display_by_name_src(src)
        LET copy2 = NULL
      END IF
    ON ACTION open
      LET src = fetchSrc(get_fldbuf(src))
      IF (ans:=checkFileSave(src,src_copy))="cancel" THEN CONTINUE INPUT END IF
      IF ans="no" THEN 
        LET src=src_copy 
        CALL display_by_name_src(src)
      END IF
      LET open_copy = src
      LET src_copy = src
      LET m_infiledlg=1
      LET cname = fglped_filedlg()
      LET m_infiledlg=0
LABEL doOpen:
      IF cname IS NOT NULL THEN
        LET src=file_read(cname)
        IF src IS NULL THEN
          LET src=src_copy
          CALL fgl_winmessage(S_ERROR,sfmt("Can't read:%1",cname),IMG_ERROR)
        ELSE
          LET src_copy = src
          LET tmpname = setCurrForm(cname,tmpname)
          CALL display_by_name_src(src)
          CALL close_sc_window()
          GOTO dopreview
        END IF
      ELSE
        LET src = open_copy
        CALL display_by_name_src(src)
        LET copy2 = NULL
      END IF
    ON ACTION save
      LET src=fetchSrc(get_fldbuf(src))
      IF isNewFile() THEN
        GOTO dosaveas
      END IF
      IF NOT file_write(m_srcfile,src) THEN
        CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",m_srcfile),IMG_ERROR)
      ELSE
        MESSAGE "saved:",m_srcfile
        LET src_copy=src
      END IF
    ON ACTION saveas
      LET src=fetchSrc(get_fldbuf(src)) 
LABEL dosaveas:
      IF (saveasfile:=fglped_saveasdlg(m_srcfile)) IS NOT NULL THEN
        IF NOT file_write(saveasfile,src) THEN
          CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",saveasfile),IMG_ERROR)
        ELSE
          LET tmpname=setCurrForm(saveasfile,tmpname)
          LET src_copy=src
          CALL mysetTitle()
          CALL display_by_name_src(src)
        END IF
      END IF
    ON ACTION find
      CALL do_find(src:=fetchSrc(get_fldbuf(src)),my_cursor(),my_getselend())
    ON ACTION findnext
      CALL do_findnext(src:=fetchSrc(get_fldbuf(src)),my_cursor())
    ON ACTION findword
      CALL do_findword(src:=fetchSrc(get_fldbuf(src)),my_cursor())
    ON ACTION gotoline
      CALL do_gotoline(src:=fetchSrc(get_fldbuf(src)),my_cursor())
    ON ACTION replace
      CALL do_replace(src:=fetchSrc(get_fldbuf(src)),my_cursor(),my_getselend())
    ON ACTION replaceagain
      CALL do_replaceagain(src:=fetchSrc(get_fldbuf(src)),my_cursor(),my_getselend())
    ON ACTION undolastreplace
      IF m_replace_src IS NOT NULL THEN
        LET src=m_replace_src
        CALL display_by_name_src(src)
        CALL fgl_dialog_setcursor(m_replace_cursor)
      END IF
    ON ACTION fglfed_select
      DISPLAY "fglfed_select"
      LET src=fetchSrc(get_fldbuf(src))
      IF (ccursor:=getSel(src))<>0 THEN
        LET cursor=ccursor
      END IF
    ON ACTION cancel
      DISPLAY "-------------cancel------------------"
    ON ACTION nextfield 
      GOTO completion
    ON ACTION prevfield 
      --prevent Shift-Tab doing crap
      GOTO completion
    ON KEY(TAB)
LABEL completion:
      LET src=fetchSrc(get_fldbuf(src))
      LET copy2=src
      LET ccursor=my_cursor()
      --write only the string portion until the cursor to prevent 
      --errors caused by later crap
      CALL my_write(tmpname,src.subString(1,ccursor-1))
      CALL complete(src,tmpname,ccursor,0) RETURNING src,ccursor
      IF checkChanged(src,copy2) 
        --OR ccursor<>my_cursor() 
                                     THEN
        LET changed=1
        LET copy2=src
        CALL display_by_name_src(src)
      END IF
      IF ccursor<>my_cursor() THEN
        CALL my_setcursor(ccursor)
      END IF
      IF NOT isGBC() THEN
        GOTO idleCheck
      END IF
    ON IDLE 1
      LET src=fetchSrc(get_fldbuf(src))
      IF checkChanged(src,copy2) THEN
         LET changed=1
         LET copy2=src
      ELSE 
        IF m_srcfile IS NULL AND src IS NULL AND NOT m_sc_open THEN
          CALL showform(opt,"fglped_empty.42f",0,0)
        END IF
      END IF
      LET ccursor=my_cursor()
      CALL computeLineCol(src,ccursor) RETURNING m_cline,m_ccol
LABEL idleCheck:
      MESSAGE ""
      IF changed THEN
        LET changed=0
        LET compmess = previewForm(tmpname,src,ccursor,0,opt)
        IF compmess IS NULL THEN
          LET init=1
        ELSE
          CALL show_compile_error(src,0,tmpname)
        END IF
      ELSE
        IF m_opt_cursor AND ccursor<>cursor AND  
           compmess IS NULL AND m_formNode IS NOT NULL THEN
          CALL doHighlight(src)
        END IF
      END IF
      LET cursor=ccursor
      --update the status
      IF m_error_line IS NOT NULL THEN
        MESSAGE m_error_line
      END IF
    ON ACTION close
      LET src=fetchSrc(get_fldbuf(src))
      IF checkFileSave(src,src_copy)="cancel" THEN
        CONTINUE INPUT
      ELSE
        EXIT INPUT
      END IF
  END INPUT

  CALL delete_tmpfiles(tmpname) 
  CALL close_sc_window()
  CALL fgl_refresh()
  RETURN 0
END FUNCTION

--helper function to check for the runtime existence of an attribute
--would be nice to have this as a library function because I found use of 
--this in each of my projects
FUNCTION attrExists(node,name)
  DEFINE node om.DomNode
  DEFINE name STRING
  DEFINE i,len INTEGER
  LET len=node.getAttributesCount()
  FOR i=1 TO len
    IF node.getAttributeName(i)=name THEN
      RETURN 1
    END IF
  END FOR
  RETURN 0
END FUNCTION

--the following functions help displaying some data on all the widgets to get
--an impression about the width of characters and fields

FUNCTION recursiveSetText(node)
  DEFINE node om.DomNode
  DEFINE c om.DomNode
  DEFINE width INT
  DEFINE height INT
  LET width=1
  IF attrExists(node,"width") THEN
    LET width=node.getAttribute("width")
  END IF
  LET height=1
  IF attrExists(node,"height") THEN
    LET height=node.getAttribute("height")
  END IF
  CASE node.getTagName()
    WHEN "Edit"
      CALL fillField(node,width)
    WHEN "ButtonEdit"
      CALL fillField(node,width)
    WHEN "DateEdit"
      CALL fillWithDate(node,width)
    WHEN "TextEdit"
      CALL fillWithChars(node,width,height)
  END CASE
  LET c=node.getFirstChild()
  WHILE c IS NOT NULL
    CALL recursiveSetText(c)
    LET c=c.getNext()
  END WHILE
END FUNCTION

FUNCTION setValue(decoration,value)
  DEFINE parent om.DomNode
  DEFINE decoration om.DomNode
  DEFINE value,parentTag STRING
  DEFINE vlistnode,v,pageSizeNode om.DomNode
  DEFINE i,pageSize INT
  LET parent=decoration.getParent()
  LET parentTag=parent.getTagName()
  CASE parentTag
    WHEN "FormField"
      CALL parent.setAttribute(A_VALUE,value)
      RETURN
    WHEN "Matrix"
      --fall through
    WHEN "TableColumn" 
      --fall through
    OTHERWISE 
      --DISPLAY "setValue for ",parent.getTagName()
      RETURN
  END CASE
  LET vlistnode=decoration.getNext()
  IF vlistnode IS NULL THEN
    --no ValueList created yet
    LET vlistnode=parent.createChild("ValueList")
    IF parentTag="Matrix" THEN
      LET pageSizeNode=parent
    ELSE
      LET pageSizeNode=parent.getParent()
    END IF
    LET pageSize=pageSizeNode.getAttribute("pageSize")
    FOR i=1 TO pageSize
      LET v=vlistNode.createChild("Value")
      CALL v.setAttribute(A_VALUE,value)
    END FOR
  ELSE
    WHILE vlistnode IS NOT NULL
      IF vlistnode.getTagName()="ValueList" THEN
        LET v=vlistnode.getFirstChild()
        WHILE v IS NOT NULL
          CALL v.setAttribute(A_VALUE,value)
          LET v=v.getNext()
        END WHILE
      END IF
      LET vlistnode=vlistnode.getNext()
    END WHILE
  END IF
END FUNCTION

FUNCTION isDecoration(node)
  DEFINE node om.DomNode
  DEFINE parent om.DomNode
  DEFINE tag STRING
  LET parent=node.getParent()
  LET tag=parent.getTagName()
  IF tag="FormField" OR tag="Matrix" OR tag="TableColumn" THEN
     RETURN 1
  END IF
  RETURN 0
END FUNCTION

FUNCTION fillField(node,width)
  DEFINE node om.DomNode
  DEFINE width INT
  DEFINE parent om.DomNode
  DEFINE i,done INT
  DEFINE value,sample,sqlType STRING
  IF isDecoration(node) THEN
    LET parent=node.getParent()
    IF attrExists(parent,A_SQLTYPE) THEN
      LET sqlType=parent.getAttribute(A_SQLTYPE)
      IF sqlType.getIndexOf("DATE",1)=1 THEN 
        LET value=TODAY
        LET done=1
      END IF
    END IF
    IF NOT done AND attrExists(node,A_SAMPLE) THEN
      LET sample=node.getAttribute(A_SAMPLE)
      IF sample.getLength()=1 THEN
        FOR i=1 TO width
          LET value=value.append(sample)
        END FOR
        LET done=1
      END IF
    END IF
    IF NOT done THEN
      --fill with numbers
      FOR i=1 TO width
        LET value=value.append(i MOD 10)
      END FOR
    END IF
    CALL setValue(node,value)
  END IF
END FUNCTION

FUNCTION fillWithDate(node,width)
  DEFINE node om.DomNode
  DEFINE width INT
  DEFINE value STRING
  IF isDecoration(node) THEN
    IF width>=8 THEN
      LET value=TODAY
    END IF
    CALL setValue(node,value)
  END IF
END FUNCTION

FUNCTION fillWithChars(node,width,height)
  DEFINE node om.DomNode
  DEFINE width INT
  DEFINE height INT
  DEFINE parent om.DomNode
  DEFINE i,j,orda,ordz INT
  DEFINE value STRING
  LET parent=node.getParent()
  IF isDecoration(node) THEN
    IF attrExists(node,"fontPitch") THEN
      IF node.getAttribute("fontPitch")="fixed" THEN
        LET orda=ord('a')-1;
        LET ordz=ord('z')
        FOR j=1 TO height
          FOR i=1 TO width
            IF i>=(ordz-orda) THEN
              LET value=value.append(i MOD 10)
            ELSE
              LET value=value.append(ascii(orda+i))
            END IF
          END FOR
          IF j<>height THEN
            LET value=value.append("\n")
          END IF
        END FOR
      END IF
    END IF
    IF value.getLength()=0 THEN
      FOR j=1 TO height
        FOR i=1 TO width
          LET value=value.append(i MOD 10)
        END FOR
        IF j<>height THEN
          LET value=value.append("\n")
        END IF
      END FOR
    END IF
    CALL setValue(node,value)
  END IF
END FUNCTION

FUNCTION basename(pname)
  DEFINE pname STRING
  DEFINE basename,ext STRING
  LET basename=pname
  LET ext=file_extension(pname)
  IF ext=".per" OR ext=".42f" THEN
    LET basename=file_basename(pname,NULL)
  END IF
  RETURN basename
END FUNCTION

FUNCTION compile_form(fname,showmessage,proposals)
  DEFINE fname STRING
  DEFINE showmessage INT
  DEFINE proposals INT
  DEFINE dirname,cmd,mess,cparam,firstErrLine,line,srcname STRING
  DEFINE code,i,atidx INT
  LET dirname=file_get_dirname(fname)
LABEL compile_again:
  LET cparam="-c"
  IF proposals THEN
    LET cparam="-L"
    LET showmessage=0
  END IF
  IF NOT m_checked OR m_opt_cursor OR proposals THEN
    LET cparam=sfmt("%1 %2,%3",cparam,m_cline,m_ccol)
  ELSE
    LET cparam=""
  END IF

  IF file_on_windows() THEN
    LET cmd=sfmt("set FGLDBPATH=%1;%%FGLDBPATH%% && fglform %2 -M %3 2>&1",dirname,cparam,fname)
  ELSE
    LET cmd=sfmt("export FGLDBPATH=\"%1\":$FGLDBPATH && fglform %2 -M \"%3\" 2>&1",dirname,cparam,fname)
  END IF
  CALL compile_arr.clear()
  IF proposals THEN
    --DISPLAY "cmd=",cmd
  END IF
  IF NOT proposals THEN
    RUN cmd RETURNING code 
  END IF
  IF code OR proposals THEN
    LET code=file_get_output(cmd,compile_arr)
    IF (atidx:=fname.getIndexOf(".@",1))>0 THEN
      LET srcname=fname.subString(1,atidx-1),fname.subString(atidx+2,fname.getLength())
    ELSE
      LET srcname=fname
    END IF
    LET mess="Form compiling of '",srcname,"' failed:\n"
    FOR i=1 TO compile_arr.getLength()
      LET line=compile_arr[i]
      IF (atidx:=line.getIndexOf(".@",1))>0 THEN
        LET compile_arr[i]=line.subString(1,atidx-1),line.subString(atidx+2,line.getLength())
      END IF
      IF i=1 THEN
        LET firstErrLine=compile_arr[i]
      END IF
      LET mess=mess,compile_arr[i],"\n"
    END FOR
    IF NOT m_checked AND NOT proposals THEN
      LET m_checked=1
      IF firstErrLine.getIndexOf("Usage",1)=1 THEN
        -- the '-c' switch was unknown to fglform
        DISPLAY "!switch off cursor detection of fglform!"
        LET m_opt_cursor=0
        GOTO compile_again
      END IF
    END IF
    IF showmessage THEN
      CALL fgl_winmessage(S_ERROR,mess,IMG_ERROR)
    END IF
    RETURN mess
  END IF
  RETURN ""
END FUNCTION

FUNCTION checkFileSave(src,src_copy)
  DEFINE src STRING
  DEFINE src_copy STRING
  DEFINE ans STRING
  IF checkChanged(src,src_copy) THEN
    IF m_clientOnMac THEN --be mac specific
      LET ans=fgl_winbutton("fglped",sfmt("Do you want to save the changes you made in\nthe form \"%1\"?",m_title),"Save...","Don't Save|Cancel|Save...","question",0)
      CASE ans
        WHEN "Save..."    LET ans="yes"
        WHEN "Don't Save" LET ans="no"
        WHEN "Cancel"     LET ans="cancel"
      END CASE
    ELSE
      LET ans=fgl_winquestion("fglped",sfmt("Save changes to %1?",m_title),"yes","yes|no|cancel","question",0)
    END IF
    IF ans=="yes" THEN
      IF isNewFile() THEN
        LET m_srcfile=fglped_saveasdlg(m_srcfile)
        IF m_srcfile IS NULL THEN
          RETURN "cancel"
        END IF
      END IF
      CALL my_write(m_srcfile,src)
    END IF
  END IF
  RETURN ans
END FUNCTION


FUNCTION file_new()
  --RETURN "LAYOUT\nGRID\n{\nlabel[e      ]\n}\nEND\nATTRIBUTES\ne=formonly.e;\n"
  RETURN ""
END FUNCTION

FUNCTION setCurrForm(fname,tmpname)
  DEFINE fname,tmpname STRING
  LET m_srcfile=fname
  CALL delete_tmpfiles(tmpname)
  LET tmpname = getTmpFileName(m_srcfile,".per")
  CALL mysetTitle()
  RETURN tmpname
END FUNCTION


FUNCTION display_by_name_src(src)
  DEFINE src STRING
  CALL fgl_dialog_setbuffer(src)
END FUNCTION

FUNCTION doHighlight(src)
  DEFINE src STRING
  DEFINE elNode om.DomNode
  IF m_client_version<1.40 OR NOT isGDC() THEN
    RETURN
  END IF
  --DISPLAY "doHighlight begin"
  LET elNode=findCursorEl()
  IF elNode IS NOT NULL THEN
    CALL highlightNode(elNode)
    CALL eventuallyRaiseFolder(elNode)
  END IF
  --DISPLAY "doHighlight end "
END FUNCTION

FUNCTION previewForm(fname,src,cursor,showerror,opt)
  DEFINE fname STRING
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE showerror INT 
  DEFINE opt INT
  DEFINE code,i INT
  DEFINE compmess,postmess,cmd STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  IF file_write(fname,src) THEN
    CALL computeLineCol(src,cursor) RETURNING m_cline,m_ccol
    LET compmess=compile_form(fname,showerror,0)
    IF compmess IS NULL AND opt THEN
      LET cmd= "fglrun formpostproc ",fname,"_tmp"
      RUN cmd RETURNING code
      IF code THEN
        LET code=file_get_output(cmd,arr)
        LET postmess="Running postproc of '",fname,"' failed:\n"
        FOR i=1 TO arr.getLength()
          LET postmess=postmess,arr[i],"\n"
        END FOR
        IF showerror THEN
          CALL fgl_winmessage(S_ERROR,postmess,IMG_ERROR)
        END IF
        RETURN postmess
      END IF
    END IF
    IF compmess IS NULL THEN
      CALL showform(opt,NULL,TRUE,showerror)
      IF NOT m_showform_failed THEN
        LET m_error_line=NULL
      END IF
    ELSE 
      IF showerror THEN
        CALL show_compile_error(src,1,fname)
      END IF
    END IF
  ELSE 
    LET m_error_line=sfmt("Can't write to:%1",m_srcfile)
    IF showerror THEN
      CALL fgl_winmessage(S_ERROR,m_error_line,IMG_ERROR)
    END IF
  END IF
  RETURN compmess
END FUNCTION


--due to the space handling we are forced to work in buffered mode, otherwise appending a space at the end of the text at the client side is not possible
FUNCTION fetchSrc(src)
  DEFINE src STRING
  DEFINE c1,c2,clen INT
  LET c1=my_cursor()
  LET c2=my_getselend()
  LET clen=src.getLength()+1
  IF c1> clen OR c2 > clen  THEN
    --get the real client value and redisplay it together
    --with the current selection
    LET src=fgl_dialog_getbuffer() 
    CALL display_by_name_src(src)
    CALL my_setselection(c1,c2)
  END IF
  RETURN src
END FUNCTION

FUNCTION my_setselection(cursor,cursor2)
  DEFINE cursor INT
  DEFINE cursor2 INT
  --DISPLAY sfmt("fgl_dialog_setselection(%1,%2)",cursor,cursor2)
  CALL fgl_dialog_setselection(cursor,cursor2)
  --was CALL fgl_dialog_setcursor(cursor)
END FUNCTION

FUNCTION my_cursor()
  RETURN fgl_dialog_getcursor()
END FUNCTION

--once we have a library function supporting the selection end it can
--be called here
FUNCTION my_getselend()
  RETURN fgl_dialog_getSelectionEnd()
  --was RETURN fgl_dialog_getcursor()
END FUNCTION

--the usual 4GL function  to check if 2 strings are different
FUNCTION checkChanged(src,copy2)
  DEFINE src STRING
  DEFINE copy2 STRING
  IF ( copy2 IS NOT NULL  AND src IS NULL     ) OR 
     ( copy2 IS NULL      AND src IS NOT NULL ) OR 
     ( copy2<>src ) OR ( copy2.getLength()<>src.getLength() ) THEN
     RETURN 1
  END IF
  RETURN 0
END FUNCTION

FUNCTION my_write(fname,str)
  DEFINE fname STRING
  DEFINE str STRING
  IF NOT file_write(fname,str) THEN
    CALL fgl_winmessage(S_ERROR,sfmt("Can't write to:%1",fname),IMG_ERROR)
  END IF
END FUNCTION

--calls the form compiler in completion mode
--and makes some computations to present a display array with possible
--completion tokens
FUNCTION complete(src,fname,cursor,recurse)
  DEFINE src STRING
  DEFINE fname STRING
  DEFINE cursor INT
  DEFINE recurse INT
  DEFINE compmess STRING
  DEFINE proposal STRING
  DEFINE proparr DYNAMIC ARRAY OF RECORD
    proposal STRING,
    kind STRING
  END RECORD
  DEFINE tok base.StringTokenizer
  DEFINE i,j,start,end,curr,len,cursor3,dummy,proplen,end2 INT
  DEFINE found,srclen,didlookahead,changed,stringlit INT
  DEFINE sub,bef,src2,src3,word STRING
  LET srclen=src.getLength()
  CALL computeLineCol(src,cursor) RETURNING m_cline,m_ccol
  LET compmess=compile_form(fname,0,1)
  FOR i=1 TO compile_arr.getLength()
    LET proposal=compile_arr[i]
    IF proposal.getIndexOf("proposal",1)=1 THEN
      CALL proparr.appendElement()
      LET len=proparr.getLength()
      LET tok=base.StringTokenizer.create(proposal,"\t")
      LET j=1
      WHILE tok.hasMoreTokens() 
        LET sub=tok.nextToken()
        CASE j
          WHEN 2
            LET proparr[len].proposal=sub
            LET proposal=sub
          WHEN 3
            LET proparr[len].kind=sub
        END CASE
        LET j=j+1
      END WHILE
      --elminite duplicates
      LET len=len-1
      FOR j=1 TO len
        IF proparr[j].proposal=proposal THEN
          --DISPLAY "!!remove duplicate:",proposal
          CALL proparr.deleteElement(len+1)
          EXIT FOR
        END IF
      END FOR
    END IF
  END FOR
  IF proparr.getLength()=0 THEN
    RETURN src,cursor
  END IF
  LET int_flag=FALSE
  IF proparr.getLength()=1 THEN
    --check if we already have this token behind us
    LET proposal=proparr[1].proposal
    LET bef=src.subString(cursor-proposal.getLength(),cursor-1)
    IF bef=proposal AND isDelimiterChar(src.getCharAt(cursor)) AND
       NOT recurse THEN
      -- call the proposals again with an inserted space because we are at the
      -- end of a single proposal token, this prevents the user from having
      -- to type the space to get the proposals after this token
      CALL file_append(fname," ") RETURNING dummy
      LET src2=src.subString(1,cursor-1)," ",src.subString(cursor,src.getLength())
      CALL complete(src2,fname,cursor+1,1) RETURNING src3,cursor3
      IF (changed:=checkChanged(src3,src2)) OR cursor+1<>cursor3 THEN
        IF changed THEN
          LET src=src.subString(1,cursor-1),src3.subString(cursor,src3.getLength())
        END IF
        LET cursor=cursor3
        LET didlookahead=TRUE
      END IF
    END IF
    LET curr=1
  ELSE
    CALL close_sc_if_GBC()
    OPEN WINDOW proposals WITH FORM "fglped_proposals"
    CALL set_count(proparr.getLength())
    DISPLAY ARRAY proparr TO p.*
      ON KEY(UP) 
        IF arr_curr()=1 THEN
          CALL fgl_set_arr_curr(proparr.getLength())
        ELSE
          CALL fgl_set_arr_curr(arr_curr()-1)
        END IF
      ON KEY(DOWN) 
        IF arr_curr()=proparr.getLength() THEN
          CALL fgl_set_arr_curr(1)
        ELSE
          CALL fgl_set_arr_curr(arr_curr()+1)
        END IF
      --lengthy list of keys to enable one key typing of selecting a proposal
      ON KEY(a) IF curr:=findProposal(proparr,"a") THEN EXIT DISPLAY END IF
      ON KEY(b) IF curr:=findProposal(proparr,"b") THEN EXIT DISPLAY END IF
      ON KEY(c) IF curr:=findProposal(proparr,"c") THEN EXIT DISPLAY END IF
      ON KEY(d) IF curr:=findProposal(proparr,"d") THEN EXIT DISPLAY END IF
      ON KEY(e) IF curr:=findProposal(proparr,"e") THEN EXIT DISPLAY END IF
      ON KEY(f) IF curr:=findProposal(proparr,"f") THEN EXIT DISPLAY END IF
      ON KEY(g) IF curr:=findProposal(proparr,"g") THEN EXIT DISPLAY END IF
      ON KEY(h) IF curr:=findProposal(proparr,"h") THEN EXIT DISPLAY END IF
      ON KEY(i) IF curr:=findProposal(proparr,"i") THEN EXIT DISPLAY END IF
      ON KEY(j) IF curr:=findProposal(proparr,"j") THEN EXIT DISPLAY END IF
      ON KEY(k) IF curr:=findProposal(proparr,"k") THEN EXIT DISPLAY END IF
      ON KEY(l) IF curr:=findProposal(proparr,"l") THEN EXIT DISPLAY END IF
      ON KEY(m) IF curr:=findProposal(proparr,"m") THEN EXIT DISPLAY END IF
      ON KEY(n) IF curr:=findProposal(proparr,"n") THEN EXIT DISPLAY END IF
      ON KEY(o) IF curr:=findProposal(proparr,"o") THEN EXIT DISPLAY END IF
      ON KEY(p) IF curr:=findProposal(proparr,"p") THEN EXIT DISPLAY END IF
      ON KEY(q) IF curr:=findProposal(proparr,"q") THEN EXIT DISPLAY END IF
      ON KEY(r) IF curr:=findProposal(proparr,"r") THEN EXIT DISPLAY END IF
      ON KEY(s) IF curr:=findProposal(proparr,"s") THEN EXIT DISPLAY END IF
      ON KEY(t) IF curr:=findProposal(proparr,"t") THEN EXIT DISPLAY END IF
      ON KEY(u) IF curr:=findProposal(proparr,"u") THEN EXIT DISPLAY END IF
      ON KEY(v) IF curr:=findProposal(proparr,"v") THEN EXIT DISPLAY END IF
      ON KEY(w) IF curr:=findProposal(proparr,"w") THEN EXIT DISPLAY END IF
      ON KEY(x) IF curr:=findProposal(proparr,"x") THEN EXIT DISPLAY END IF
      ON KEY(y) IF curr:=findProposal(proparr,"y") THEN EXIT DISPLAY END IF
      ON KEY(z) IF curr:=findProposal(proparr,"z") THEN EXIT DISPLAY END IF
      ON KEY(',') IF curr:=findProposal(proparr,",") THEN EXIT DISPLAY END IF
      ON KEY('.') IF curr:=findProposal(proparr,".") THEN EXIT DISPLAY END IF
      ON KEY('(') IF curr:=findProposal(proparr,"(") THEN EXIT DISPLAY END IF
      ON KEY(')') IF curr:=findProposal(proparr,")") THEN EXIT DISPLAY END IF
      ON KEY(';') IF curr:=findProposal(proparr,";") THEN EXIT DISPLAY END IF
      ON KEY(':') IF curr:=findProposal(proparr,":") THEN EXIT DISPLAY END IF
      ON KEY('>') IF curr:=findProposal(proparr,">") THEN EXIT DISPLAY END IF
      ON KEY('<') IF curr:=findProposal(proparr,"<") THEN EXIT DISPLAY END IF
      ON KEY('@') IF curr:=findProposal(proparr,"@") THEN EXIT DISPLAY END IF
      ON KEY('!') IF curr:=findProposal(proparr,"!") THEN EXIT DISPLAY END IF
      ON KEY('[') IF curr:=findProposal(proparr,"[") THEN EXIT DISPLAY END IF
      ON KEY(']') IF curr:=findProposal(proparr,"]") THEN EXIT DISPLAY END IF
      ON KEY('=') IF curr:=findProposal(proparr,"=") THEN EXIT DISPLAY END IF
      ON KEY('*') IF curr:=findProposal(proparr,"*") THEN EXIT DISPLAY END IF
      --found problems on some versions with KEY -
      --ON KEY('-') IF curr:=findProposal(proparr,"-") THEN EXIT DISPLAY END IF
      ON KEY('%') IF curr:=findProposal(proparr,"%") THEN EXIT DISPLAY END IF
      ON ACTION accept 
        LET curr=arr_curr()
        EXIT DISPLAY
    END DISPLAY 
    CLOSE WINDOW proposals
  END IF
  IF NOT int_flag AND NOT didlookahead THEN
    LET proposal=proparr[curr].proposal
    IF proposal="string-literal" THEN
      LET proposal='""'
      LET proparr[curr].proposal=proposal
      LET stringlit=1
    END IF
    LET proplen=proposal.getLength()
    CALL findWord(src,cursor) RETURNING start,end
    IF proplen=1 OR stringlit THEN
      IF  findProposal(proparr,src.getCharAt(cursor)) THEN
        --jump over the single character
        IF stringlit THEN
          LET proposal='"'
          LET proplen=1
        END IF
        LET end=cursor+1
        LET start=cursor-1
      END IF
      IF recurse THEN
        LET start=start-1
      END IF
    ELSE 
      LET word=src.subString(start+1,end-1) CLIPPED
      LET end2=end
      LET found=1
      --look if we find a portion of the token we want to insert
      FOR i=1 TO word.getLength()
        IF i>proplen THEN
          LET found=0
          EXIT FOR
        END IF
        IF UPSHIFT(word.getCharAt(i))<>UPSHIFT(proposal.getCharAt(i)) THEN
          LET found=0
          EXIT FOR
        END IF
        LET end=start+i+1
      END FOR
      IF NOT found THEN
        IF findProposalString(proparr,word) THEN
          --replace the current word
          LET end=end2
        ELSE
          IF i=proplen+1 THEN
            --there is our keyword part first inside the word were on
            --just move the cursor to the last position
            LET cursor=start+proplen+1
            RETURN src,cursor
          ELSE
            --last resort, just insert the token before the cursor
            LET end=cursor
          END IF
        END IF
      END IF
    END IF
    IF NOT found AND
      end<=cursor AND (src.getCharAt(end)=" " OR src.getCharAt(end)="\n") THEN
      --check if the next word is the proposal we try to insert
      --and if yes,jump over it
      LET end2=end
      WHILE (src.getCharAt(end2)=" " OR src.getCharAt(end2)="\n")
        LET end2=end2+1
      END WHILE
      LET found=1
      FOR i=1 TO proplen
        IF end2+i-1>srclen THEN
          LET found=0
          EXIT FOR
        END IF
        IF UPSHIFT(src.getCharAt(end2+i-1))<>UPSHIFT(proposal.getCharAt(i)) THEN
          LET found=0
          EXIT FOR
        END IF
      END FOR
      IF found AND isDelimiterChar(src.getCharAt(end2+proplen)) THEN
        --only move the cursor
        LET cursor=end2+proplen
        RETURN src,cursor
      END IF
    END IF
    LET src=src.subString(1,start),proposal,src.subString(end,src.getLength())
    LET cursor=start+proposal.getLength()+1
    IF stringlit AND proplen=2 THEN
      LET cursor=cursor-1
    END IF
  END IF --NOT int_flag
  RETURN src,cursor
END FUNCTION

FUNCTION findProposal(proparr,c)
  DEFINE proparr DYNAMIC ARRAY OF RECORD
    proposal STRING,
    kind STRING
  END RECORD
  DEFINE c CHAR(1)
  DEFINE i,len,currRow,idx,firstOcc,numFound INT
  DEFINE proposal STRING
  LET len=proparr.getLength()
  LET currRow=arr_curr()
  FOR i=1 TO len
    LET idx=((len+currRow+i-1) MOD len)+1
    LET proposal=proparr[idx].proposal
    IF UPSHIFT(proposal.getCharAt(1))==UPSHIFT(c) THEN
      IF NOT firstOcc THEN
        LET firstOcc=idx
        LET numFound=1
      ELSE
        LET numFound=numFound+1
      END IF
    END IF
  END FOR
  IF numFound>0 THEN
    CALL fgl_set_arr_curr(firstOcc)
    IF numFound=1 THEN
      RETURN firstOcc
    END IF
  END IF
  RETURN 0
END FUNCTION

FUNCTION findProposalString(proparr,s)
  DEFINE proparr DYNAMIC ARRAY OF RECORD
    proposal STRING,
    kind STRING
  END RECORD
  DEFINE s STRING
  DEFINE i,len INT
  DEFINE proposal STRING
  LET len=proparr.getLength()
  FOR i=1 TO len
    LET proposal=proparr[i].proposal
    IF UPSHIFT(proposal)==UPSHIFT(s) THEN
      RETURN TRUE
    END IF
  END FOR
  RETURN FALSE
END FUNCTION


--returns the begin and end of the word the cursor is over
FUNCTION findWord(src,cursor)
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE leftIdx,rightIdx,i,len INT 
  FOR i=cursor-1 TO 1 STEP -1
    IF isDelimiterChar(src.getCharAt(i)) THEN
      --DISPLAY "leftIdx:",i,",char:",printChar(src.getCharAt(i))
      LET leftIdx=i
      EXIT FOR
    END IF
  END FOR 
  LET len=src.getLength()
  LET rightIdx=len+1
  FOR i=cursor TO len 
    IF isDelimiterChar(src.getCharAt(i)) THEN
      --DISPLAY "rightIdx:",i,",char:",printChar(src.getCharAt(i))
      LET rightIdx=i
      EXIT FOR
    END IF
  END FOR 
  RETURN leftIdx,rightIdx
END FUNCTION

{ --for debugging only
FUNCTION quote(c)
  DEFINE c CHAR(1)
  CASE c
    WHEN "\n"
      LET c="\\n"
    WHEN "\r"
      LET c="\\r"
    WHEN "\t"
      LET c="\\t"
    WHEN "\\"
      LET c="\\"
    WHEN "\""
      LET c="\\\""
  END CASE
  RETURN c
END FUNCTION

FUNCTION printChar(c)
  DEFINE c CHAR(1)
  RETURN quote(c)
END FUNCTION
}

--computes the temporary .per file name to work with during our manipulations
FUNCTION getTmpFileName(fname,ext)
  DEFINE fname STRING
  DEFINE ext STRING
  DEFINE tmpname STRING
  DEFINE dir,shortname STRING
  IF fname IS NULL THEN
    LET tmpname=".@__empty__",ext
  ELSE
    LET dir=file_get_dirname(fname)
    LET shortname=file_get_short_filename(fname)
    LET tmpname=file_join(dir,sfmt(".@%1",shortname))
    LET tmpname=basename(tmpname),ext
  END IF
  RETURN tmpname
END FUNCTION

--shows a form in the 'sc' window
--if refresh is 1, the window is recreated otherwise the form is
--loaded via XML into the existing window
FUNCTION showform(opt,otherform,refresh,previewaction)
  DEFINE opt INT
  DEFINE otherform,tmpDir STRING
  DEFINE refresh INT
  DEFINE previewaction INT
  DEFINE pstyle,ff STRING
  DEFINE winNode,fNode,curr om.DomNode
  LET m_showform_failed=0
  IF otherform IS NOT NULL THEN
    LET ff=otherform
  ELSE
    IF opt THEN 
      LET ff = m_srcfile,"_tmp_ext"
    ELSE
      LET ff = getTmpFileName(m_srcfile,".42f")
    END IF
  END IF
  CALL highlightNode(NULL)
  IF isGBC() THEN
    LET pstyle=S_PREVIEW_GBC
  ELSE
    LET pstyle=S_PREVIEW
  END IF
  IF NOT m_sc_open OR isGBC() THEN
    --recreate the 'sc' window
    IF m_sc_open THEN
      CALL close_sc_window()
    END IF
    --OPEN WINDOW sc WITH FORM ff ATTRIBUTES(style=S_PREVIEW)
    OPEN WINDOW sc AT 0,0 WITH 25 ROWS, 60 COLUMNS ATTRIBUTES(style=pstyle)
    IF m_showWeb THEN
      OPEN FORM theform FROM "fglped_webpreview"
    ELSE
      OPEN FORM theform FROM ff
    END IF
    DISPLAY FORM theform
    LET m_sc_open=1
    LET winNode=getWindowNode("sc")
    --patch over our preview style to get the previous position on the screen
    --and no decoration
    CALL winNode.setAttribute(A_STYLE,pstyle)
    CALL winNode.setAttribute("text",sfmt("Preview of:%1",m_title))
    LET fNode = getFormNode(winNode)
    CALL fNode.setAttribute(A_STYLE,pstyle)
    CALL fNode.setAttribute(A_VERSION,m_formVersion)
  ELSE
    --just load the form into the existing window
    CURRENT WINDOW IS sc
    CLOSE FORM theform
    IF m_showWeb THEN
      OPEN FORM theform FROM "fglped_webpreview"
    ELSE
      LET fNode=loadForm(ff,"sc",pstyle)
      IF fNode IS NULL THEN
        LET m_showform_failed=1
        LET m_error_line="Can't load :",ff
        LET fNode=m_formNode
      END IF
      CALL fNode.setAttribute(A_VERSION,m_formVersion)
      LET winNode = fNode.getParent()
    END IF
  END IF
  IF m_showWeb THEN
    LET tmpDir=fgl_getenv("TMPDIR")
    LET m_tmpWebForm=os.Path.join(tmpDir,sfmt("fglpedtmp%1.42f",fgl_getpid()))
    IF NOT os.Path.copy(ff,m_tmpWebForm) THEN
      DISPLAY "Can't copy:",ff
    ELSE
      IF NOT checkGASInt() THEN
        DISPLAY "Can't start GAS or create GAS entry"
        LET m_showWeb=FALSE
      END IF
    END IF
  END IF
  IF NOT m_formedit AND NOT isGBC() THEN
    --activate the formedit click extension if available
    WHENEVER ERROR CONTINUE
    CALL ui.Interface.frontcall("formedit","edit",[winNode.getId(),1],[])
    LET m_formedit=1
    WHENEVER ERROR STOP
  END IF

  IF previewaction AND (NOT isGDC()) THEN
    DISPLAY "createPreview"
    MENU "Preview"
      COMMAND KEY(escape)
      ON ACTION myclose --ATTRIBUTE(TEXT="Close (Escape)",ACCELERATOR="Escape")
        EXIT MENU
    END MENU
    RETURN
  END IF

  IF m_infiledlg THEN
    CURRENT WINDOW IS __filedialog
  ELSE
    CURRENT WINDOW IS screen
  END IF
  IF m_showWeb THEN --leave out some mark up
    RETURN
  END IF
  LET m_formNode=fNode
  --uncomment the following line to see some data inside the form
  IF m_toggle_text THEN
    CALL recursiveSetText(fNode)
  END IF
  LET m_formVersion=m_formVersion+1
  CALL setSizeInTables(fNode)
  LET curr=find_fglform_current()
  IF curr IS NOT NULL THEN
    CALL highlightNode(curr)
    CALL eventuallyRaiseFolder(curr)
  END IF
END FUNCTION

--close the 'sc' window, only used for GBC
FUNCTION close_sc_window()
  DEFINE winNode om.DomNode
  IF m_sc_open THEN
    IF m_formedit THEN
      CALL highlightNode(NULL)
      LET winNode=getWindowNode("sc")
      WHENEVER ERROR CONTINUE
      CALL ui.Interface.frontcall("formedit","edit",[winNode.getId(),0],[])
      WHENEVER ERROR STOP
      LET m_formedit=0
    END IF
    --IF m_init=0 THEN
      --CALL manipulatePreviewStyle()
      --CALL fgl_refresh()
      --LET m_init=1
    --END IF
    IF isGBC() THEN
      CLOSE WINDOW sc
      LET m_sc_open=0
    END IF
    CURRENT WINDOW IS screen
    CALL fgl_refresh()
  END IF
END FUNCTION

FUNCTION close_sc_if_GBC()
  IF NOT isGBC() THEN 
    RETURN
  END IF
  CALL close_sc_window()
END FUNCTION

--returns the corresponding window node to a given window name
--from the AUI tree
FUNCTION getWindowNode(windowName)
  DEFINE windowName STRING
  DEFINE doc om.DomDocument
  DEFINE nl om.NodeList
  DEFINE rootNode om.DomNode

  LET doc =ui.Interface.getDocument()
  LET rootNode=ui.Interface.getRootNode()
  LET nl = rootNode.selectByPath(sfmt("//Window[@name=\"%1\"]",windowName))
  IF nl.getLength()=0 THEN
    DISPLAY "ERROR :getWindowNode:could not find Window named:",windowName
    RETURN NULL
  END IF
  RETURN  nl.item(1)
END FUNCTION

--returns the corresponding active Form Node of a given AUI window node
FUNCTION getFormNode(winNode)
  DEFINE winNode om.DomNode
  DEFINE nl om.NodeList
  LET nl = winNode.selectByPath("//Form")
  IF nl.getLength()=0 THEN
    DISPLAY "ERROR :getFormNode:could not find Form"
    RETURN NULL
  END IF
  RETURN nl.item(1)
END FUNCTION

--loads the form into the window named with windowName
FUNCTION loadForm(ff,windowName,pstyle)
  DEFINE ff STRING
  DEFINE windowName STRING
  DEFINE pstyle STRING
  DEFINE oldFormNode om.DomNode
  DEFINE winNode,fNode om.DomNode
  --DEFINE node,vl,va om.DomNode
  --DEFINE nl,nl2 om.NodeList
  --DEFINE i,j,pageSize INT
  DEFINE w ui.Window
  DEFINE f ui.Form
  LET winNode=getWindowNode(windowName)
  LET oldFormNode = getFormNode(winNode)
  CALL winNode.removeChild(oldFormNode)
  OPEN FORM theform FROM ff
  DISPLAY FORM theform
  LET w=ui.Window.forName(windowName)
  LET f = w.getForm()
  LET fNode=f.getNode()
  --LET fNode=winNode.loadXML(ff)
  IF fNode IS NULL THEN
    DISPLAY "ERROR : Can't load:",ff
    IF NOT file_exists(ff) THEN
      DISPLAY "file:",ff," does not exist"
    END IF
    RETURN NULL
  END IF

  --fill in matrix valuelist nodes manually
  {
  LET nl = fNode.selectByPath("//Matrix")
  FOR i=1 TO nl.getLength()
    LET node=nl.item(i)
    LET nl2=node.selectByPath("//ValueList")
    IF nl2.getLength()=0 THEN
      LET pageSize=node.getAttribute("pageSize")
      LET vl=node.createChild("ValueList")
      FOR j=1 TO pageSize
        LET va=vl.createChild("Value")
        CALL va.setAttribute(A_VALUE,"")
      END FOR
    END IF
  END FOR
  }
  --patch the title
  IF attrExists(fnode,"text") THEN
    CALL winNode.setAttribute("text",fnode.getAttribute("text"))
  END IF
  CALL winNode.setAttribute(A_STYLE,pstyle)
  IF fNode.getAttribute(A_STYLE) IS NULL THEN
    CALL fNode.setAttribute(A_STYLE,pstyle)
  END IF
  RETURN fNode
END FUNCTION

FUNCTION setSizeInTables(fNode)
  DEFINE fNode om.DomNode
  DEFINE node om.DomNode
  DEFINE nl om.NodeList
  DEFINE i INT
  LET nl = fNode.selectByPath("//Table")
  FOR i=1 TO nl.getLength()
    LET node=nl.item(i)
    CALL node.setAttribute("size",node.getAttribute("pageSize"))
  END FOR
END FUNCTION

--raise the folder(s) where the current element is inside
--there are people which have folders inside folders...
--however I treat this as a "GUI blooper"
FUNCTION eventuallyRaiseFolder(curr)
  DEFINE curr om.DomNode
  --DEFINE parent,page,folder,child om.DomNode
  --DEFINE winNode
  DEFINE parent,fnode om.DomNode
  DEFINE f ui.Form
  DEFINE w ui.Window
  DEFINE raiseName STRING
  LET parent=curr.getParent()
  --DISPLAY "eventuallyRaiseFolder curr:",curr.getTagName(),",parent:",parent.getTagName()
  WHILE parent IS NOT NULL
    IF parent.getTagName()="Page" THEN
      LET m_raiseId=m_raiseId+1
      LET raiseName=sfmt("raiseId%1",m_raiseId)
      CALL parent.setAttribute("name",raiseName)
      CURRENT WINDOW IS sc
      --CALL fgl_refresh()
      --LET winNode=getWindowParent(parent)
      LET w=ui.Window.forName("sc")
      LET f = w.getForm()
      LET fnode=f.getNode()
      --DISPLAY "ensureVisible:",raiseName,",id:",parent.getId(),",form id:",fnode.getId()
      --for debug
      --CALL f.setElementText(raiseName,raiseName)
      CALL f.ensureElementVisible(raiseName)
      CALL fgl_refresh()
      CURRENT WINDOW IS screen
      EXIT WHILE
    END IF
    LET parent=parent.getParent()
  END WHILE
END FUNCTION

FUNCTION getWindowParent(curr)
  DEFINE curr om.DomNode
  DEFINE parent om.DomNode
  LET parent=curr.getParent()
  WHILE parent IS NOT NULL 
    IF parent.getTagName()="Window" THEN
      RETURN parent
    END IF
    LET parent=parent.getParent()
  END WHILE
  RETURN NULL
END FUNCTION

--displays the first error in the status line with the compile errors
--returns the error line
FUNCTION show_compile_error(txt,jump,fname)
  DEFINE txt STRING
  DEFINE jump INT
  DEFINE fname STRING
  DEFINE idx INT
  DEFINE firstcolon,secondcolon,thirdcolon,linenum,c,start INT
  DEFINE line,col,linenumstr STRING
  LET idx=1
  LET m_error_line=""
  IF idx>compile_arr.getLength() OR idx<1 THEN
    RETURN 
  END IF
  WHILE idx<=compile_arr.getLength() AND idx>0 
    LET line=compile_arr[idx]
    LET start=1
    IF (firstcolon:=line.getIndexOf(":",1))>0 AND firstcolon=2 AND
        line.getCharAt(3)="\\" THEN
      --exclude drive letters under windows
      LET start=3
    END IF
    IF (firstcolon:=line.getIndexOf(":",start))>0 THEN
      LET secondcolon=line.getIndexOf(":",firstcolon+1)
      LET thirdcolon=line.getIndexOf(":",secondcolon+1)
      IF secondcolon>firstcolon THEN
        LET linenumstr=line.subString(firstcolon+1,secondcolon-1)
        LET col=line.subString(secondcolon+1,thirdcolon-1)
        LET linenum=linenumstr
        IF linenum>0 OR (linenumstr="0" AND 
                         line.getIndexOf("expecting",1)<>0) THEN
          LET line=line.subString(firstcolon,line.getLength())
          LET m_error_line=line
          MESSAGE m_error_line
          IF linenumstr="0" THEN 
            LET linenum=1
          END IF
          IF jump THEN
            CALL jump_to_line(txt,linenum,col,1) RETURNING c
          END IF
          RETURN 
        END IF
      END IF
      EXIT WHILE
    END IF
    LET idx=idx+1
  END WHILE
END FUNCTION
  
FUNCTION jump_to_line(txt,linenum,col,setcursor)
  DEFINE txt STRING
  DEFINE linenum INT
  DEFINE col INT
  DEFINE setcursor INT
  DEFINE currline,idx,old INT
  DISPLAY "jump_to_line linenum:",linenum,",col:",col,",setcursor:",setcursor
  LET old=1
  LET currline=1
  WHILE (idx:=txt.getIndexOf("\n",old))<>0 AND currline<linenum AND idx<txt.getLength()
    LET old=idx+1
    LET currline=currline+1
  END WHILE
  IF currline=linenum THEN 
    IF col=0 THEN 
      LET col=1
    END IF
    IF setcursor THEN
      CALL my_setcursor(old+col-1)
    END IF
    RETURN (old+col-1)
  END IF
  RETURN 0
END FUNCTION

FUNCTION computeLineCol(txt,cursor)
  DEFINE txt STRING
  DEFINE cursor,idx,old,col,currline INT

  LET old=1
  LET currline=1
  WHILE (idx:=txt.getIndexOf("\n",old))<>0 AND idx<txt.getLength()
    IF idx>=cursor THEN
      LET col=cursor-old+1
      RETURN currline,col
    END IF
    LET currline=currline+1
    LET old=idx+1
  END WHILE
  LET col=cursor-old+1
  RETURN currline,col
END FUNCTION

--retrieves the clicked node from the client ,
--figure out the postition in the .per and jump with the cursor to that position
FUNCTION getSel(src)
  DEFINE src STRING
  DEFINE c STRING
  DEFINE node,vl,vlContainer om.DomNode
  DEFINE doc om.DomDocument
  DEFINE arr DYNAMIC ARRAY OF INT
  DEFINE linenum,col,ret,line2,col2,i,matrixIndex,mOff,selnodeId INT
  DEFINE selend INT
  DEFINE selType STRING
  LET selnodeId = -1
  WHENEVER ERROR CONTINUE
  CALL ui.Interface.frontCall("formedit","getclickednode",[],[selnodeId])
  WHENEVER ERROR STOP
  LET doc  =ui.Interface.getDocument()
  LET node =doc.getElementById(selnodeId)
  IF node IS NULL THEN
    RETURN 0
  END IF
  CASE node.getTagName()
    WHEN "FormField" 
      LET node=node.getFirstChild()
    WHEN "TableColumn" 
      LET node=node.getFirstChild()
    WHEN "Value" 
      LET vl=node.getParent()
      LET vlContainer=vl.getParent()
      IF vlContainer.getTagName()="Matrix" THEN
        FOR i=1 TO vl.getChildCount()
          IF vl.getChildByIndex(i)=node THEN
            LET matrixIndex=i
            EXIT FOR
          END IF
        END FOR
      END IF
      LET node=vlContainer.getFirstChild()
    WHEN "Item" 
      LET vl=node.getParent()
      LET vlContainer=vl.getParent()
      IF vlContainer.getTagName()="FormField" THEN
        LET node=vlContainer.getFirstChild()
      END IF
  END CASE
  --DISPLAY "node:",node.getTagName(),",tag:",node.getAttribute("tag")
  CALL highlightNode(node)

  IF (seltype:=parseTag(node,arr)) IS NULL THEN
    RETURN 0
  END IF

  IF matrixIndex>1 THEN
    LET mOff=matrixIndex*4
  END IF
  LET linenum = arr[mOff + 1]
  LET col     = arr[mOff + 2]
  LET line2   = arr[mOff + 3]
  LET col2    = arr[mOff + 4]

  LET ret=jump_to_line(src,linenum,col,1)
  IF ret>0 THEN
    LET c=src.getCharAt(ret)
    IF c="[" OR c="<" OR c="|" THEN
      LET ret=ret+1
      LET col2=col2-1
    END IF
    IF selType.getCharAt(1)="B" THEN
      CALL my_setselection(ret,ret+col2-col)
    ELSE
      LET selend=jump_to_line(src,line2,col2,0)+1
      CALL my_setselection(ret,selend)
    END IF
  END IF
  RETURN ret
END FUNCTION

--parses the "tag" attribute filled in by the form compiler in the special
--cursor mode (-c option)
FUNCTION parseTag(node,arr)
  DEFINE node om.DomNode
  DEFINE arr DYNAMIC ARRAY OF INT
  DEFINE tag STRING
  DEFINE sub STRING
  DEFINE idx,i INT
  DEFINE blockOrLineSel CHAR(1)
  DEFINE tok base.StringTokenizer
  DEFINE posarr DYNAMIC ARRAY OF STRING
  DEFINE pos INT
  DEFINE ret STRING
  LET tag=node.getAttribute("tag")
  IF tag IS NULL OR tag.getLength()=0 THEN
    RETURN NULL
  END IF
  IF tag.getIndexOf(",",1)>0 THEN
    LET tok=base.StringTokenizer.create(tag,",")
    WHILE  tok.hasMoreTokens() 
      LET pos=pos+1
      LET posarr[pos]=tok.nextToken()
    END WHILE
  ELSE
    LET posarr[1]=tag
    LET pos=1
  END IF
  FOR i=1 TO pos
    LET sub=posarr[i]

    LET blockOrLineSel=sub.getCharAt(1)
    LET ret=ret,blockOrLineSel
    LET sub=sub.subString(2,sub.getLength())
    LET tok=base.StringTokenizer.create(sub,":")
    WHILE(tok.hasMoreTokens())
      LET idx=idx+1
      LET arr[idx]=tok.nextToken()
    END WHILE
    IF arr.getLength() MOD 4!=0 THEN
      DISPLAY "ERROR:can't parse tag:",tag,"  for Node:",node.getTagName()
    ELSE
  END IF
  END FOR
  --DISPLAY "parseTag: ret is:'",ret,"'"
  --FOR i=1 TO arr.getLength()
  --  DISPLAY "  ",arr[i]
  --END FOR
  RETURN ret
END FUNCTION

--looks if the form compiler marked an element with the special 
--'fglform_current' style indicating that this was the element the cursor 
--was over may be we need to review this to be able to detect 'fglform_current'
--in thestyle string together with other (already existing) styles 
--separated by whitespace
FUNCTION find_fglform_current()
  DEFINE node om.DomNode
  DEFINE nl om.NodeList
  --search the * style
  IF m_formNode IS NULL THEN
    RETURN NULL
  END IF
  LET nl=m_formNode.selectByPath("//*[@style=\"fglform_current\"]")
  IF nl.getLength()>0 THEN
    LET node=nl.item(1)
  ELSE
  END IF
  RETURN node
END FUNCTION

--highlights a node at the client side thru a front call
FUNCTION highlightNode(node)
  DEFINE node om.DomNode
  DEFINE id,tag STRING
  DEFINE parent om.DomNode
  --DEFINE child om.DomNode
  DEFINE starttime DATETIME YEAR TO FRACTION(3)
  DEFINE endv INTERVAL HOUR TO FRACTION(3)
  IF NOT isGDC() THEN
    RETURN
  END IF
  IF node IS NULL THEN
    LET id=""
  ELSE
    LET parent=node.getParent()
    LET tag=node.getTagName()
    IF parent.getTagName()="FormField" AND 
      (tag="ComboBox" OR tag="ButtonEdit" OR tag="DateEdit") THEN
      LET node=parent
    END IF
    LET id=sfmt("%1",node.getId())
  END IF
  WHENEVER ERROR CONTINUE
  --here the GDC on MacOSX has problems in certain situations, the frontcall
  --lasts very long, seems a Qt socket problem when writing back to the VM
  --in the lib
  LET starttime=CURRENT
  CALL ui.Interface.frontCall("formedit","setselectednodes",[id],[])
  LET endv=CURRENT - starttime
  IF endv > INTERVAL (0:00:00.100) HOUR(2) TO FRACTION(3) THEN
    DISPLAY "setselectednode frontcall duration:",endv
  END IF
  WHENEVER ERROR STOP
END FUNCTION

FUNCTION my_setcursor(pos)
  DEFINE pos INT
  CALL fgl_dialog_setcursor(pos)
END FUNCTION

FUNCTION findCursorEl()
  DEFINE matchNode om.DomNode
  --call recursively the internal function until the closest
  --cursor match
  IF m_formNode IS NULL THEN
    RETURN NULL
  END IF
  LET matchNode=findCursorElInt(m_formNode,m_formNode)
  RETURN matchNode 
END FUNCTION

--checks if the the cursor pos is inside the given area of a tag
FUNCTION checkLexLoc(node,selChar,first_line,first_col,last_line,last_col)
  DEFINE node om.DomNode
  DEFINE selChar STRING
  DEFINE first_line,first_col,last_line,last_col INT
  DEFINE matchLines,matchCols INT
  IF first_line <= m_cline AND last_line >= m_cline THEN
    LET matchLines=1
  END IF
  IF  selChar="B" THEN
    IF first_col<=m_ccol AND last_col >=m_ccol THEN
      LET matchCols=1
    END IF
  ELSE 
    IF matchLines THEN
      IF (first_col>m_ccol AND first_line=m_cline) OR
         (last_col<m_ccol AND last_line=m_cline) THEN
         LET matchCols=0
      ELSE
        LET matchCols=1
      END IF
    END IF
  END IF
  IF matchLines AND matchCols THEN
    RETURN 1
  END IF
  RETURN 0
END FUNCTION

FUNCTION findCursorElInt(node,matchNode)
  DEFINE node om.DomNode
  DEFINE matchNode om.DomNode
  DEFINE ch,matchChild om.DomNode
  DEFINE arr DYNAMIC ARRAY OF INT
  DEFINE seltype STRING
  DEFINE i,idx INT
  IF (seltype:=parseTag(node,arr)) IS NOT NULL THEN
    FOR i=1 TO seltype.getLength()
      LET idx=1+ ((i-1)*4) 
      IF checkLexLoc(node,selType.getCharAt(i),arr[idx],arr[idx+1],arr[idx+2],arr[idx+3]) THEN
        LET matchNode=node
      END IF
    END FOR
  END IF
  LET ch=node.getFirstChild()
  WHILE ch IS NOT NULL
    IF (matchChild:=findCursorElInt(ch,matchNode)) IS NOT NULL THEN
      IF matchChild<>matchNode THEN
        --don't search further siblings
        LET matchNode=matchChild
        EXIT WHILE
      END IF
    END IF
    LET ch=ch.getNext()
  END WHILE
  RETURN matchNode
END FUNCTION

FUNCTION mysetTitle()
  IF isNewFile() THEN
    LET m_title="Unnamed"
  ELSE
    LET m_title=file_get_short_filename(m_srcfile)
  END IF
  CALL fgl_setTitle(sfmt("%1 - fglped",m_title))
END FUNCTION

FUNCTION enable_history(d,enable)
  DEFINE d ui.Dialog
  DEFINE enable SMALLINT
  CALL d.setActionActive("history_show",enable)
  CALL d.setActionActive("history_down",enable)
  CALL d.setActionActive("history_up",enable)
END FUNCTION

FUNCTION do_find(src,cursor,selend)
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE selend INT
  DEFINE found,idxhist,idxfound Integer
  CALL close_sc_if_GBC()
  OPEN WINDOW search WITH FORM "fglped_search"
  CALL fgl_settitle("Search text")
  IF srch_updown IS NULL OR srch_updown.getLength()=0 THEN
    LET srch_updown="Down"
  END IF
  INPUT BY NAME srch_search, srch_wholeword, srch_matchcase, srch_updown WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED)
    BEFORE INPUT
      CALL dialog.setActionHidden("history_show",1)
      CALL dialog.setActionHidden("history_down",1)
      CALL dialog.setActionHidden("history_up",1)
      CALL enable_history(DIALOG,0)
    BEFORE FIELD srch_search
      CALL enable_history(DIALOG,1)
    AFTER FIELD srch_search
      CALL enable_history(DIALOG,0)
    ON ACTION history_up 
      CALL history_up(srch_hist_arr,idxhist,srch_search) RETURNING srch_search,idxhist 
    ON ACTION history_down 
      CALL history_down(srch_hist_arr,idxhist,srch_search) RETURNING srch_search,idxhist 
    ON ACTION history_show 
      CALL history_show(srch_hist_arr,idxhist,srch_search) RETURNING srch_search,idxhist
    ON ACTION accept
      CALL text_search(src,cursor,FALSE,TRUE) RETURNING found,idxfound
      IF found=0 THEN
        CONTINUE INPUT
      ELSE
        CALL history_insert(srch_hist_arr,srch_search)
        EXIT INPUT
      END IF
  END INPUT
  CLOSE WINDOW search
  IF found THEN
    CALL my_setselection(idxfound,idxfound+srch_search.getLength())
  END IF
END FUNCTION

FUNCTION do_findnext(src,cursor)
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE found, idxfound Integer
  IF srch_updown IS NULL OR srch_updown.getLength()=0 THEN
    LET srch_updown="Down"
  END IF
  CALL text_search(src,cursor,TRUE,TRUE) RETURNING found,idxfound
END FUNCTION

FUNCTION do_replace(src,cursor,selend)
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE selend INT
  DEFINE found,idxfound Integer
  DEFINE idxhist_search,idxhist_repl Integer
  CALL close_sc_if_GBC()
  OPEN WINDOW search WITH FORM "fglped_replace"
  LET srch_replaceall=0
  INPUT BY NAME srch_search, srch_replace, srch_wholeword, srch_matchcase, srch_replaceall WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED)
    BEFORE INPUT
      CALL dialog.setActionHidden("history_show",1)
      CALL dialog.setActionHidden("history_down",1)
      CALL dialog.setActionHidden("history_up",1)
      CALL enable_history(DIALOG,0)
    BEFORE FIELD srch_search
      CALL enable_history(DIALOG,1)
    AFTER FIELD srch_search
      CALL enable_history(DIALOG,0)
    BEFORE FIELD srch_replace
      CALL enable_history(DIALOG,1)
    AFTER FIELD srch_replace
      CALL enable_history(DIALOG,0)
    ON ACTION history_up 
      IF INFIELD(srch_search) THEN
        CALL history_up(srch_hist_arr,idxhist_search,srch_search) RETURNING srch_search,idxhist_search 
      ELSE IF INFIELD(srch_replace) THEN
        CALL history_up(srch_repl_arr,idxhist_repl,srch_replace) RETURNING srch_replace,idxhist_repl 
      END IF END IF
    ON ACTION history_down 
      IF INFIELD(srch_search) THEN
        CALL history_down(srch_hist_arr,idxhist_search,srch_search) RETURNING srch_search,idxhist_search 
      ELSE IF INFIELD(srch_replace) THEN
        CALL history_down(srch_repl_arr,idxhist_repl,srch_replace) RETURNING srch_replace,idxhist_repl 
      END IF END IF
    ON ACTION history_show 
      IF INFIELD(srch_search) THEN
        CALL history_show(srch_hist_arr,idxhist_search,srch_search) RETURNING srch_search,idxhist_search
      ELSE IF INFIELD(srch_replace) THEN
        CALL history_show(srch_repl_arr,idxhist_repl,srch_replace) RETURNING srch_replace,idxhist_repl
      END IF END IF
    ON ACTION accept
      LET srch_updown="Down"
      CALL text_search(src,cursor,FALSE,TRUE) RETURNING found,idxfound
      IF found=0 THEN
        CONTINUE INPUT
      ELSE
        
        CALL history_insert(srch_hist_arr,srch_search)
        CALL history_insert(srch_repl_arr,srch_replace)
        EXIT INPUT
      END IF
  END INPUT
  CLOSE WINDOW search
  IF found THEN
    CALL replace_int(src,idxfound)
  END IF
END FUNCTION

--replaces with srch_replace if the current position matches with
--srch_search
FUNCTION do_replaceagain(src, cursor,selend)
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE selend INT
  IF getIndexOfI(src,srch_search,cursor)=cursor THEN
    CALL replace_int(src,cursor)
  END IF
END FUNCTION

FUNCTION replace_int(src,start)
  DEFINE src STRING
  DEFINE start INT
  DEFINE end INT
  LET m_replace_src=src
  LET m_replace_cursor=start
  LET end=start+srch_search.getLength()
  LET src=src.subString(1,start-1),srch_replace,src.subString(end,src.getLength())
  CALL display_by_name_src(src)
  CALL fgl_dialog_setcursor(start+srch_replace.getLength())
END FUNCTION

FUNCTION do_finddef(src,cursor)
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE elNode om.DomNode
  DEFINE arr DYNAMIC ARRAY OF INT
  DEFINE i,idx,line,col INT
  DEFINE seltype STRING
  CALL computeLineCol(src,cursor) RETURNING m_cline,m_ccol
  LET elNode=findCursorEl()
  IF elNode IS NULL THEN
    RETURN
  END IF
  IF (seltype:=parseTag(elNode,arr)) IS NULL THEN
    RETURN 
  END IF
  FOR i=1 TO seltype.getLength()
    LET idx=1+ ((i-1)*4) 
    IF checkLexLoc(elNode,selType.getCharAt(i),arr[idx],arr[idx+1],arr[idx+2],arr[idx+3]) THEN
      CONTINUE FOR
    END IF
    --IF selType.getCharAt(i)="L" THEN
    LET line=arr[idx]
    LET col=arr[idx+1]
    IF selType.getCharAt(i)="B" THEN
      LET col=col+1
    END IF
    LET cursor=jump_to_line(src,line,col,1)
    --  EXIT FOR
    --END IF
  END FOR
END FUNCTION

FUNCTION do_findword(src,cursor)
  DEFINE src STRING
  DEFINE cursor INT
  DEFINE start,end INT
  DEFINE word,oldstr,oldupdown STRING
  DEFINE found,idxfound,oldwhole,oldcase INT
  CALL findWord(src,cursor) RETURNING start,end
  LET word=src.subString(start+1,end-1)
  IF word.getLength()=0 OR LENGTH(word CLIPPED)=0  THEN 
    RETURN
  END IF
  LET oldwhole=srch_wholeword
  LET oldcase=srch_matchcase
  LET oldstr=srch_search
  LET oldupdown=srch_updown
  LET srch_wholeword=1
  LET srch_matchcase=0
  LET srch_search=word
  LET srch_updown="Down"
  CALL text_search(src,start+1,TRUE,FALSE) RETURNING found,idxfound
  IF found THEN
    CALL history_insert(srch_hist_arr,srch_search)
  ELSE
    LET srch_search=oldstr
    LET srch_wholeword=oldwhole
    LET srch_matchcase=oldcase
    LET srch_updown=oldupdown
  END IF
END FUNCTION

--searches in the given text the occurence of srch_search influenced by
--various flags
--returns if the search string was found and the position
FUNCTION int_search(txt,startpos)
  DEFINE txt STRING
  DEFINE startpos INT
  DEFINE found,idxfound INT
  DEFINE leftChar,rightChar STRING

LABEL search_again:
  IF srch_matchcase THEN
    LET idxfound=txt.getIndexOf(srch_search,startpos)
  ELSE
    LET idxfound=getIndexOfI(txt,srch_search,startpos)
  END IF
  --DISPLAY "int_search :",srch_search,",startpos:",startpos,",textlen:",txt.getLength(),",idxfound:",idxfound
  LET found=idxfound<>0
  IF found AND srch_wholeword THEN
    --check if there are delimiters at the left or the right
    IF idxfound>1 THEN
      LET leftchar=txt.getCharAt(idxfound-1)
      IF NOT isDelimiterChar(leftChar) THEN
        LET found=0
      END IF
    END IF
    IF found AND idxfound+srch_search.getLength()<=txt.getLength() THEN
      LET rightChar=txt.getCharAt(idxfound+srch_search.getLength())
      IF NOT isDelimiterChar(rightChar) THEN
        LET found=0
      END IF 
    END IF 
    IF NOT found THEN
      LET startpos=idxfound+srch_search.getLength()
      GOTO search_again
    END IF
  END IF -- found AND srch_wholeword
  RETURN found,idxfound
END FUNCTION

--main workhorse for the various search functions
FUNCTION text_search(txt,cursor,set_cursor,showerror)
  DEFINE txt STRING
  DEFINE cursor INT
  DEFINE set_cursor INT
  DEFINE showerror INT --show an error if nothing was found
  DEFINE found,idxfound,lastidxfound,startpos,endpos,i INT
  IF srch_updown="Down" THEN
    LET startpos=cursor+1
    WHILE NOT found
      CALL int_search(txt,startpos) RETURNING found,idxfound
      --DISPLAY "found:",found,",idxfound:",idxfound
      IF NOT found THEN
        IF startpos>1 THEN
          --search from the beginning
          LET startpos=1
        ELSE --must be 1 here
          EXIT WHILE
        END IF
      END IF
    END WHILE
  ELSE
    --searching upwards is somewhat difficult, because the string methods
    --do not support it
    --this code is pretty hairy...
    LET startpos=1
    LET endpos=cursor-1
    LET lastidxfound=0
    FOR i=1 TO 2
      IF startpos<endpos THEN
        CALL int_search(txt,startpos) RETURNING found,idxfound
        WHILE found AND idxfound<endpos
          LET lastidxfound=idxfound
          LET startpos=idxfound+1
          CALL int_search(txt,startpos) RETURNING found,idxfound
        END WHILE
        IF (i=1 AND lastidxfound<>0) OR 
           (i=2 AND NOT found AND lastidxfound<>0) THEN
          LET found=1
          LET idxfound=lastidxfound
          EXIT FOR
        END IF
      END IF
      IF endpos=cursor-1 AND cursor<txt.getLength() THEN
        LET endpos=txt.getLength()
        LET startpos=cursor+1
      ELSE
        EXIT FOR
      END IF
    END FOR
  END IF
  IF NOT found THEN
    IF showerror THEN
      CALL cant_find()
    END IF
  ELSE
    IF set_cursor THEN
      CALL my_setselection(idxfound,idxfound+srch_search.getLength())
    END IF
  END IF
  RETURN found,idxfound
END FUNCTION

--inserts an entry into to given history array
--the function checks for duplicates
--and deletes them before inserting the new entry
FUNCTION history_insert (hist_arr,entry)
  DEFINE hist_arr DYNAMIC ARRAY OF STRING
  DEFINE entry STRING
  DEFINE i,len INTEGER
  --insert the command into the history
  --first look if its already in the history
  LET len=hist_arr.getLength()
  FOR i=1 TO len
    IF hist_arr[i]=entry THEN
      CALL hist_arr.deleteElement(i)
      EXIT FOR
    END IF
  END FOR
  CALL hist_arr.insertElement(1)
  LET hist_arr[1]=entry
END FUNCTION

--goes up in the given history array
FUNCTION history_up (hist_arr,idx,prevEntry)
  DEFINE hist_arr DYNAMIC ARRAY OF STRING
  DEFINE idx INTEGER
  DEFINE prevEntry,entry STRING
  IF hist_arr.getLength()<1 THEN
    RETURN prevEntry,idx
  END IF
LABEL fdb_history_up:
  LET idx=idx+1
  IF idx>hist_arr.getLength() THEN
    LET idx=hist_arr.getLength()
  END IF
  IF idx=0 THEN
    LET entry=""
  ELSE
    LET entry=hist_arr[idx]
  END IF
  IF entry IS NOT NULL AND entry=prevEntry AND
     hist_arr.getLength()>1 AND idx<hist_arr.getLength() THEN
    --the value didnt change
    GOTO :fdb_history_up
  END IF
  RETURN entry,idx
END FUNCTION

--goes down in the given history array
FUNCTION history_down (hist_arr,idx,prevEntry)
  DEFINE hist_arr DYNAMIC ARRAY OF STRING
  DEFINE idx INTEGER
  DEFINE prevEntry,entry STRING
  LET idx=idx-1
  IF idx<0 THEN
    LET idx=0
  END IF
  IF idx=0 THEN
    LET entry=""
  ELSE
    LET entry=hist_arr[idx]
  END IF
  RETURN entry,idx
END FUNCTION

--shows a dialog containing the history list
FUNCTION history_show(hist_arr,idx,oldvalue)
  DEFINE hist_arr DYNAMIC ARRAY OF STRING
  DEFINE idx Integer
  DEFINE oldvalue,value STRING
  DEFINE prevIdx,i,len INTEGER
  LET prevIdx=idx
  LET value=oldvalue
  OPEN WINDOW history WITH FORM "fglped_history" 
  CALL set_count(hist_arr.getLength())
  DISPLAY ARRAY hist_arr to hist.* 
    BEFORE DISPLAY
      LET len=hist_arr.getLength()
      FOR i=1 TO len
        IF hist_arr[i]=value THEN
          CALL fgl_set_arr_curr(i)
          EXIT FOR
        END IF
      END FOR
    ON KEY(Interrupt)
      LET value=oldValue
      LET idx=prevIdx
      EXIT DISPLAY
    --ON ACTION delete
      --delete the current line in the array
      --because this led on some fgl versions to core dumps when we
      --stay in the DISPLAY ARRAY, we should go out
      --and reenter it in an outer loop
      --CALL hist_arr.deleteElement(arr_curr())
    AFTER DISPLAY
      LET prevIdx=-1
      LET idx=arr_curr()
  END DISPLAY
  CLOSE WINDOW history
  IF idx!=prevIdx THEN
    LET value=hist_arr[idx]
  ELSE
    LET value=oldvalue
  END IF
  RETURN value,idx
END FUNCTION

FUNCTION do_gotoline(src,cursor)
  DEFINE src STRING
  DEFINE cursor INT
  CALL close_sc_if_GBC()
  OPEN WINDOW gotoline WITH FORM "fglped_gotoline"
  LET int_flag=FALSE
  INPUT BY NAME m_lineno WITHOUT DEFAULTS
  CLOSE WINDOW gotoline
  IF NOT int_flag THEN
    LET cursor=jump_to_line(src,m_lineno,1,1)
  END IF
END FUNCTION

FUNCTION cant_find ()
    CALL fgl_winMessage("fglped", "Cannot find the string \""||srch_search||"\" !", "info")
END FUNCTION

--wizard to choose a schema file and choose columns from that schema to
--create an initial form
FUNCTION dowizard()
  DEFINE winopen INT
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE i,code,len INT
  DEFINE schemaFile,dirname,state,type,cmd,src,mkper,pedpath STRING
  DEFINE init INT
LABEL wizschema:
  IF winopen THEN
    CLOSE WINDOW wiz
    LET winopen=0
  END IF
  CURRENT WINDOW IS SCREEN CALL fgl_refresh()
  LET schemaFile= fglped_schemadlg(schemaFile)
  IF schemaFile IS NULL THEN
    RETURN NULL,NULL
  END IF
  LET init=1
LABEL wizcols:
  CALL fglped_wiz_columns.clear()
  IF NOT winopen THEN 
    LET winopen=1
    --hack:
    --make screen active for a short while to make 'center2' working for 'wiz'
    CURRENT WINDOW IS SCREEN CALL fgl_refresh()
    OPEN WINDOW wiz WITH 25 ROWS, 80 COLUMNS ATTRIBUTES(STYLE="dialog_resize")
  END IF
  LET state=colwizard(schemaFile,init) 
  LET init=0
  CASE state
    WHEN "prev"   GOTO wizschema
    WHEN "next"   GOTO wiztype
    WHEN "cancel" GOTO wizend
    WHEN "accept" GOTO wizend
  END CASE
LABEL wiztype:
  CALL fglped_typewizard() RETURNING state,type
  DISPLAY "type:",type
  CASE state
    WHEN "prev"   GOTO wizcols
    WHEN "cancel" GOTO wizend
    WHEN "accept" GOTO wizend
  END CASE
LABEL wizend:
  IF state="accept" THEN
    LET dirname=file_get_dirname(schemaFile)
    LET schemaFile=file_get_short_filename(schemaFile)
    LET schemaFile=file_basename(schemaFile,".sch")
    IF (pedpath:=fgl_getenv("FGLPEDPATH")) IS NOT NULL THEN
      LET mkper=file_join(pedpath,"fglmkper")
    ELSE
      LET mkper="fglmkper"
    END IF
    LET cmd=sfmt("fglrun %1 -s %2 ",mkper,schemaFile)
    IF file_on_windows() THEN
      LET cmd=sfmt("set DBPATH=%1;%%DBPATH%% && %2",dirname,cmd)
    ELSE
      LET cmd=sfmt("export DBPATH=\"%1\":$DBPATH && %2",dirname,cmd)
    END IF
    IF type="table" THEN
      LET cmd=cmd,"-t table.tpl "
    END IF
    FOR i=1 TO fglped_wiz_columns.getLength()
      LET cmd=cmd,fglped_wiz_columns[i].table_name,"."
      LET cmd=cmd,fglped_wiz_columns[i].field_name," "
    END FOR
    LET code=file_get_output(cmd,arr)
    LET len=arr.getLength()
    FOR i=1 TO arr.getLength()
      LET src=src,arr[i]
      IF i<>len THEN
        LET src=src,"\n"
      END IF
    END FOR
  END IF
  CLOSE WINDOW wiz
  RETURN src,dirname
END FUNCTION

FUNCTION fglped_typewizard()
  DEFINE rlayout,state STRING
  OPEN FORM typewizard FROM "fglped_typewizard"
  DISPLAY FORM typewizard
  LET rlayout="single"
  LET state="cancel"
  DISPLAY "fglped_singlecol.png" TO img
  INPUT BY NAME rlayout WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED)
    ON CHANGE rlayout
      CASE rlayout
        WHEN "single"
          DISPLAY "fglped_singlecol.png" TO img
        WHEN "table"
          DISPLAY "fglped_table.png" TO img
      END CASE
    ON ACTION cancel   LET state="cancel" EXIT INPUT
    ON ACTION accept   LET state="accept" EXIT INPUT
    ON ACTION prevwiz  LET state="prev"   EXIT INPUT
    --ON ACTION nextwiz  LET state="next"   EXIT INPUT
  END INPUT
  CLOSE FORM typewizard
  RETURN state,rlayout
END FUNCTION

FUNCTION choose_style()
  DEFINE uroot,unode om.DomNode
  DEFINE unl om.NodeList
  DEFINE udoc om.DomDocument
  DEFINE i INT
  DEFINE sarr DYNAMIC ARRAY OF STRING

  LET udoc=om.DomDocument.createFromXmlFile(m_user_styles)
  IF udoc IS NULL THEN
    CALL fgl_winmessage(S_ERROR,sfmt("Can't read style file:%1",m_user_styles),IMG_ERROR)
    RETURN 0
  ELSE
    LET uroot=uDoc.getDocumentElement()
    LET unl=uroot.selectByPath("//Style")
    IF unl.getLength()=0 THEN
      CALL fgl_winmessage(S_ERROR,sfmt("No styles found in:%1",m_user_styles),IMG_ERROR)
      RETURN 0
    END IF
    FOR i=1 TO  unl.getLength() 
      LET unode=unl.item(i)
      --DISPLAY "unode:",unode.getTagName(),",name:",unode.getAttribute(A_NAME)
      LET sarr[sarr.getLength()+1]=unode.getAttribute(A_NAME)
    END FOR
  END IF
  OPEN WINDOW fglped_styles WITH FORM "fglped_styles"
  CALL set_count(sarr.getLength())
  LET int_flag=FALSE
  DISPLAY ARRAY sarr TO sarr.*
    BEFORE DISPLAY
      FOR i=1 TO sarr.getLength()
        IF m_style=sarr[i] THEN
          CALL fgl_set_arr_curr(i)
          EXIT FOR
        END IF
      END FOR
  END DISPLAY
  IF NOT int_flag THEN
    LET m_style=sarr[arr_curr()]
    CALL manipulatePreviewStyle()
  END IF
  CLOSE WINDOW fglped_styles
  RETURN 1
END FUNCTION

--set the 'forceDefaultSettings' property in the 'preview' style
--to leave the 'sc' window in the same position when recreating with a
--new form, or to let it appear under the textedit window
--however the size should not be restored to show the form always in the virgin state
--unfortunately this works not yet if the form is recreated inside the 
--existing form, it only works if the window is reopened
FUNCTION manipulatePreviewStyle()
  DEFINE r,uroot,n,ch,chn,unode,uch,newNode,parent om.DomNode
  DEFINE nl,unl om.NodeList
  DEFINE doc,udoc om.DomDocument
  DEFINE name,value STRING
  IF isGBC() OR m_client_version>=2.50 THEN --omit the crap code below
    RETURN
  END IF
  LET udoc=om.DomDocument.createFromXmlFile(m_user_styles)
  IF udoc IS NOT NULL AND m_style.getLength()>0 THEN
    LET uroot=uDoc.getDocumentElement()
    LET unl=uroot.selectByPath(sfmt("//Style[@name=\"%1\"]",m_style))
    IF unl.getLength()>0 THEN
      LET unode=unl.item(1)
      --DISPLAY "unode:style", unode.getAttribute(A_NAME)
    END IF
  END IF

  LET r = ui.Interface.getRootNode()
  LET nl=r.selectByPath("//Style[@name=\"Window."||S_PREVIEW||"\"]")
  IF nl.getLength()<>1 THEN
    RETURN
  END IF
  LET n=nl.item(1)
  --DISPLAY "manipulate ",n.getTagName(),":",n.getAttribute(A_NAME)


  IF unode IS NOT NULL THEN
    --copy user style attributes
    LET uch=unode.getFirstChild()
    WHILE uch IS NOT NULL 
      LET name=uch.getAttribute(A_NAME)
      LET value=uch.getAttribute(A_VALUE)

      LET ch=n.getFirstChild()
      LET chn=NULL
      WHILE ch IS NOT NULL
        IF ch.getAttribute(A_NAME)=name THEN
          LET chn=ch
          EXIT WHILE
        END IF
        LET ch=ch.getNext()
      END WHILE
      IF chn IS NULL THEN
        LET chn=n.createChild("StyleAttribute")
        CALL chn.setAttribute(A_NAME,name)
      END IF
      CALL chn.setAttribute(A_VALUE,value)
      LET chn=NULL
      LET uch=uch.getNext()
    END WHILE
    --ready copying StyleAttributes
  END IF
      
  LET nl=n.selectByPath("//StyleAttribute[@name=\"forceDefaultSettings\"]")
  IF nl.getLength()>0 THEN
    LET ch=nl.item(1)
  ELSE
    LET ch=n.createChild("StyleAttribute")
    CALL ch.setAttribute(A_NAME,"forceDefaultSettings")
  END IF
  --instruct gdc to NOT store the size but the position of the window
  --this works funnyly also for 1.33 and 2.00 by accident because 
  --asking to store the size is a different 'if' question than asking
  --to restore the position
  CALL ch.setAttribute(A_VALUE,"size")
  --remove 'position'='field' so the xy settings can be effective on redisplay
  LET nl=n.selectByPath("//StyleAttribute[@name=\"position\"]")
  IF nl.getLength()>0 THEN
    LET ch=nl.item(1)
    CALL n.removeChild(ch)
    LET ch=NULL
  END IF
  LET doc=ui.interface.getDocument()
  --clone the existing to be sure the client changes the style
  LET newNode=doc.copy(n,TRUE)
  --remove the old
  LET parent=n.getParent()
  CALL parent.appendChild(newNode)
  --DISPLAY "newNode id:",newNode.getId(),",parentId:",parent.getId(),",old node:",n.getId(),",parent tagname:",parent.getTagName()
  CALL parent.removeChild(n)
END FUNCTION

FUNCTION checkClientVersion()
  DEFINE version STRING
  DEFINE pointpos INTEGER
  LET version=ui.interface.getFrontEndVersion()
  --cut out major.minor from the version
  LET pointpos=version.getIndexOf(".",1)
  --get the index of the 2nd point
  LET pointpos=version.getIndexOf(".",pointpos+1)
  IF pointpos>1 THEN
    LET version=version.subString(1,pointpos-1)
  END IF
  LET m_client_version=version
  IF NOT isGDC() THEN
    LET m_client_version=2.0
  END IF
  DISPLAY "client version:",m_client_version
END FUNCTION

--returns true if the current contents was initialized by File->New
--or File->New From Wizard
FUNCTION isNewFile()
  IF m_srcfile IS NULL OR
    file_get_short_filename(m_srcfile)=WIZGEN THEN
    RETURN 1
  END IF
  RETURN 0
END FUNCTION

FUNCTION delete_tmpfiles(tmpname)
  DEFINE tmpname STRING
  DEFINE dummy INT
  IF tmpname IS NULL THEN
    RETURN
  END IF
  CALL file_delete(tmpname) RETURNING dummy
  CALL file_delete(basename(tmpname)||".42f") RETURNING dummy
END FUNCTION

FUNCTION browse(dirname)
  DEFINE dirname STRING
  DEFINE fname STRING
  DEFINE dir_new,fullname,menutitle STRING
  DEFINE browsearr DYNAMIC ARRAY OF STRING
  DEFINE idx,len,exit_browse INT
  DEFINE winNode,fNode om.DomNode
  LET idx=1
  WHILE dirname IS NOT NULL AND fillBrowseArray(dirname,browsearr)=0 
     LET dirname=fglped_dirdlg(dirname)
  END WHILE
  IF dirname IS NULL THEN
    RETURN NULL
  END IF
  --IF fillBrowseArray(dirname,browsearr)=0 THEN
  --  RETURN NULL
  --END IF
  IF m_browseidx<>0 THEN
    LET idx=m_browseidx
  END IF
  WHILE NOT exit_browse 
    LET len=browsearr.getLength()
    IF len=0 THEN
      LET fullname="fglped_browse_error"
      LET fname="Empty dir:",dirname
    ELSE
      LET fullname=browsearr[idx]
      LET fname=file_get_short_filename(browsearr[idx])
    END IF
    CALL previewBrowseForm(fullname,len,dirname)
    CALL fgl_setTitle(sfmt("%1 in: %2",fname,dirname))
    MESSAGE sfmt("%1 in: %2",fname,dirname)
    LET winNode=getWindowNode("browse")
    --patch the style to force our position + button frame
    CALL winNode.setAttribute(A_STYLE,"browse")
    LET fNode = getFormNode(winNode)
    CALL fNode.setAttribute(A_STYLE,"browse")
    LET menutitle=sfmt("Browse %1 of %2",idx,len)
    MENU menutitle
      COMMAND KEY(N) "Next Form"
        LET idx=((len+idx) MOD len)+1
        EXIT MENU
      COMMAND KEY(P) "Prev Form"
        LET idx=((len+idx-2) MOD len)+1
        EXIT MENU
      {
      COMMAND KEY(U) "Up "
        LET dir_new=file_normalize_dir(dirname)
        LET dir_new=file_get_dirname(dir_new)
        IF (dir_new:=checkBrowseArr(dir_new,browsearr,1)) IS NOT NULL THEN
          LET idx=1
          LET dirname=dir_new
          EXIT MENU
        END IF
      }
      COMMAND KEY(C) "Choose Dir..."
        LET dir_new=file_normalize_dir(dirname)
        LET dir_new=fglped_dirdlg(dir_new)
        IF (dir_new:=checkBrowseArr(dir_new,browsearr,0)) IS NOT NULL THEN
          LET idx=1
          LET dirname=dir_new
          EXIT MENU
        END IF
      COMMAND KEY(E) "Edit "
        IF len=0 THEN
          LET fullname=NULL
        END IF
        LET exit_browse=TRUE
        EXIT MENU
      COMMAND KEY(Escape) "Cancel "
        LET exit_browse=TRUE
        LET fullname=NULL
        EXIT MENU
    END MENU
    CLOSE WINDOW browse
    IF NOT m_screen_closed THEN
      CURRENT WINDOW IS screen
      CALL fgl_refresh()
    END IF
  END WHILE
  RETURN fullname
END FUNCTION

FUNCTION checkBrowseArr(dirname,browsearr,runDialog)
  DEFINE dirname STRING
  DEFINE browsearr DYNAMIC ARRAY OF STRING
  DEFINE runDialog INT
  DEFINE newarr DYNAMIC ARRAY OF STRING
  DEFINE i,len INT
  IF dirname IS NULL THEN
    RETURN NULL
  ELSE
    LET len=fillBrowseArray(dirname,newarr)
    IF len=0 AND runDialog THEN
      LET dirname=fglped_dirdlg(dirname)
      IF dirname IS NOT NULL THEN
         LET len=fillBrowseArray(dirname,newarr)
      END IF
    END IF
  END IF
  IF len=0 THEN
    IF dirname IS NOT NULL THEN
      CALL fgl_winmessage(S_ERROR,sfmt("Can't find .per files in:%1",dirname),IMG_ERROR)
    END IF
    RETURN NULL
  END IF
  CALL browsearr.clear()
  FOR i=1 TO len
    LET browsearr[i]=newarr[i]
  END FOR
  RETURN dirname
END FUNCTION

FUNCTION fillBrowseArray(dirname,browsearr)
  DEFINE dirname STRING
  DEFINE browsearr DYNAMIC ARRAY OF STRING
  DEFINE dh INTEGER
  DEFINE fname, pname, ext STRING
  DEFINE atidx INT
  DEFINE currdir,currname STRING
  CALL browsearr.clear()
  LET m_browseidx=0
  IF dirname IS NULL THEN
    RETURN 0
  END IF
  LET dh = os.Path.diropen(dirname)
  IF dh == 0 THEN 
    RETURN 0
  END IF
  IF m_srcfile IS NOT NULL THEN
    LET currdir=file_get_dirname(m_srcfile)
    IF currdir=dirname THEN
      LET currname=file_get_short_filename(m_srcfile)
    END IF
  END IF
  WHILE TRUE
    LET fname = os.Path.dirnext(dh)
    IF fname IS NULL THEN 
      EXIT WHILE 
    END IF
    IF fname == "." THEN
      CONTINUE WHILE
    END IF
    LET pname = file_join(dirname,fname)
    IF file_is_dir(pname) THEN
      CONTINUE WHILE
    END IF
    LET ext=file_extension(pname)
    IF ext=".per" THEN
      IF (atidx:=fname.getIndexOf(".@",1))==1 THEN
        CONTINUE WHILE
      END IF
      LET browsearr[browsearr.getLength()+1]=pname
      IF currname=fname THEN
        LET m_browseidx=browsearr.getLength()
        --DISPLAY "m_browseidx=",m_browseidx
      END IF
      --DISPLAY sfmt("%1:%2",browsearr.getLength(),browsearr[browsearr.getLength()])
    END IF
  END WHILE
  CALL os.Path.dirclose(dh)
  RETURN browsearr.getLength()
END FUNCTION

FUNCTION previewBrowseForm(fname,len,dirname)
  DEFINE fname STRING
  DEFINE len INT
  DEFINE dirname STRING
  DEFINE bname,mess STRING
  LET bname=basename(fname)
  --DISPLAY "previewBrowseForm:",fname
  IF len > 0 THEN
    IF (mess:=compile_form(bname,0,0)) IS NOT NULL THEN
      LET bname="fglped_browse_error"
    END IF
  END IF
  --DISPLAY " compiled.."
  OPEN WINDOW browse WITH FORM bname ATTRIBUTES(style="browse")
  IF len=0 THEN
    DISPLAY sfmt("found no forms in directory:%1",dirname) TO browse_message
  ELSE
  IF mess IS NOT NULL THEN
    DISPLAY sfmt("could not compile:%1",fname) TO browse_message
    DISPLAY mess TO browse_message_detail
  END IF
  END IF
END FUNCTION

FUNCTION isGDC()
  DEFINE fename STRING
  LET fename=ui.Interface.getFrontEndName()
  IF fename=="GDC" OR fename=="Genero Desktop Client" THEN
    --DISPLAY "GDC detected"
    RETURN TRUE
  ELSE
    RETURN FALSE
  END IF
END FUNCTION

FUNCTION isGBC()
  RETURN ui.Interface.getFrontEndName()=="GBC"
END FUNCTION

FUNCTION setClientOnMac()
  DEFINE ostype STRING
  CALL ui.Interface.frontcall("standard","feinfo", ["ostype"],[ostype])
  IF ostype="OSX" THEN
    LET m_clientOnMac=TRUE
  END IF
END FUNCTION

--displays an om node tree with attributes
FUNCTION displayNode(n,indent)
  DEFINE n,ch om.DomNode
  DEFINE i INT
  DEFINE indent,s,aName STRING
  LET s=indent,n.getTagName()
  FOR i=1 TO n.getAttributesCount()
    LET aName=n.getAttributeName(i)
    LET s=s," ",aName,": '",n.getAttribute(aName),"'"
  END FOR
  DISPLAY s
  LET indent=indent,"  "
  LET ch=n.getFirstChild()
  WHILE ch IS NOT NULL
    CALL displayNode(ch,indent)
    LET ch=ch.getNext()
  END WHILE
END FUNCTION

FUNCTION deactivateIdleAction()
  DEFINE w ui.Window
  DEFINE wNode,idleNode om.DomNode
  DEFINE nl om.NodeList
  --as all other clients are disturbed by the idle action we 
  --"disable" it by giving it a never ending timeout
  LET w=ui.Window.getCurrent()
  LET wNode=w.getNode()
  --CALL displayNode(wNode,"")
  LET nl= wNode.selectByPath("//IdleAction[@timeout=\"1\"]")
  IF nl.getLength()!=1 THEN
    CALL myErr("Can't find IdleAction")
  END IF
  LET idleNode=nl.item(1)
  CALL idleNode.setAttribute("timeout","10000")
END FUNCTION

FUNCTION hideSideBar()
  DEFINE w ui.Window
  DEFINE f ui.Form
  DEFINE wNode,fNode,te om.DomNode
  DEFINE nl om.NodeList
  DEFINE i INT
  LET w=ui.Window.getCurrent()
  LET wNode=w.getNode()
  LET f=w.getForm()
  LET fNode=f.getNode()
  --just set a ridiculous width to kill the side bar
  CALL wNode.setAttribute("width","1000")
  CALL fNode.setAttribute("width","1000")
  CALL fNode.setAttribute("minWidth","1000")
  FOR i=1 TO 2
  
  LET nl=fNode.selectByTagName(IIF(i==1,"Grid","TextEdit"))
  IF nl.getLength()<1 THEN 
    CALL myErr("No textedit found")
  END IF
  LET te=nl.item(1)
  CALL te.setAttribute("width","1000")
  CALL te.setAttribute("gridWidth","1000")
  END FOR
END FUNCTION

FUNCTION firstLetterToUpper(s)
  DEFINE s,s1,s2 STRING
  LET s1=s.subString(1,1)
  LET s1=s1.toUpperCase()
  LET s2=s.subString(2,s.getLength())
  LET s2=s2.toLowerCase()
  RETURN sfmt("%1%2",s1,s2)
END FUNCTION

FUNCTION handleAccel(s)
  DEFINE s,first,second STRING
  DEFINE minus INT
  LET minus=s.getIndexOf("-",1)
  IF minus<>0 THEN
    LET first=s.subString(1,minus-1)
    LET first=firstLetterToUpper(first)
    LET second=s.subString(minus+1,s.getLength())
    LET second=firstLetterToUpper(second)
    RETURN sfmt("%1+%2",first,second)
  END IF
  RETURN firstLetterToUpper(s)
END FUNCTION

--we make the accelereators visible in the TopMenu if running under GBC
--this should be build in into GBC...
FUNCTION addAcceleratorsToTopMenu()
  DEFINE w ui.Window
  DEFINE root,wNode,tc,ad,p,next om.DomNode
  DEFINE nl1,nl2 om.NodeList
  DEFINE f,txt,acc,name STRING
  DEFINE doc om.DomDocument
  DEFINE i,j INT
  LET f=os.Path.join(os.Path.dirName(arg_val(0)),"fglped.42f")
  LET doc=om.DomDocument.createFromXmlFile(f)
  IF doc IS NULL THEN
    CALL myErr(sfmt("can't read :%1",f))
  END IF
  LET w=ui.Window.getCurrent()
  LET wNode=w.getNode()
  LET nl1=wNode.selectByTagName("TopMenuCommand")
  LET root=doc.getDocumentElement()
  LET nl2=root.selectByTagName("ActionDefault")
  FOR i=1 TO nl1.getLength()
    LET tc=nl1.item(i)
    LET name=tc.getAttribute("name")
    --remove the actions which are not (yet) usable
    --some can be re added if some GBC bugs are fixed
    IF name="findword" 
       OR name="jump_to_def" 
       OR name="toggle_text"
       OR name="replace"
       OR name="replaceagain"
       OR name="undolastreplace"
       OR name="viewerr"
       OR name="editcopy"
       OR name="editpaste"
       OR name="editcut"
       THEN
       LET p=tc.getParent()
       LET next=tc.getNext()
       IF next IS NOT NULL AND next.getTagName()=="TopMenuSeparator" THEN
         CALL p.removeChild(next)
       END IF
       CALL p.removeChild(tc)
       CONTINUE FOR
    END IF
    FOR j=1 TO nl2.getLength()
      LET ad=nl2.item(j)
      IF ad.getAttribute("name")==name THEN
        LET acc=ad.getAttribute("acceleratorName")
        LET txt=ad.getAttribute("text")
        IF acc IS NOT NULL AND txt IS NOT NULL THEN
          CALL tc.setAttribute("text",SFMT("%1 (%2)",txt,handleAccel(acc)))
        END IF
      END IF
    END FOR
  END FOR
END FUNCTION

FUNCTION myErr(errstr)
  DEFINE errstr STRING
  DISPLAY "ERROR:",errstr
  EXIT PROGRAM 1
END FUNCTION

FUNCTION myErrReturn(s)
  DEFINE s STRING
  DISPLAY "ERROR:",s
  RETURN FALSE
END FUNCTION

FUNCTION isWin()
  RETURN fgl_getenv("WINDIR") IS NOT NULL
END FUNCTION

FUNCTION checkGAS()
END FUNCTION

FUNCTION checkGASInt()
  DEFINE defdir STRING
  IF m_gasdir IS NULL THEN
    RETURN FALSE
  END IF
  IF NOT checkGBCDir() THEN
    LET defdir=os.Path.join(m_gasdir,"web/gwc-js")
    IF NOT os.Path.exists(defdir) AND NOT os.Path.isDirectory(defdir) THEN
      RETURN FALSE
    END IF
  END IF
  IF NOT try_GASalive() THEN
    IF NOT runGAS() THEN
      RETURN FALSE
    END IF
  END IF
  IF NOT createGASApp() THEN
    RETURN FALSE
  END IF
  CALL displayURL()
  RETURN TRUE
END FUNCTION

FUNCTION displayURL()
  DEFINE url STRING
  IF m_gbcdir IS NOT NULL THEN
    LET url=sfmt("http://localhost:%1/%2/index.html?app=%3",m_port,m_gbcname,m_appname)
  ELSE
    LET url=sfmt("http://localhost:%1/gwc-js/index.html?app=%2",m_port,m_appname)
  END IF
  DISPLAY url TO webpreview
END FUNCTION

--write a GAS app entry 
FUNCTION createGASApp()
  DEFINE ch base.Channel
  DEFINE appdir,appfile,ext,cmd,line,name STRING
  DEFINE copyenv DYNAMIC ARRAY OF STRING
  DEFINE code,i,eqIdx INT
  DEFINE invokeShell BOOLEAN
  DEFINE dollar STRING
  LET dollar='$'
  LET ch=base.Channel.create()
  LET appdir=os.Path.join(os.Path.join(m_gasdir,"appdata"),"app")
  IF NOT os.Path.exists(appdir) THEN
    IF NOT os.Path.mkdir(appdir) THEN
      RETURN myErrReturn(sfmt("GAS app dir:%1 doesn't exist and cannot be created",appdir))
    END IF 
  END IF
  LET m_appname=sfmt("fglped_web%1",fgl_getpid())
  LET appfile=os.Path.join(appdir,sfmt("%1.xcf",m_appname))
  TRY
    CALL ch.openFile(appfile,"w")
  CATCH
    RETURN myErrReturn(sfmt("Can't open %1:%2",appfile,err_get(status)))
  END TRY
  CALL ch.writeLine(       "<?xml version=\"1.0\"?>")
  CALL ch.writeLine(       "<APPLICATION Parent=\"defaultgwc\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"http://www.4js.com/ns/gas/2.30/cfextwa.xsd\">" )
  IF fgl_getenv("FGLRUN") IS NOT NULL THEN
    CALL ch.writeLine(sfmt("<RESOURCE Id=\"res.dvm.wa\" Source=\"INTERNAL\">%1</RESOURCE>",fgl_getenv("FGLRUN")))
  END IF
  IF fgl_getenv("FGLDIR") IS NOT NULL THEN
    CALL ch.writeLine(sfmt(  "  <RESOURCE Id=\"res.fgldir\" Source=\"INTERNAL\">%1</RESOURCE>",fgl_getenv("FGLDIR")))
  END IF
  CALL ch.writeLine(sfmt(  "  <RESOURCE Id=\"res.path\" Source=\"INTERNAL\">%1</RESOURCE>",fgl_getenv("PATH")))
  CALL ch.writeLine(       "  <EXECUTION>")
  {
  CALL file_get_output(IIF(isWin(),"set","env"),copyenv) 
  --we simply add every environment var in the .xcf file
  FOR i=1 TO copyenv.getLength() 
    LET line=copyenv[i]
    IF (eqIdx:=line.getIndexOf("=",1))>0 THEN
      LET name=line.subString(1,eqIdx-1) --may be we need to leave out some vars...candidate is _FGL_PPID
      IF name.getIndexOf("_FGL_",1)==1 or name.getIndexOf("FGLGUI",1)==1 THEN
        CONTINUE FOR
      END IF
      IF fgl_getenv(name) IS NOT NULL THEN --check if we actually have this env
        CALL ch.writeLine(sfmt(  "    <ENVIRONMENT_VARIABLE Id=\"%1\">%2</ENVIRONMENT_VARIABLE>",name,fgl_getenv(name)))
      END IF
    END IF
  END FOR
  IF m_gbcdir IS NOT NULL AND 
     os.Path.exists(os.Path.join(m_gbcdir,"gbc2.css")) THEN
     --GBC2 needs JSON with FGLGUI set to 2
      CALL ch.writeLine( "    <ENVIRONMENT_VARIABLE Id=\"FGLGUI\">2</ENVIRONMENT_VARIABLE>")
  END IF
  }
  CALL ch.writeLine("    <ENVIRONMENT_VARIABLE Id=\"FGLGUIDEBUG\">1</ENVIRONMENT_VARIABLE>")
  CALL ch.writeLine(sfmt(  "    <PATH>%1</PATH>",os.Path.dirname(arg_val(0))))
  CALL ch.writeLine(sfmt(  "    <MODULE>%1</MODULE>","fglped_webpreview"))
  CALL ch.writeLine(       "    <PARAMETERS>")
  --FOR i=2 TO num_args()
    CALL ch.writeLine(sfmt(  "      <PARAMETER>%1</PARAMETER>",m_tmpWebForm))
  --END FOR
  CALL ch.writeLine(       "    </PARAMETERS>")
  CALL ch.writeLine(       "  </EXECUTION>")
  IF m_gbcdir IS NOT NULL THEN
    CALL ch.writeLine(       "  <UA_OUTPUT>")
    CALL ch.writeLine(  sfmt("     <PROXY>%1(res.uaproxy.cmd)</PROXY>",dollar))
    CALL ch.writeLine(  sfmt("     <PUBLIC_IMAGEPATH>%1(res.public.resources)</PUBLIC_IMAGEPATH>",dollar))
    CALL ch.writeLine(  sfmt("     <GWC-JS>%1</GWC-JS>",m_gbcname))
    CALL ch.writeLine(       "   </UA_OUTPUT>")
  END IF

  CALL ch.writeLine(       "</APPLICATION>")
  CALL ch.close()
  CALL log(sfmt("wrote gas app file:%1",appfile))
  RETURN TRUE
END FUNCTION

FUNCTION runGAS()
  DEFINE cmd,gasbindir,httpdispatch,filter STRING
  DEFINE trial,i INT
  IF NOT bindport() THEN
    RETURN FALSE
  END IF
  LET gasbindir=os.Path.join(m_gasdir,"bin")
  LET httpdispatch=IIF(isWin(),"httpdispatch.exe","httpdispatch")
  LET httpdispatch=os.Path.join(gasbindir,httpdispatch)
  IF NOT os.Path.exists(httpdispatch) THEN
    RETURN myErrReturn(sfmt("Can't find %1",httpdispatch))
  END IF
  IF isWin() THEN
    LET cmd='cd ',m_gasdir,'&&start ',httpdispatch
  ELSE
    LET cmd=httpdispatch
  END IF
  --LET filter="ERROR"
  --LET filter="ERROR PROCESS"
  IF (filter:=fgl_getenv("CATEGORIES_FILTER")) IS NULL THEN
    --default filter value
    --other possible values "ERROR" "ALL"
    LET filter="PROCESS"
  END IF
  LET cmd=cmd,' -p ', m_gasdir,sfmt(' -E "res.ic.port.offset=%1"',m_port-6300),' -E "res.log.output.type=CONSOLE" -E ',sfmt('"res.log.categories_filter=%1"',filter)
  --comment the following line if you want  to disable AUI tree watching
  --LET cmd=cmd,'  -E res.uaproxy.param=--development '
  IF NOT isWin() THEN
    LET cmd=cmd,' -E "res.log.output.path=/tmp"'
  END IF
  LET cmd=cmd,' -E "res.appdata.path=',os.Path.join(m_gasdir,"appdata") ,'" >/dev/null 2>&1'
    
  CALL log(sfmt("RUN %1 ...",cmd))
  RUN cmd WITHOUT WAITING
  FOR i=1 TO 4 
    IF try_GASalive() THEN
      RETURN TRUE
    END IF
    SLEEP 1
  END FOR
  RETURN myErrReturn("Can't startup GAS, check your configuration, FGLASDIR")
END FUNCTION

--2.41 has no os.Path.fullPath
FUNCTION fullPath(dir_or_file)
  DEFINE oldpath,dir_or_file,full,baseName STRING
  DEFINE dummy INT
  LET full=dir_or_file
  LET oldpath=os.Path.pwd()
  IF NOT os.Path.exists(dir_or_file) THEN
    CALL myerr(sfmt("fullPath:'%1' does not exist",dir_or_file))
  END IF
  IF NOT os.Path.isDirectory(dir_or_file) THEN
    --file case
    LET baseName=os.Path.basename(dir_or_file)
    LET dir_or_file=os.Path.dirName(dir_or_file)
  END IF
  IF os.Path.chdir(dir_or_file) THEN
    LET full=os.Path.pwd()
    IF baseName IS NOT NULL THEN 
      --file case
      LET full=os.Path.join(full,baseName)
    END IF
  END IF
  CALL os.Path.chdir(oldpath) RETURNING dummy
  RETURN full
END FUNCTION

--if GBCDIR is set a custom GBC installation is linked into the GAS
--web dir
FUNCTION checkGBCDir()
  DEFINE dummy,code INT
  DEFINE custom_gbc STRING
  LET m_gbcdir=fgl_getenv("GBCDIR")
  IF m_gbcdir IS NULL THEN
    RETURN FALSE
  END IF
  IF (NOT os.Path.exists(m_gbcdir)) OR 
     (NOT os.Path.isDirectory(m_gbcdir)) THEN
    RETURN myErrReturn(sfmt("GBCDIR %1 is not a directory",m_gbcdir))
  END IF
  LET m_gbcdir=fullPath(m_gbcdir);
  LET m_gbcname=os.Path.baseName(m_gbcdir);
  IF m_gbcname IS NULL THEN
    RETURN myErrReturn("GBC dirname must not be NULL")
  END IF
  IF m_gbcname=="gwc-js" THEN
    RETURN myErrReturn("GBC dirname must not be 'gwc-js'")
  END IF
  --remove the old symbolic link
  LET custom_gbc=os.Path.join(os.Path.join(m_gasdir,"web"),m_gbcname)
  CALL os.Path.delete(custom_gbc) RETURNING dummy
  CALL log(sfmt("custom_gbc:%1",custom_gbc))
  IF NOT isWin() THEN
    RUN sfmt("ln -s %1 %2",m_gbcdir,custom_gbc) RETURNING code
  ELSE
    RUN sfmt("mklink %1 %2",m_gbcdir,custom_gbc) RETURNING code
  END IF
  IF code THEN
    RETURN myErrReturn("could not link GBC into GAS web dir");
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION try_GASalive()
    DEFINE c base.Channel
    DEFINE s STRING
    DEFINE found BOOLEAN
    LET c = base.Channel.create()
    CALL log(sfmt("probe GAS on port:%1",m_port))
    TRY 
        CALL c.openClientSocket("localhost", m_port, "u", 2)
    CATCH
        RETURN FALSE
    END TRY
    -- write header
    LET s = "GET /index.html HTTP/1.1"
    CALL writeLine(c, s)
    CALL writeLine(c, "Host: localhost")
    CALL writeLine(c, "User-Agent: fglrun")
    CALL writeLine(c, "Accept: */*")
    CALL writeLine(c, "")

    LET found = read_response(c)
    CALL c.close()
    RETURN found
END FUNCTION

FUNCTION read_response(c)
    DEFINE c base.Channel
    DEFINE s STRING
    WHILE NOT c.isEof()
      LET s = c.readLine()
      LET s = s.toLowerCase()

      IF s MATCHES "x-fourjs-server: gas/3*" THEN
        RETURN TRUE
      END IF
      IF s.getLength() == 0 THEN
        EXIT WHILE
      END IF
    END WHILE
    RETURN FALSE
END FUNCTION

FUNCTION writeLine(c, s)
    DEFINE c base.Channel
    DEFINE s STRING
    LET s = s, '\r'
    CALL c.writeLine(s)
END FUNCTION

FUNCTION log(s)
  DEFINE s STRING
  IF fgl_getenv("VERBOSE") IS NOT NULL THEN
    DISPLAY "LOG:",s
  END IF
END FUNCTION

FUNCTION bindport()
  DEFINE newport INT
  DEFINE cmd,prog STRING
  --IF m_fglmajor<2525 THEN -- < 2.51
  --  RETURN FALSE
  --END IF
  LET prog=os.Path.join(os.Path.dirname(arg_val(0)),"bindport.42m")
  LET cmd=sfmt("fglrun %1 %2",prog,m_port)
  LET newport=readOutput(cmd)
  IF newport IS NULL OR newport==0 THEN
    RETURN myErrReturn(sfmt("Can't get port number from '%1'",cmd))
  END IF
  IF newport<>m_port THEN
    LET m_port=newport
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION readOutput(program)
  DEFINE program STRING
  DEFINE linestr STRING
  DEFINE c base.Channel
  LET c = base.channel.create()
  WHENEVER ERROR CONTINUE
  CALL c.openpipe(program,"r")
  WHENEVER ERROR STOP
  --DISPLAY "file_get_output:",program
  LET linestr=c.readline()
  CALL c.close()
  RETURN linestr
END FUNCTION
