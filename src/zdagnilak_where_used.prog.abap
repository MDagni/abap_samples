**********************************************************************
* Kaynak:
* https://wiki.scn.sap.com/wiki/display/TechTSG/Code+to+rebuild+object+list+aka+where-used+lists
**********************************************************************

report zdagnilak_where_used.

* PLEASE RUN THIS PROGRAM IN BACKGROUND!
* The program will rebuild programs which belong to either:
*   - the entered software component and program names
*   - or the entered packages and program names
*   - or the entered programs only
* If none of them are entered, nothing happens

**report z_saprseui.

data g_dummyso_devc type devclass.
data g_dummyso_prog type progname_2.

* software component
parameters pa_dlvun type dlvunit.
* package
select-options so_devc for g_dummyso_devc.
* program
select-options so_prog for g_dummyso_prog.

at selection-screen on value-request for so_prog-low.

start-of-selection.
  perform main.

*
form main.
  data lt_tdevc type table of tdevc.
  data ls_tdevc type tdevc.
  data lt_tadir type table of tadir.
  data ls_tadir type tadir.
  data l_repid type rsnewleng-programm.
  data lt_repid type table of rsnewleng-programm.

  if not pa_dlvun is initial.
    select * from tdevc
              into table lt_tdevc
              where dlvunit = pa_dlvun
                and devclass in so_devc.
  elseif so_devc[] is not initial.
    select * from tdevc
              into table lt_tdevc
              where devclass in so_devc.
  elseif so_prog[] is not initial.
    select name from trdir into table lt_repid where name in so_prog.
  endif.

* Pour chaque package, reconstruction des Object List de tous
* ses programmes
  loop at lt_tdevc into ls_tdevc.
    select * from tadir into table lt_tadir
        where pgmid = 'R3TR'
          and object in ('FUGR','FUGS','FUGX','PROG','TYPE','CLAS','INTF','LDBA','CNTX')
          and devclass = ls_tdevc-devclass.
    loop at lt_tadir into ls_tadir.
      call function 'RS_TADIR_TO_PROGNAME'
        exporting
          object   = ls_tadir-object
          obj_name = ls_tadir-obj_name
        importing
          progname = l_repid.
      if l_repid is not initial and l_repid in so_prog.
        append l_repid to lt_repid.
      endif.
    endloop.
  endloop.

  loop at lt_repid into l_repid.
    submit saprseui
        with repname = l_repid
        and return.
    commit work.
  endloop.

endform.                    "main
