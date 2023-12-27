" https://serkanozcan.com/sap-islem-kodu-ile-user-exit-bulma-ve-user-exit-implementasyonu-badi-enhancement-program-exit-bte-workflow/
" adresinden alınmıştır.

*&--------------------------------------------------------------------&*
*& Report:       Z_USEREXIT(V10)                                &*
*&--------------------------------------------------------------------&*
*& Selection Texts:
*& P_ALV   ALV format
*& P_AUTH   Include authority-check search
*& P_BADI   Display BADIs
*& P_CUSB   Customer BADIs only
*& P_BTE   Display business trans events
*& P_DEVC   Show development class exits
*& P_EXIT   Display user exits
*& P_FUNC   Show function modules
*& P_LIMIT   Limit no. of submits to search
*& P_LST   Standard list format
*& P_PNAME   Program name
*& P_PROG   Display program exits
*& P_SUBM   Show submits
*& P_TCODE   Transaction code
*& P_TEXT   Search for text
*& P_WFLOW   Display workflow links
*&--------------------------------------------------------------------&*
*& Text symbols:
*& M01   Enter TCode or program
*& M02   Enter at least one scope criteria
*& S01   Selection data (TCode takes precedence over program name)
*& S02   Scope criteria
*& S03   Display criteria
*&--------------------------------------------------------------------&*
report  z_userexit
  no standard page heading
  line-size 201.

tables: sxs_attr,
        tobjt,
        tstct,               "TCode texts
        trdirt,              "Program texts
        sxc_exit.            "BADI exits

type-pools: slis.

data: tabix         like sy-tabix,
      w_linnum      type i,
      w_off         type i,
      w_index       like sy-tabix,
      w_include     like trdir-name,
      w_prog        like trdir-name,
      w_incl        like trdir-name,
      w_area        like rs38l-area,
      w_level,
      w_str(50)     type c,
      w_cnt(2)      type c,
      w_funcname    like tfdir-funcname,
      w_fsel        like sy-ucomm,    " Determination of screen field
      w_gridtxt(70) type c.           "ALV grid title

constants: c_fmod(40) type c value 'Function modules searched: ',
           c_subm(40) type c value 'Submit programs searched: ',
           c_devc(60) type c value 'User-exits from development classes in function modules',
           c_col1(12) type c value 'Enhanmt Type',
           c_col2(40) type c value 'Enhancement',
           c_col3(30) type c value 'Program/Include',
           c_col4(20) type c value 'Enhancement Name',
           c_col5(40) type c value 'Enhancement Description',
           c_col6(8)  type c value 'Project',
           c_col7(1)  type c value 'S',
           c_col8(12) type c value 'ChangeName',
           c_col9(10) type c value 'ChangeDate',
           c_x        type c value 'X'.

* Work Areas: ABAP Workbench
data: begin of wa_d010inc.
data: master type d010inc-master.
data: end of wa_d010inc.

data: begin of wa_tfdir.
data: funcname type tfdir-funcname,
      pname    type tfdir-pname,
      include  type tfdir-include.
data: end of wa_tfdir.

data: begin of wa_tadir.
data: devclass type tadir-devclass.
data: end of wa_tadir.

data: begin of wa_tstc.
data: pgmna type tstc-pgmna.
data: end of wa_tstc.

data: begin of wa_tstcp.
data: param type tstcp-param.
data: end of wa_tstcp.

data: begin of wa_enlfdir.
data: area type enlfdir-area.
data: end of wa_enlfdir.

* Work Areas: BADIs
data: begin of wa_sxs_attr.
data: exit_name type sxs_attr-exit_name.
data: end of wa_sxs_attr.

data: begin of wa_sxs_attrt.
data: text type sxs_attrt-text.
data: end of wa_sxs_attrt.

* Work Areas: Enhancements
data: begin of wa_modsap.
data: member type modsap-member.
data: end of wa_modsap.

data: begin of wa_modsapa.
data: name type modsapa-name.
data: end of wa_modsapa.

data: begin of wa_modsapt.
data: modtext type modsapt-modtext.
data: end of wa_modsapt.

* Work Areas: Business Transaction Events
data: begin of wa_tbe01t.
data: text1 type tbe01t-text1.
data: end of wa_tbe01t.

data: begin of wa_tps01t.
data: text1 type tps01t-text1.
data: end of wa_tps01t.

* user-exits
types:  begin of ty_mod,
          member like modact-member,
          name   like modact-name,
          status like modattr-status,
          anam   like modattr-anam,
          adat   like modattr-adat,
        end of ty_mod.
data:   w_mod  type ty_mod.

types: begin of t_userexit,
         type(12)    type c,
         pname       like trdir-name,
         txt(300),
         level       type c,
         modname(30) type c,
         modtext(60) type c,
         modattr     type ty_mod,
         colour(4)   type c,
       end of t_userexit.
data: i_userexit type standard table of t_userexit with header line.

* Function module developmnet classes
types: begin of t_devclass,
         clas like trdir-clas,
       end of t_devclass.
data: i_devclass type standard table of t_devclass with header line.

* Submit programs
types: begin of t_submit,
         pname like trdir-name,
         level,
         done,
       end of t_submit.
data: i_submit type standard table of t_submit with header line.

* Source code
types: begin of t_sourcetab,
         line(255),
       end of t_sourcetab.
data: sourcetab type standard table of t_sourcetab with header line.
data c_overflow(30000) type c.

* Description of an ABAP/4 source analysis token
data: i_stoken type standard table of stokex with header line.
data wa_stoken like i_stoken.

* Description of an ABAP/4 source analysis statement
data: i_sstmnt type standard table of sstmnt with header line. "#EC NEEDED

* keywords for searching ABAP code
types: begin of t_keywords,
         word(30),
       end of t_keywords.
data: keywords type standard table of t_keywords with header line.

* function modules within program
types: begin of t_fmodule,
         name   like rs38l-name,
         pname  like trdir-name,
         pname2 like trdir-name,
         level,
         bapi,
         done,
       end of t_fmodule.
data: i_fmodule type standard table of t_fmodule with header line.

* ALV definitions
data i_fieldcat type slis_t_fieldcat_alv with header line.
data i_layout   type slis_layout_alv.
data i_sort     type slis_t_sortinfo_alv with header line.

*&--------------------------------------------------------------------&*
*& Selection Options                                                  &*
*&--------------------------------------------------------------------&*
selection-screen begin of block selscr1 with frame title text-s01.
parameter: p_pname like trdir-name,
           p_tcode like syst-tcode,
           p_limit(4) type n default 500.
selection-screen skip.
selection-screen end of block selscr1.

selection-screen begin of block selscr2 with frame title text-s02.
parameter: p_badi  as checkbox default c_x,
           p_cusb  as checkbox default c_x,
           p_bte   as checkbox default c_x,
           p_exit  as checkbox default c_x,
           p_prog  as checkbox default c_x,
           p_wflow as checkbox,
           p_auth  as checkbox.
selection-screen skip.
parameter: p_text(40) type c.
selection-screen end of block selscr2.

selection-screen begin of block selscr3 with frame title text-s03.
parameter: p_alv radiobutton group rad1 default 'X',
           p_lst radiobutton group rad1.
selection-screen skip.
parameter: p_devc  like rihea-dy_ofn default ' ' modif id a01,
           p_func  like rihea-dy_ofn default ' ' modif id a01,
           p_subm  like rihea-dy_ofn default ' ' modif id a01.
selection-screen end of block selscr3.

*&--------------------------------------------------------------------&*
*& START-OF-SELECTION                                                 &*
*&--------------------------------------------------------------------&*
start-of-selection.

  if p_pname is initial and p_tcode is initial.
    message i000(g01) with text-m01.
    stop.
  endif.

  if p_badi  is initial and
     p_exit  is initial and
     p_bte   is initial and
     p_wflow is initial and
     p_auth  is initial and
     p_prog  is initial.
    message i000(g01) with text-m02.
    stop.
  endif.

* ensure P_LIMIT is not zero.
  if p_limit = 0.
    p_limit = 1.
  endif.

  perform data_select.
  perform get_submit_data.
  perform get_fm_data.
  perform get_additional_data.
  perform data_display.

*&--------------------------------------------------------------------&*
*& Form DATA_SELECT                                                   &*
*&--------------------------------------------------------------------&*
*&                                                                    &*
*&--------------------------------------------------------------------&*
form data_select.

* data selection message to sap gui
  call function 'SAPGUI_PROGRESS_INDICATOR'
    destination 'SAPGUI'
    keeping logical unit of work
    exporting
      text = 'Get programs/includes'       "#EC NOTEXT
             exceptions
             system_failure
             communication_failure
    .                                                       "#EC *

* get TCode name for ALV grid title
  clear w_gridtxt.
  if not p_tcode is initial.
    select single * from tstct where tcode = p_tcode
                                 and sprsl = sy-langu.
    concatenate 'TCode:' p_tcode tstct-ttext into w_gridtxt
                                separated by space.
  endif.
* get program name for ALV grid title
  if not p_pname is initial.
    select single * from trdirt where name = p_pname
                                 and sprsl = sy-langu.
    concatenate 'Program:' p_pname tstct-ttext into w_gridtxt
                                separated by space.
  endif.

* determine search words
  keywords-word = 'CALL'.
  append keywords.
  keywords-word = 'FORM'.
  append keywords.
  keywords-word = 'PERFORM'.
  append keywords.
  keywords-word = 'SUBMIT'.
  append keywords.
  keywords-word = 'INCLUDE'.
  append keywords.
  keywords-word = 'AUTHORITY-CHECK'.
  append keywords.

  if not p_tcode is initial.
* get program name from TCode
    select single pgmna from tstc into wa_tstc-pgmna
                 where tcode eq p_tcode.
    if not wa_tstc-pgmna is initial.
      p_pname = wa_tstc-pgmna.
* TCode does not include program name, but does have reference TCode
    else.
      select single param from tstcp into wa_tstcp-param
                   where tcode eq p_tcode.
      if sy-subrc = 0.
        check wa_tstcp-param(1)   = '/'.
        check wa_tstcp-param+1(1) = '*'.
        if wa_tstcp-param ca ' '.
        endif.
        w_off = sy-fdpos + 1.
        subtract 2 from sy-fdpos.
        if sy-fdpos gt 0.
          p_tcode = wa_tstcp-param+2(sy-fdpos).
        endif.
        select single pgmna from tstc into wa_tstc-pgmna
               where tcode eq p_tcode.
        p_pname = wa_tstc-pgmna.
        if sy-subrc <> 0.
          message s110(/saptrx/asc) with 'No program found for: ' p_tcode. "#EC NOTEXT
          stop.
        endif.
      else.
        message s110(/saptrx/asc) with 'No program found for: ' p_tcode. "#EC NOTEXT
        stop.
      endif.

    endif.
  endif.

* Call customer-function aus Program coding
  read report p_pname into sourcetab.
  if sy-subrc > 0.
    message e017(enhancement) with p_pname raising no_program. "#EC *
  endif.

  scan abap-source sourcetab tokens     into i_stoken
                             statements into i_sstmnt
                             keywords   from keywords
                             overflow into c_overflow
                             with includes with analysis.   "#EC
  if sy-subrc > 0. "keine/syntakt. falsche Ablauflog./Fehler im Skanner
    message e130(enhancement) raising syntax_error.         "#EC
  endif.

* check I_STOKEN for entries
  clear w_linnum.
  describe table i_stoken lines w_linnum.
  if w_linnum gt 0.
    w_level = '0'.
    w_prog = ''.
    w_incl = ''.
    perform data_search tables i_stoken using w_level w_prog w_incl.
  endif.

endform.                        "DATA_SELECT

*&--------------------------------------------------------------------&*
*& Form GET_FM_DATA                                                   &*
*&--------------------------------------------------------------------&*
*&                                                                    &*
*&--------------------------------------------------------------------&*
form get_fm_data.

* data selection message to sap gui
  call function 'SAPGUI_PROGRESS_INDICATOR'
    destination 'SAPGUI'
    keeping logical unit of work
    exporting
      text = 'Get function module data'    "#EC NOTEXT
             exceptions
             system_failure
             communication_failure
    .                                                       "#EC *

* Function module data
  sort i_fmodule by name.
  delete adjacent duplicates from i_fmodule comparing name.

  loop at i_fmodule where done  ne c_x.

    clear:   i_stoken, i_sstmnt, sourcetab, wa_tfdir, w_include .
    refresh: i_stoken, i_sstmnt, sourcetab.

    clear wa_tfdir.
    select single funcname pname include from tfdir into wa_tfdir
                            where funcname = i_fmodule-name.
    check sy-subrc = 0.

    call function 'FUNCTION_INCLUDE_SPLIT'
      exporting
        program = wa_tfdir-pname
      importing
        group   = w_area.

    concatenate 'L' w_area 'U' wa_tfdir-include into w_include.
    i_fmodule-pname  = w_include.
    i_fmodule-pname2 = wa_tfdir-pname.
    modify i_fmodule.

    read report i_fmodule-pname into sourcetab.
    if sy-subrc = 0.

      scan abap-source sourcetab tokens     into i_stoken
                                 statements into i_sstmnt
                                 keywords   from keywords
                                 with includes
                                 with analysis.
      if sy-subrc > 0.
        message e130(enhancement) raising syntax_error.
      endif.

* check i_stoken for entries
      clear w_linnum.
      describe table i_stoken lines w_linnum.
      if w_linnum gt 0.
        w_level = '1'.
        w_prog  = i_fmodule-pname2.
        w_incl =  i_fmodule-pname.
        perform data_search tables i_stoken using w_level w_prog w_incl.
      endif.
    endif.

  endloop.

* store development classes
  if p_devc = c_x.
    loop at i_fmodule.
      clear: wa_tadir, wa_enlfdir.

      select single area from enlfdir into wa_enlfdir-area
                            where funcname = i_fmodule-name.
      check not wa_enlfdir-area is initial.

      select single devclass into wa_tadir-devclass
                      from tadir where pgmid    = 'R3TR'
                                   and object   = 'FUGR'
                                   and obj_name = wa_enlfdir-area.
      check not wa_tadir-devclass is initial.
      move wa_tadir-devclass to i_devclass-clas.
      append i_devclass.
      i_fmodule-done = c_x.
      modify i_fmodule.
    endloop.

    sort i_devclass.
    delete adjacent duplicates from i_devclass.
  endif.

endform.                        "GET_FM_DATA

*&--------------------------------------------------------------------&*
*& Form GET_SUBMIT_DATA                                               &*
*&--------------------------------------------------------------------&*
*&                                                                    &*
*&--------------------------------------------------------------------&*
form get_submit_data.

* data selection message to sap gui
  call function 'SAPGUI_PROGRESS_INDICATOR'
    destination 'SAPGUI'
    keeping logical unit of work
    exporting
      text = 'Get submit data'             "#EC NOTEXT
             exceptions
             system_failure
             communication_failure
    .                                                       "#EC *

  sort i_submit.
  delete adjacent duplicates from i_submit comparing pname.
  w_level = '0'.

  loop at i_submit where done ne c_x.

    clear:   i_stoken, i_sstmnt, sourcetab.
    refresh: i_stoken, i_sstmnt, sourcetab.

    read report i_submit-pname into sourcetab.
    if sy-subrc = 0.

      scan abap-source sourcetab tokens     into i_stoken
                                 statements into i_sstmnt
                                 keywords   from keywords
                                 with includes
                                 with analysis.
      if sy-subrc > 0.
*        message e130(enhancement) raising syntax_error.
        continue.
      endif.

* check i_stoken for entries
      clear w_linnum.
      describe table i_stoken lines w_linnum.
      if w_linnum gt 0.
        w_prog  = i_submit-pname.
        w_incl = ''.
        perform data_search tables i_stoken using w_level w_prog w_incl.
      endif.
    endif.

* restrict number of submit program selected for processing
    describe table i_submit lines w_linnum.
    if w_linnum ge p_limit.
      w_level = '1'.
    endif.
    i_submit-done = c_x.
    modify i_submit.
  endloop.

endform.                       "GET_SUBMIT_DATA

*&--------------------------------------------------------------------&*
*& Form DATA_SEARCH                                                   &*
*&--------------------------------------------------------------------&*
*&                                                                    &*
*&--------------------------------------------------------------------&*
form data_search tables p_stoken structure stoken
                        using p_level l_prog l_incl.

  loop at p_stoken.

    clear i_userexit.

* Workflow
    if p_wflow = c_x.
      if p_level eq '1'.    " do not perform for function modules (2nd pass)
        if  p_stoken-str+1(16) cs 'SWE_EVENT_CREATE'.
          replace all occurrences of '''' in p_stoken-str with ''.
          i_userexit-type = 'WorkFlow'.
          i_userexit-txt  = p_stoken-str.
          concatenate l_prog '/' l_incl into i_userexit-pname.
          append i_userexit.
        endif.
      endif.
    endif.

    tabix = sy-tabix + 1.
    i_userexit-level = p_level.
    if i_userexit-level = '0'.
      if l_incl is initial.
        i_userexit-pname = p_pname.
      else.
        concatenate  p_pname '-' l_incl into i_userexit-pname.
      endif.
    else.
      if l_incl is initial.
        i_userexit-pname = l_prog.
      else.
        concatenate  l_prog '-' l_incl into i_userexit-pname.
      endif.
    endif.

* AUTHORITY-CHECKS
    if p_auth = c_x.
      if p_stoken-str eq 'AUTHORITY-CHECK'.
        check p_level eq '0'.    " do not perform for function modules (2nd pass)
        w_index = sy-tabix + 2.
        read table p_stoken index w_index into wa_stoken.
        check not wa_stoken-str cs 'STRUCTURE'.
        check not wa_stoken-str cs 'SYMBOL'.
        read table i_submit with key pname = wa_stoken-str.
        if sy-subrc <> 0.
          i_userexit-pname = i_submit-pname.
          i_userexit-type = 'AuthCheck'.
          i_userexit-txt  = wa_stoken-str.
          replace all occurrences of '''' in i_userexit-txt with space.
          clear tobjt.
          select single * from tobjt where object = i_userexit-txt
                                       and langu  = sy-langu.
          i_userexit-modname = 'AUTHORITY-CHECK'.
          i_userexit-modtext = tobjt-ttext.
          append i_userexit.
        endif.
      endif.
    endif.

* Text searches
    if not p_text is initial.
      if p_stoken-str cs p_text.
        i_userexit-pname = i_submit-pname.
        i_userexit-type = 'TextSearch'.
        i_userexit-txt  = wa_stoken-str.
        i_userexit-modname = 'Text Search'.
        i_userexit-modtext = p_stoken-str.
        append i_userexit.
      endif.
    endif.

* Include (SE38)
    if p_stoken-str eq 'INCLUDE'.
      check p_level eq '0'.    " do not perform for function modules (2nd pass)
      w_index = sy-tabix + 1.
      read table p_stoken index w_index into wa_stoken.
      check not wa_stoken-str cs 'STRUCTURE'.
      check not wa_stoken-str cs 'SYMBOL'.
      read table i_submit with key pname = wa_stoken-str.
      if sy-subrc <> 0.
        i_submit-pname = wa_stoken-str.
        i_submit-level = p_level.
        append i_submit.
      endif.
    endif.

* Enhancements (SMOD)
    if p_exit = c_x.
      if p_stoken-str eq 'CUSTOMER-FUNCTION'.
        clear w_funcname.
        read table p_stoken index tabix.
        translate p_stoken-str using ''' '.
        condense p_stoken-str.
        if l_prog is initial.
          concatenate 'EXIT' p_pname p_stoken-str into w_funcname
                       separated by '_'.
        else.
          concatenate 'EXIT' l_prog p_stoken-str into w_funcname
                 separated by '_'.
        endif.
        select single member from modsap into wa_modsap-member
              where member = w_funcname.
        if sy-subrc = 0.   " check for valid enhancement
          i_userexit-type = 'Enhancement'.
          i_userexit-txt  = w_funcname.
          append i_userexit.
        else.
          clear wa_d010inc.
          select single master into wa_d010inc-master
                from d010inc
                   where include = l_prog.
          concatenate 'EXIT' wa_d010inc-master p_stoken-str into w_funcname
                 separated by '_'.
          i_userexit-type = 'Enhancement'.
          i_userexit-txt  = w_funcname.
        endif.
      endif.
    endif.

* BADIs (SE18)
    if p_badi = c_x.
      if p_stoken-str cs 'cl_exithandler='.
        w_index = sy-tabix + 4.
        read table p_stoken index w_index into wa_stoken.
        i_userexit-txt = wa_stoken-str.
        replace all occurrences of '''' in i_userexit-txt with space.
        i_userexit-type = 'BADI'.
        clear sxs_attr.   " ensure a real BADI
        if p_cusb = c_x.   "customer BADIs only
          select single * from sxs_attr where exit_name = i_userexit-txt
                                          and internal <> c_x.
        else.
          select single * from sxs_attr where exit_name = i_userexit-txt.
        endif.
        if sy-subrc = 0.
          append i_userexit.
        endif.
      endif.
    endif.

* Business transaction events (FIBF)
    if p_bte = c_x.
      if p_stoken-str cs 'OPEN_FI_PERFORM'.
        i_userexit-type = 'BusTrEvent'.
        i_userexit-txt = p_stoken-str.
        replace all occurrences of '''' in i_userexit-txt with space.
        i_userexit-modname =  i_userexit-txt+16(8).
        case i_userexit-txt+25(1).
          when 'E'.
            clear wa_tbe01t.
            select single text1 into wa_tbe01t-text1 from tbe01t
                             where event = i_userexit-txt+16(8)
                               and spras = sy-langu.
            if wa_tbe01t-text1 is initial.
              i_userexit-modtext = ''.                      "#EC NOTEXT
            else.
              i_userexit-modtext = wa_tbe01t-text1.
            endif.
            i_userexit-modname+8 = '/P&S'.                  "#EC NOTEXT
          when 'P'.
            clear wa_tps01t.
            select single text1 into wa_tps01t-text1 from tps01t
                             where procs = i_userexit-txt+16(8)
                               and spras = sy-langu.
            i_userexit-modtext = wa_tps01t-text1.
            i_userexit-modname+8 = '/Process'.
        endcase.

        append i_userexit.
      endif.
    endif.

* Program exits (SE38)
    if p_prog = c_x.
      if p_stoken-str cs 'USEREXIT_'.
        check not p_stoken-str cs '-'.   " ensure not USEREXIT_XX-XXX
        check not p_stoken-str cs '('.   " ensure not SUBMIT_XX(X)
        i_userexit-type = 'Program Exit'.
        i_userexit-txt = p_stoken-str.
        replace all occurrences of '''' in i_userexit-txt with space.
        append i_userexit.
      endif.
    endif.

* Submit programs (SE38)
    if p_stoken-str cs 'SUBMIT'.
      check p_level eq '0'.    " do not perform for function modules (2nd pass)
      check not p_stoken-str cs '_'.   " ensure not SUBMIT_XXX
      w_index = sy-tabix + 1.
      read table p_stoken index w_index into wa_stoken.
      check not wa_stoken-str cs '_'.   " ensure not SUBMIT_XXX
      replace all occurrences of '''' in wa_stoken-str with space.
      read table i_submit with key pname = wa_stoken-str.
      if sy-subrc <> 0.
        i_submit-pname = wa_stoken-str.
        i_submit-level = p_level.
        append i_submit.
      endif.
    endif.

* Perform routines (which reference external programs)
    if p_stoken-str cs 'PERFORM'.
      check p_level eq '0'.    " do not perform for function modules (2nd pass)
      w_index = sy-tabix + 1.
      read table p_stoken index w_index into wa_stoken.
      if not wa_stoken-ovfl is initial.
        w_off = wa_stoken-off1 + 10.
        w_str = c_overflow+w_off(30).
        find ')' in w_str match offset w_off.
        if sy-subrc = 0.
          w_off = w_off + 1.
          wa_stoken-str = w_str(w_off).
        endif.
      endif.

      check wa_stoken-str cs '('.
      w_off = 0.
      while sy-subrc  = 0.
        if wa_stoken-str+w_off(1) eq '('.
          replace section offset w_off length 1 of wa_stoken-str with ''.
          replace all occurrences of ')' in wa_stoken-str with space.
          read table i_submit with key pname = wa_stoken-str.
          if sy-subrc <> 0.
            i_submit-pname = wa_stoken-str.
            append i_submit.
          endif.
          exit.
        else.
          replace section offset w_off length 1 of wa_stoken-str with ''.
          shift wa_stoken-str left deleting leading space.
        endif.
      endwhile.
    endif.

* Function modules (SE37)
    if p_stoken-str cs 'FUNCTION'.

      clear i_fmodule.
      if p_level eq '0'.    " do not perform for function modules (2nd pass)
        w_index = sy-tabix + 1.
        read table p_stoken index w_index into wa_stoken.

        if wa_stoken-str cs 'BAPI'.
          i_fmodule-bapi = c_x.
        endif.

        replace first occurrence of '''' in wa_stoken-str with space.
        replace first occurrence of '''' in wa_stoken-str with space.
        if sy-subrc = 4.   " didn't find 2nd quote (ie name truncated)
          clear wa_tfdir.
          concatenate wa_stoken-str '%' into wa_stoken-str.
          select single funcname into wa_tfdir-funcname from tfdir
                       where funcname like wa_stoken-str.
          if sy-subrc = 0.
            i_fmodule-name = wa_tfdir-funcname.
          else.
            continue.
          endif.
        else.
          i_fmodule-name = wa_stoken-str.
        endif.
        i_fmodule-level = p_level.
        append i_fmodule.
      endif.
    endif.

  endloop.

endform.                        "DATA_SEARCH

*&--------------------------------------------------------------------&*
*& Form GET_ADDITIONAL_DATA                                           &*
*&--------------------------------------------------------------------&*
*&                                                                    &*
*&--------------------------------------------------------------------&*
form get_additional_data.

* data selection message to sap gui
  call function 'SAPGUI_PROGRESS_INDICATOR'
    destination 'SAPGUI'
    keeping logical unit of work
    exporting
      text = 'Get additional data'         "#EC NOTEXT
             exceptions
             system_failure
             communication_failure
    .                                                       "#EC *

  loop at i_userexit.

* Workflow
    if i_userexit-type eq 'WorkFlow'.
      continue.
    endif.

* Enhancement data
    if  i_userexit-type cs 'Enh'.
      clear: wa_modsapa.
      select single name into wa_modsapa-name from modsap
                        where member = i_userexit-txt.
      check sy-subrc = 0.
      i_userexit-modname = wa_modsapa-name.

      clear wa_modsapt.
      select single modtext into wa_modsapt-modtext from modsapt
                        where name = wa_modsapa-name
                                     and sprsl = sy-langu.
      i_userexit-modtext = wa_modsapt-modtext.

* Get the CMOD project name
      clear w_mod.
      select single modact~member modact~name modattr~status
                    modattr~anam  modattr~adat
        into w_mod
        from modact
        inner join modattr
          on modattr~name = modact~name
        where modact~member = wa_modsapa-name
          and modact~typ    = space.
      if sy-subrc = 0.
        i_userexit-modattr  = w_mod.
      endif.
    endif.

* BADI data
    if  i_userexit-type eq 'BADI'.
      clear wa_sxs_attr.
      select single exit_name into wa_sxs_attr-exit_name from sxs_attr
                                    where exit_name = i_userexit-txt.
      if sy-subrc = 0.
        i_userexit-modname = i_userexit-txt.
      else.
        i_userexit-modname = 'Dynamic call'.                "#EC NOTEXT
      endif.
      clear wa_sxs_attrt.
      select single text into wa_sxs_attrt-text from sxs_attrt
                                     where exit_name = wa_sxs_attr-exit_name
                                       and sprsl = sy-langu.
      i_userexit-modtext = wa_sxs_attrt-text.
    endif.

* BADI Implementation
    if  i_userexit-type eq 'BADI'.
      clear sxc_exit.
      select count( * ) from sxc_exit where exit_name = i_userexit-txt.
      w_cnt = sy-dbcnt.
* determine id BADI is for interal or external use
      clear sxs_attr.
      select single * from sxs_attr where exit_name = i_userexit-txt.
      if sxs_attr-internal = 'X'.
        wa_sxs_attrt-text = 'SAP '.
      else.
        wa_sxs_attrt-text = 'CUST'.
      endif.
*        concatenate wa_sxs_attrt-text w_cnt into i_userexit-modattr-name
*        separated by space.
      write wa_sxs_attrt-text to i_userexit-modattr-name.
      write w_cnt             to i_userexit-modattr-name+5.
    endif.

    modify i_userexit.
  endloop.

* get enhancements via program package
  clear wa_tadir.
  select single devclass into wa_tadir-devclass from tadir
                             where pgmid    = 'R3TR'
                               and object   = 'PROG'
                               and obj_name = p_pname.
  if sy-subrc = 0.
    clear: wa_modsapa, wa_modsapt.
    select name from modsapa into wa_modsapa-name
                          where devclass = wa_tadir-devclass.
      select single modtext from modsapt into wa_modsapt-modtext
                          where name = wa_modsapa-name
                            and sprsl = sy-langu.

      clear i_userexit.
      read table i_userexit with key modname = wa_modsapa-name.
      if sy-subrc <> 0.
        i_userexit-modtext = wa_modsapt-modtext.
        i_userexit-type = 'Enhancement'.                    "#EC NOTEXT
        i_userexit-modname  = wa_modsapa-name.
        i_userexit-txt = 'Determined from program DevClass'. "#EC NOTEXT
        i_userexit-pname = 'Unknown'.                       "#EC NOTEXT
        append i_userexit.
      endif.
    endselect.
  endif.

* set row colour.
  loop at i_userexit.
    case i_userexit-type.
      when 'BADI'.
        i_userexit-colour = 'C601'.
      when 'Enhancement'.
        i_userexit-colour = 'C501'.
      when 'Program Exit'.
        i_userexit-colour = 'C401'.
      when 'WorkFlow'.
        i_userexit-colour = 'C301'.
      when 'BusTrEvent'.
        i_userexit-colour = 'C201'.
    endcase.
    modify i_userexit.
  endloop.

endform.                        "GET_ADDITIONAL_DATA

*&--------------------------------------------------------------------&*
*& Form DATA_DISPLAY                                                  &*
*&--------------------------------------------------------------------&*
*&                                                                    &*
*&--------------------------------------------------------------------&*
form data_display.

* data selection message to sap gui
  call function 'SAPGUI_PROGRESS_INDICATOR'
    destination 'SAPGUI'
    keeping logical unit of work
    exporting
      text = 'Prepare screen for display'  "#EC NOTEXT
             exceptions
             system_failure
             communication_failure
    .                                                       "#EC *

  sort i_userexit by type txt modname.
  delete adjacent duplicates from i_userexit comparing txt pname modname.

* ensure records selected.
  describe table i_userexit lines w_linnum.
  if w_linnum = 0.
    message s003(g00).   "No data records were selected
    exit.
  endif.

  if p_alv = ' '.

* format headings
    write: 'Enhancements from main program: ', p_pname.
    write: 'Enhancements from TCode: ', p_tcode.
    write: 201''.
    uline.
    format color col_heading.
    write: /    sy-vline,
           (12) c_col1,                    "Enhanmt Type
                sy-vline,
           (40) c_col2,                    "Enhancement
                sy-vline,
           (30) c_col3,                    "Program/Include
                sy-vline,
           (20) c_col4,                    "Enhancement name
                sy-vline,
           (40) c_col5,                    "Enhancement description
                sy-vline,
           (8)  c_col6,                    "Project
                sy-vline,
           (1)  c_col7,                    "S
                sy-vline,
           (12) c_col8,                    "ChangeName
                sy-vline,
           (10)  c_col9,                    "ChangeDate
                sy-vline.
    format reset.
    uline.

* format lines
    loop at i_userexit.
* set line colour
      case i_userexit-type.
        when 'Enhancement'.
          format color 3 intensified off.
        when 'BADI'.
          format color 4 intensified off.
        when 'BusTrEvent'.
          format color 5 intensified off.
        when 'Program Exit'.
          format color 6 intensified off.
        when others.
          format reset.
      endcase.
      write: / sy-vline,
               i_userexit-type,
               sy-vline,
               i_userexit-txt(40),
               sy-vline,
               i_userexit-pname(30),
               sy-vline,
               i_userexit-modname(20),
               sy-vline,
               i_userexit-modtext(40),
               sy-vline.

      write:  i_userexit-modattr-name,
              sy-vline,
              i_userexit-modattr-status,
              sy-vline,
              i_userexit-modattr-anam,
              sy-vline,
              i_userexit-modattr-adat no-zero,
              sy-vline.
      hide: i_userexit-modname, i_userexit-type, i_userexit-modattr-name.

    endloop.
    format reset.
    uline.

* user-exits from development class of function modules
    if p_devc = c_x.
      write: /.
      write: / c_devc.
      write: 201''.
      uline (90).
      write: 201''.

      loop at i_devclass.
        clear wa_modsapa.
        select name from modsapa into wa_modsapa
                     where devclass = i_devclass-clas.
          select single name modtext into corresponding fields of wa_modsapt
                                     from modsapt
                                       where name  = wa_modsapa-name
                                         and sprsl = sy-langu.
          format color 3 intensified off.
          write: / sy-vline,
                   (12) 'Enhancement',
                   sy-vline,
                  wa_modsapa-name,
                  sy-vline,
                  wa_modsapt-modtext,
                  sy-vline.
        endselect.
      endloop.
      write: 201''.
      uline (90).
      format reset.
    endif.

* display fuction modules used in program
    write /.
    describe table i_fmodule lines w_linnum.
    write: / c_fmod , at 35 w_linnum.                       "#EC NOTEXT
    write: 201''.

    if p_func = c_x.
      uline (38).
      write: 201''.
      loop at i_fmodule.
        write: sy-vline,
               i_fmodule-name,
               sy-vline,
               i_fmodule-bapi,
               sy-vline.
        write: 201''.
      endloop.
      write: 201''.
      uline (38).
    endif.

* display submit programs used in program
    write /.
    describe table i_submit lines w_linnum.
    write: / c_subm , at 35 w_linnum.                       "#EC NOTEXT
    write: 201''.
    if p_subm = c_x.
      uline (44).
      write: 201''.
      loop at i_submit.
        write: sy-vline,
               i_submit-pname,
               sy-vline.
        write: 201''.
      endloop.
      write: 201''.
      uline (44).
    endif.

* issue message with number of user-exits displayed
    describe table i_userexit lines w_linnum.
    message s697(56) with w_linnum.

  else.    " Show in alv format

* issue message with number of user-exits displayed
    describe table i_userexit lines w_linnum.
    message s697(56) with w_linnum.

* Create field catalog
    perform create_field_catalog using 'TYPE'           'T_USEREXIT' ' ' 'Type'.
    perform create_field_catalog using 'PNAME'          'T_USEREXIT' ' ' 'Program name'.
    perform create_field_catalog using 'TXT'            'T_USEREXIT' ' ' 'Enhancement'.
    perform create_field_catalog using 'LEVEL'          'T_USEREXIT' c_x 'Level'.
    perform create_field_catalog using 'MODNAME'        'T_USEREXIT' ' ' 'Enhancement name'.
    perform create_field_catalog using 'MODTEXT'        'T_USEREXIT' ' ' 'Enhancement text'.
    perform create_field_catalog using 'MODATTR-MEMBER' 'T_USEREXIT' c_x 'Member'.
    perform create_field_catalog using 'MODATTR-NAME'   'T_USEREXIT' ' ' 'Project'.
    perform create_field_catalog using 'MODATTR-STATUS' 'T_USEREXIT' ' ' 'Status'.
    perform create_field_catalog using 'MODATTR-ANAM'   'T_USEREXIT' ' ' 'Changed by'.
    perform create_field_catalog using 'MODATTR-ADAT'   'T_USEREXIT' ' ' 'Change date'.

* Layout
    clear i_layout.
    i_layout-colwidth_optimize = c_x.
    i_layout-info_fieldname    = 'COLOUR'.

* Sort
    clear i_sort.
    i_sort-fieldname = 'TYPE'.
    i_sort-tabname   = 'T_USEREXIT'.
    i_sort-up = c_x.
    append i_sort.

    call function 'REUSE_ALV_GRID_DISPLAY'
      exporting
        i_callback_program      = sy-cprog
        i_callback_user_command = 'USER_COMMAND'
        is_layout               = i_layout
        it_fieldcat             = i_fieldcat[]
        it_sort                 = i_sort[]
        i_default               = c_x
        i_save                  = 'A'
        i_grid_title            = w_gridtxt
      tables
        t_outtab                = i_userexit.

  endif.

* issue message with number of user-exits displayed
  describe table i_userexit lines w_linnum.
  message s697(56) with w_linnum.

endform.                        "DATA_DISPLAY

*&---------------------------------------------------------------------&*
*& Form  CREATE_FIELD_CATALOG                                          &*
*&---------------------------------------------------------------------&*
form create_field_catalog using    p_fieldname
                                   p_tabname
                                   p_hide
                                   p_text.

  i_fieldcat-fieldname        = p_fieldname.
  i_fieldcat-tabname          = p_tabname.
  i_fieldcat-no_out           = p_hide.
  i_fieldcat-seltext_l        = p_text.

  append i_fieldcat.

endform.                    " CREATE_FIELD_CATALOG

*&---------------------------------------------------------------------&*
*& Form  CREATE_FIELD_CATALOG                                          &*
*&---------------------------------------------------------------------&*
form user_command using r_ucomm like sy-ucomm
                        rs_selfield type slis_selfield.
  read table i_userexit index rs_selfield-tabindex.
  check sy-subrc = 0.
  case r_ucomm.
    when '&IC1'.
      case rs_selfield-sel_tab_field.
        when 'T_USEREXIT-MODNAME'.
          read table i_userexit index rs_selfield-tabindex.
          case i_userexit-type.
            when 'Enhancement'.
              set parameter id 'MON' field i_userexit-modname.
              call transaction 'SMOD'.
            when 'BADI'.
              set parameter id 'EXN' field i_userexit-modname.
              call transaction 'SE18' and skip first screen.
            when 'BusTrEvent'.
              submit rfopfi00 with event = i_userexit-modname(8) and return.
            when others.
              message s030(cj). "Navigation not possible
          endcase.
        when 'T_USEREXIT-MODATTR-NAME'.
          if not i_userexit-modattr-name is initial.
            set parameter id 'MON_KUN' field i_userexit-modattr-name.
            call transaction 'CMOD'.
          else.
            message s030(cj)."Navigation not possible
          endif.
        when others.
          message s030(cj)."Navigation not possible
      endcase.
  endcase.

endform.                    "user_command

*&--------------------------------------------------------------------&*
*& AT LINE-SELECTION                                                  ௥*
*&--------------------------------------------------------------------&*
at line-selection.

  get cursor field w_fsel.

  case w_fsel.

    when 'I_USEREXIT-MODNAME'.
      case i_userexit-type.
        when 'Enhancement'.
          set parameter id 'MON' field i_userexit-modname.
          call transaction 'SMOD'.
        when 'BADI'.
          set parameter id 'EXN' field i_userexit-modname.
          call transaction 'SE18' and skip first screen.
        when 'BusTrEvent'.
          submit rfopfi00 with event = i_userexit-modname(8) and return.
        when others.
          message s030(cj)."Navigation not possible
      endcase.

    when 'I_USEREXIT-MODATTR-NAME'.
      if not i_userexit-modattr-name is initial.
        set parameter id 'MON_KUN' field i_userexit-modattr-name.
        call transaction 'CMOD'.
      else.
        message s030(cj)."Navigation not possible
      endif.

    when others.
      message s030(cj)."Navigation not possible

  endcase.

*&--------------------------------------------------------------------&*
*& AT SELECTION-SCREEN                                                &*
*&--------------------------------------------------------------------&*
at selection-screen on radiobutton group rad1.

* grey-out checkboxes if ALV selected
at selection-screen output.
  loop at screen.
    if p_alv = c_x.
      if screen-group1 = 'A01'.
        screen-input = '0'.
        modify screen.
      endif.
    else.
      if screen-group1 = 'A01'.
        screen-input = '1'.
        modify screen.
      endif.
    endif.
  endloop.
