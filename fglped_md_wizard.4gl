IMPORT FGL fgldialog
IMPORT FGL fglped_schema
IMPORT FGL fglped_utils

DEFINE mytables STRING
DEFINE afields DYNAMIC ARRAY OF RECORD
     atable STRING,
     acol STRING
END RECORD
DEFINE cfields DYNAMIC ARRAY OF RECORD
     ctable STRING,
     ccol STRING
END RECORD

FUNCTION colwizard(schema,init)
  DEFINE schema STRING
  DEFINE init INT
  DEFINE i INT
  DEFINE state STRING 
  DEFINE drag_index,drop_index INT
  DEFINE dnd ui.DragDrop
  DEFINE drag_source STRING
  DEFINE drag_value RECORD
     table STRING,
     col STRING
  END RECORD
  LET state="cancel"
  DISPLAY "colwizard,init:",init
  IF NOT fglped_readTables(schema) THEN
    RETURN state
  END IF
  OPEN FORM colwizard FROM "fglped_md_wizard"
  DISPLAY FORM colwizard
  IF init THEN
    CALL afields.clear()
    CALL cfields.clear()
  END IF
  OPTIONS FIELD ORDER FORM
  DIALOG ATTRIBUTES(UNBUFFERED)
    INPUT BY NAME mytables
      ON CHANGE mytables
        CALL on_change_mytables(DIALOG)
    END INPUT

    DISPLAY ARRAY afields TO afields.* 
      ON DRAG_START(dnd) -- DragSourceEvent 
         LET drag_source = "afields"
         LET drag_index = arr_curr()            
         LET drag_value.* = afields[drag_index].*
      ON DRAG_FINISHED(dnd) --DragSourceEvent
         INITIALIZE drag_source TO NULL
      ON DRAG_ENTER(dnd) --DropTargetEvent
         --we only accept items which come from the left or right hand side
         --nothing from the outer world is allowed to disturb
         IF drag_index IS NULL THEN
           CALL dnd.setOperation(NULL)
         END IF
      ON DROP (dnd) --DropTargetEvent
         LET drop_index = dnd.getLocationRow()            
         CALL DIALOG.insertRow("afields", drop_index)            
         LET afields[drop_index].* = drag_value.*
         IF drag_source == "afields" THEN -- self
           CALL DIALOG.setCurrentRow("afields", drop_index)
           IF drag_index > drop_index THEN
             LET drag_index = drag_index + 1
           END IF
         END IF
         CALL DIALOG.deleteRow(drag_source, drag_index)
         CALL updateActions(DIALOG)
    END DISPLAY 

    DISPLAY ARRAY cfields TO cfields.* 
      ON DRAG_START(dnd)
        LET drag_source = "cfields"
        LET drag_index = arr_curr()
        LET drag_value.* = cfields[drag_index].*
      ON DRAG_FINISHED(dnd)
        INITIALIZE drag_source TO NULL

      ON DRAG_ENTER(dnd)
        IF drag_source IS NULL THEN
          CALL dnd.setOperation(NULL)
        END IF
      ON DROP(dnd)
        LET drop_index = dnd.getLocationRow()
        CALL DIALOG.insertRow("cfields", drop_index)
        LET cfields[drop_index].* = drag_value.*
        IF drag_source == "cfields" THEN
          CALL DIALOG.setCurrentRow("cfields", drop_index)
          IF drag_index > drop_index THEN
            LET drag_index = drag_index + 1
          END IF
        END IF
        CALL DIALOG.deleteRow(drag_source, drag_index)
        CALL updateActions(DIALOG)
    END DISPLAY 

    BEFORE DIALOG
      CALL init_tables(DIALOG,init)
    ON ACTION right
      CALL right(DIALOG)
    ON ACTION allright
      CALL allright(DIALOG)
    ON ACTION left
      CALL left(DIALOG)
    ON ACTION allleft
      CALL allleft(DIALOG)
    ON ACTION prevwiz
      LET state="prev"
      EXIT DIALOG
    ON ACTION cancel
      LET state="cancel"
      EXIT DIALOG
    ON ACTION nextwiz
      LET state="next"
      GOTO accept_dialog
    ON ACTION accept
      LET state="accept"
LABEL accept_dialog:
      CALL fglped_wiz_columns.clear()
      IF cfields.getLength()==0 THEN
         CALL fgl_winMessage("fglped","You must choose a column before you can continue!","attention")
         CONTINUE DIALOG
      END IF
      FOR i=1 TO cfields.getLength()
        DISPLAY sfmt("table:%1,column:%2",cfields[i].ctable,cfields[i].ccol)
        LET fglped_wiz_columns[i].table_name=cfields[i].ctable
        LET fglped_wiz_columns[i].field_name=cfields[i].ccol
      END FOR
      EXIT DIALOG
  END DIALOG
  CLOSE FORM colwizard
  RETURN state
END FUNCTION


FUNCTION init_tables(d,init)
  DEFINE d ui.Dialog
  DEFINE init INT
  DEFINE cb ui.ComboBox
  DEFINE i INTEGER
  LET cb = ui.ComboBox.forName("formonly.mytables")
  IF cb IS NULL THEN
    CALL myerror("combobox not found")
  END IF
  IF init THEN
    CALL cfields.clear()
    LET mytables=fglped_tables[1]
  END IF
  FOR i=1 TO fglped_tables.getLength()
    CALL cb.addItem(fglped_tables[i],fglped_tables[i])
  END FOR
  CALL on_change_mytables(d)
END FUNCTION

--Function to be called for displaying the content of the left list
--according to the content of the tables combobox
FUNCTION on_change_mytables(d)
  DEFINE d ui.Dialog
  DEFINE tab,col STRING
  DEFINE col_len,used_col_len,idx,i,j,foundUsed INT
  DISPLAY "mytables:",mytables
  CALL afields.clear()
  LET idx=0
  LET col_len=fglped_columns.getLength()
  FOR i=1 TO col_len
    LET tab=fglped_columns[i].table_name
    LET col=fglped_columns[i].field_name
    LET used_col_len=cfields.getLength()
    LET foundUsed=FALSE
    FOR j=1 TO used_col_len
      IF cfields[j].ctable=tab AND cfields[j].ccol=col THEN
        LET foundUsed=TRUE
        EXIT FOR
      END IF
    END FOR
    IF NOT foundUsed AND tab=mytables THEN
      LET idx=idx+1
      LET afields[idx].atable=tab
      LET afields[idx].acol=col
    END IF
  END FOR
  CALL updateActions(d)
END FUNCTION

FUNCTION right(d)
  DEFINE d ui.Dialog
  DEFINE idx,lastC INT
  LET idx = d.getCurrentRow("a")
  DISPLAY "idx:",idx
  LET lastC=cfields.getLength()+1
  LET cfields[lastC].ctable=afields[idx].atable
  LET cfields[lastC].ccol=afields[idx].acol
  CALL afields.deleteElement(idx)
  CALL d.setCurrentRow("cfields",lastC)
  CALL updateActions(d)
END FUNCTION

FUNCTION allright(d)
  DEFINE d ui.Dialog
  DEFINE lastC,i INT
  LET lastC=cfields.getLength()
  FOR i=1 TO afields.getLength()
    LET lastC=lastC+1
    LET cfields[lastC].ctable=afields[i].atable
    LET cfields[lastC].ccol=afields[i].acol
  END FOR
  CALL afields.clear()
  CALL d.setCurrentRow("cfields",lastC)
  CALL updateActions(d)
END FUNCTION

FUNCTION left(d)
  DEFINE d ui.Dialog
  DEFINE idx,i INT
  DEFINE col, tab STRING
  LET idx =d.getCurrentRow("cfields")
  LET tab=cfields[idx].ctable
  LET col=cfields[idx].ccol
  CALL cfields.deleteElement(idx)
  CALL on_change_mytables(d)
  FOR i=1 TO afields.getLength()
    IF afields[i].atable=tab AND afields[i].acol=col THEN
      CALL d.setCurrentRow("afields",i)
      EXIT FOR
    END IF
  END FOR
END FUNCTION

FUNCTION allleft(d)
  DEFINE d ui.Dialog
  CALL cfields.clear()
  CALL on_change_mytables(d)
END FUNCTION

FUNCTION updateActions(d)
  DEFINE d ui.Dialog
  CALL d.setActionActive("right",afields.getLength()<>0)
  CALL d.setActionActive("allright",afields.getLength()<>0)
  CALL d.setActionActive("left",cfields.getLength()<>0)
  CALL d.setActionActive("allleft",cfields.getLength()<>0)
END FUNCTION
