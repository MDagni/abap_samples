" Kaynak:
" https://community.sap.com/t5/application-development-and-automation-blog-posts/development-dependencies-translator-with-transport/ba-p/13271261

" How to implement:
"
" In SE38 create a executable report in your SAP development system with name ZNM_TRANSLATOR and description Development Translation and Transport;
" Copy past code bellow and activate the program;
" Create/Fill corresponding Text Symbols and Selection Texts. Please check the meaning at top comments of the program;
" Go to transaction SE41, select button copy status and fill popup. After copy you can delete function codes not needed.
" From: SAPLSALV STANDARD
" To: ZNM_TRANSLATOR STATUS
" Edit status to add the following customer functions codes:
" DOWN with text Download Template and icon ICON_SAVE_AS_TEMPLATE;
" UP with text Upload Template and icon ICON_IMPORT;
" COPY with text Copy source language to targets and icon ICON_SYSTEM_COPY;
" TR with text Transport translations and icon ICON_IMPORT_TRANSPORT_REQUEST.


report zdagnilak_translator message-id 00.
" -----------------------------------------------------------------------
"  Created by NM for Object Dependencies translation and Transport
" -----------------------------------------------------------------------
"  Text Symbols
"  B01 Objects selection
"  B02 Options
"  C01 Obj. Desc.
"  C02 Source
"  C03 Targets
"  C04 Trans. St.
"  C05 Proc. St.
"  C06 Check St.
"  D01 Please select target language:
"  D02 Edit Translation
"  EX1 Executed with success
"  EX2 Executed with errors
"  F01 Translations
"  F02 Automatic translations. Continue?
"  G01 Upload Template
"  G02 Download Template
"  M01 Please fill all required fields
"  M02 Error opening file
"  M03 Objects not found
"  M04 No objects selected
"  M05 Transport not allowed for multiple targets
"  M06 No dependecies found
"  M07 Objects added to request
"  M08 Overwrite existent translations activated
"  M09 Transport canceled
"  M10 Request canceled, at least one object $TEMP detected
"  M11 File not valid
"  M12 File source language not valid
"  M13 File target languages not valid
"  M14 Error treating transport request
"  P01 Adding object
"  P02 Checking Dependecies
"  P03 Checking Translations
"  P04 Display objects
"  PB1 % Complete
"  T01 Object
"  T02 dependecies
"  T03 and translations
"
"  Selection Texts
"  P_DEP Dependencies check
"  P_OBJECT  Object Type
"  P_OBJ_N Object Name
"  P_OW  Overwrite translations
"  P_PGMID Program ID
"  P_SLANG Source Language
"  P_TR  Transport request
"  R_OBJ Add workbench objects
"  R_TR  Add from transport request
"  SO_TLANG  Target Languages
"
"  Standard Status GUI function codes: &ALL, &SAL, &OUP, &ODN, &ILT, %PC, &OL0, &OAD and &AVE
"  Status GUI function code: DOWN Download Template, UP Upload Template, COPY Copy source language to targets and TR Transport translations
"
" --------------------------------------------------------- GLOBAL DATA -
tables t002.                  " Language Keys
type-pools: abap, icon, ole2. " Only for old versions
" ----------------------------------------------------------- Constants -
constants gc_r3tr       type pgmid        value 'R3TR'.        " Main object
constants gc_temp       type developclass value '$TMP'.        " Local development class
constants gc_excel_ext  type string       value 'XLSX'.        " Excel file extension
constants gc_ieq        type c length 3   value 'IEQ'.         " Ranges
constants gc_pgmid      type c length 5   value 'PGMID'.       " Fields names
constants gc_object     type c length 6   value 'OBJECT'.
constants gc_lxe_object type c length 3   value 'LXE'.
constants gc_textkey    type c length 8   value 'TEXTPAIR'.
constants gc_length     type c length 6   value 'LENGTH'.
constants gc_desc       type c length 11  value 'DESCRIPTION'.
" ---------------------------------------------------------- Structures -
" ---------- Objects -----------
types:
  begin of gty_objects,
    status   type icon_d,       " Check status
    pgmid    type pgmid,        " Program ID in Requests and Tasks
    object   type trobjtype,    " Object Type
    obj_name type sobj_name,    " Object Name in Object Directory
    obj_desc type ddtext,       " Object Explanatory short text
    slang    type spras,        " Source Language
    tlangs   type string,       " Target Languages
    stattrn  type icon_d,       " Initial Translation status of an Object
    statproc type icon_d,       " Process Translation status of an Object
    devclass type developclass, " Development Package
    target   type tr_target,    " Transport Target of Request
  end of gty_objects.
" ---------- LXE Object Lists -----------
types:
  begin of gty_colob,
    pgmid    type pgmid,     " Program ID in Requests and Tasks
    object   type trobjtype, " Object Type
    obj_name type sobj_name. " Object Name in Object Directory
    include type lxe_colob. " Object Lists
types:
  end of gty_colob.
" ---------- Languages Informations -----------
types:
  begin of gty_languages,
    r3_lang    type c length 2, " R3 Language (Char 2)
    laiso      type laiso,      " Language according to ISO 639
    o_language type lxeisolang, " Translation Language
    text       type sptxt,      " Name of Language
  end of gty_languages.
set extended check off.
data gt_objects    type table of gty_objects.    " Objects to transport
data gt_objs_desc  type table of ko100.          " Objects prograns IDs
data gt_objs_colob type table of gty_colob.      " LXE Object Lists
data gt_languages  type table of gty_languages.  " Target Languages Informations
" ----------------------------------------------------------- Variables -
data gv_percent    type i.                    " Progress bar percentage
data gv_tlangs     type string.               " Target Languages
data gv_msg_text   type string.               " All Global Exceptions Text
data gv_object     type trobjtype.
" ------------------------------------------------------------- Objects -
data go_objects    type ref to cl_salv_table. " Objects ALV
data go_exp        type ref to cx_root.       " Abstract Superclass for All Global Exceptions
set extended check on.
*-------------------------------------- CLASS HANDLE EVENTS DEFINITION *
class lcl_handle_events definition final.
  public section.
    methods on_user_command for event added_function of cl_salv_events
      importing e_salv_function.

    methods on_double_click for event double_click of cl_salv_events_table
      importing !row !column ##NEEDED.
endclass.
*---------------------------------------------------- SELECTION SCREEN *
*---------------------------------------------------- Object selection *
selection-screen begin of block b01 with frame title text-b01.
  selection-screen skip 1.
  " ---------- Workbench object -----------
  parameters r_obj radiobutton group rbt user-command rbt default 'X'.
  selection-screen begin of line.
    selection-screen position 4.
    parameters:
      p_pgmid  type pgmid default gc_r3tr,  " Program ID in Requests and Tasks
      p_object type trobjtype default 'DEVC',              " Object Type
      p_obj_n  type sobj_name default ''.              " Object Name in Object Directory
  selection-screen end of line.
  " ---------- Transport request -----------
  selection-screen skip 1.
  parameters r_tr radiobutton group rbt.
  selection-screen begin of line.
    selection-screen position 4.
    parameters p_tr type trkorr.  " Transport request
  selection-screen end of line.
  selection-screen skip 1.
selection-screen end of block b01.
" -------------------------------------------------- Translation options -
selection-screen begin of block b02 with frame title text-b02.
  selection-screen skip 1.
  parameters p_slang type spras default 'TR'.          " Source Language
  select-options so_tlang for t002-spras no intervals default 'EN'.  " Target Languages
  selection-screen skip 1.
  parameters p_dep as checkbox default abap_true.  " Dependencies check
  parameters p_ow  as checkbox.  " Overwrite existent translations
selection-screen end of block b02.
*--------------------------------------------- SELECTION SCREEN EVENTS *
*------------------------------------------------------- Program ID F4 *
at selection-screen on value-request for p_pgmid.
  perform pgmid_f4.
  " ------------------------------------------------------ Object Type F4 -
at selection-screen on value-request for p_object.
  perform object_f4.
  " ------------------------------------------------------ Object Name F4 -
at selection-screen on value-request for p_obj_n.
  perform object_name_f4.
  " --------------------------------------------------- Transport request -
at selection-screen on value-request for p_tr.
  call function 'TR_F4_REQUESTS'
    importing ev_selected_request = p_tr.
  " ----------------------------------------- Selection Screen Events PAI -
at selection-screen.
  perform screen_pai.
*------------------------------------------------------- REPORT EVENTS *
*----------------------------------------------- Initialization events *
initialization.
  perform load_of_program.
  " ---------------------------------------------------- Executing events -
start-of-selection.
  perform run_checks.

end-of-selection.
  perform display_objects.
  " --------------------------------------------------------------- FORMS -
  " ------------------------------------------------ Form LOAD_OF_PROGRAM -
form load_of_program.
  data lt_restrict  type sscr_restrict. " Select Options Restrict
  data lt_opt_list  type sscr_opt_list.
  data lt_associate type sscr_ass.      " selection screen object

  " ---------- Fill Program IDs -----------
  call function 'TR_OBJECT_TABLE'
    tables wt_object_text = gt_objs_desc.
  " ---------- SC restrict SOs -----------
  lt_opt_list-name = gc_ieq+1(2).
  lt_opt_list-options-eq = abap_true.
  append lt_opt_list to lt_restrict-opt_list_tab.
  lt_associate-kind    = 'S'.
  lt_associate-name    = 'SO_TLANG'.
  lt_associate-sg_main = gc_ieq(1).
  lt_associate-sg_addy = space.
  lt_associate-op_main = gc_ieq+1(2).
  lt_associate-op_addy = gc_ieq+1(2).
  append lt_associate to lt_restrict-ass_tab.
  call function 'SELECT_OPTIONS_RESTRICT'
    exporting  restriction            = lt_restrict
    exceptions too_late               = 1
               repeated               = 2
               selopt_without_options = 3
               selopt_without_signs   = 4
               invalid_sign           = 5
               empty_option_list      = 6
               invalid_kind           = 7
               repeated_kind_a        = 8
               others                 = 9.
  if sy-subrc is not initial.
    message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  endif.
endform.

" ------------------------------------------------------- Form PGMID_F4 -
form pgmid_f4.
  data lt_pgmids type table of ko101.  " Program IDs with Description

  " ---------- Read PGMID -----------
  call function 'TR_PGMID_TABLE'
    tables wt_pgmid_text = lt_pgmids.
  " ---------- Set PGMID F4 -----------
  call function 'F4IF_INT_TABLE_VALUE_REQUEST'
    ##FM_SUBRC_OK
    exporting  retfield        = 'PGMID'
               dynpprog        = sy-cprog
               value_org       = 'S'
               dynpnr          = '1000'
               dynprofield     = 'TRE071X-PGMID'
    tables     value_tab       = lt_pgmids
    exceptions parameter_error = 1
               no_values_found = 2
               others          = 3.
endform.

" ------------------------------------------------------ Form OBJECT_F4 -
form object_f4.
  data lt_shlp          type shlp_descr.               " Description of Search Help
  data lt_return_values type table of ddshretval.      " Interface Structure Search Help
  data ls_return_values like line of lt_return_values.
  data lv_rc            type sysubrc.                  " Return Value of ABAP Statements
  field-symbols <interface> type ddshiface. " Interface description of a F4 help method

  " ---------- Get search help -----------
  call function 'F4IF_GET_SHLP_DESCR'
    exporting shlpname = 'SCTSOBJECT'
    importing shlp     = lt_shlp.
  " ---------- Fill search help -----------
  loop at lt_shlp-interface assigning <interface>.
    if <interface>-shlpfield = gc_object.
      <interface>-valfield = abap_true.
      <interface>-value    = gv_object.
    endif.
    if <interface>-shlpfield = gc_pgmid.
      <interface>-valfield = abap_true.
      <interface>-value    = p_pgmid.
    endif.
  endloop.
  " ---------- Call search help -----------
  call function 'F4IF_START_VALUE_REQUEST'
    exporting shlp          = lt_shlp
    importing rc            = lv_rc
    tables    return_values = lt_return_values.
  " ---------- Set search help return -----------
  if lv_rc is initial.
    read table lt_return_values into ls_return_values with key fieldname = gc_object.
    if sy-subrc is initial.
      p_object = ls_return_values-fieldval.
    endif.
    read table lt_return_values into ls_return_values with key fieldname = gc_pgmid.
    if sy-subrc is initial.
      p_pgmid = ls_return_values-fieldval.
    endif.
  endif.
endform.

" ------------------------------------------------- Form OBJECT_NAME_F4 -
form object_name_f4.
  data lv_object_type type seu_obj. " Object type

  " ---------- Get objects repository information -----------
  lv_object_type = p_object.
  call function 'REPOSITORY_INFO_SYSTEM_F4'
    ##FM_SUBRC_OK
    exporting  object_type          = lv_object_type
               object_name          = p_obj_n
    importing  object_name_selected = p_obj_n
    exceptions cancel               = 1
               wrong_type           = 2
               others               = 3.
endform.

" ----------------------------------------------------- Form SCREEN_PAI -
form screen_pai.
  gv_object = p_object.
  " ---------- Execute -----------
  if sy-ucomm <> 'ONLI'.
    return.
  endif.

  try.
      " ---------- Check and Read languages informations -----------
      perform check_languages.
      case abap_true.
        " ---------- Add object or dev class objects -----------
        when r_obj.
          perform execute_add_objects.
          " ---------- Add TR objects -----------
        when r_tr.
          perform execute_add_from_transport.
      endcase.
      " ---------- Check if objects found -----------
      if gt_objects is initial.
        message e398 with text-m03 space space space display like 'W'.  " Object not found
      endif.
      if p_ow is not initial.
        message w398 with text-m08 space space space. " Overwrite existent translations activated
      endif.
    catch cx_root into go_exp ##CATCH_ALL.
      message go_exp type 'I' display like 'E'.
*        gv_msg_text = go_exp->get_text( ).
*        message s398 with gv_msg_text space space space display like 'E'. "Critical error
  endtry.
endform.

" --------------------------------------------------- Form PROGRESS_BAR -
form progress_bar using i_value type itex132
                        i_tabix type i.

  data lv_text         type c length 40.
  data lv_percentage   type p length 8 decimals 0.
  data lv_percent_char type c length 3.

  lv_percentage = ( i_tabix / 100 ) * 100.
  lv_percent_char = lv_percentage.
  shift lv_percent_char left deleting leading space.
  concatenate i_value '...' into i_value.
  concatenate i_value lv_percent_char text-pb1 into lv_text separated by space.
  if lv_percentage > gv_percent or i_tabix = 1.
    call function 'SAPGUI_PROGRESS_INDICATOR'
      exporting percentage = lv_percentage
                text       = lv_text.
    gv_percent = lv_percentage.
  endif.
endform.

" ------------------------------------------------ Form DISPLAY_OBJECTS -
form display_objects.
  data lr_events        type ref to cl_salv_events_table.     " ALV Events
  data lr_display       type ref to cl_salv_display_settings. " ALV Output Appearance
  data lr_columns       type ref to cl_salv_columns_table.    " ALV Columns
  data lr_column        type ref to cl_salv_column_table.
  data lr_selections    type ref to cl_salv_selections.       " ALV Selections
  data lr_layout        type ref to cl_salv_layout.           " ALV Layout
  data lr_sorts         type ref to cl_salv_sorts.
  data lo_event_handler type ref to lcl_handle_events.        " ALV Events Handler
  data lt_column_ref    type salv_t_column_ref.               " Columns of ALV List
  data ls_column_ref    type salv_s_column_ref.
  data ls_key           type salv_s_layout_key.               " Layout Key
  data lv_title         type lvc_title.                       " ALV title
  data lv_lines         type i.                               " Number of objects
  data lv_lines_c       type string.

  perform progress_bar using text-p04
                             '90'. " Display objects
  if go_objects is not bound. " Create ALV
    try.
        if lines( gt_objects ) = 1.
          message s398 with text-m06 space space space display like 'W'.  " No dependecies found
        endif.
        " ---------- Create ALV -----------
        cl_salv_table=>factory( importing r_salv_table = go_objects
                                changing  t_table      = gt_objects ).
        " ---------- Set ALV Functions -----------
        go_objects->set_screen_status( pfstatus      = 'STATUS'
                                       report        = sy-cprog
                                       set_functions = go_objects->c_functions_all ).
        " ---------- Set Layout -----------
        lr_layout = go_objects->get_layout( ).
        ls_key-report = sy-repid.
        lr_layout->set_key( ls_key ).
        lr_layout->set_save_restriction( ).
        " ---------- Set ALV selections -----------
        lr_selections = go_objects->get_selections( ).
        lr_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).
        " ---------- Set ALV Display and Title -----------
        lr_display = go_objects->get_display_settings( ).
        lr_display->set_striped_pattern( if_salv_c_bool_sap=>true ).
        lv_lines = lines( gt_objects ).
        lv_lines_c = lv_lines.
        lv_lines_c = condense( val  = lv_lines_c
                               from = ` `
                               to   = `` ).
        concatenate '(' lv_lines_c ')' into lv_lines_c.
        if p_dep is initial.
          concatenate text-t01 p_pgmid p_object p_obj_n text-t02 lv_lines_c into lv_title separated by space.
        else.
          concatenate text-t01 p_pgmid p_object p_obj_n text-t02 text-t03 lv_lines_c into lv_title separated by space.
        endif.
        lr_display->set_list_header( lv_title ).
        " ---------- Set ALV Sorts -----------
        lr_sorts = go_objects->get_sorts( ).
        lr_sorts->add_sort( 'PGMID' ).
        lr_sorts->add_sort( 'OBJECT' ).
        lr_sorts->add_sort( 'OBJ_NAME' ).

        " ---------- Set ALV Columns -----------
        lr_columns = go_objects->get_columns( ).
        lr_columns->set_key_fixation( ).
        lr_columns->set_optimize( ).
        lt_column_ref = lr_columns->get( ).
        loop at lt_column_ref into ls_column_ref. " Default format for all columns
          lr_column ?= lr_columns->get_column( ls_column_ref-columnname ).
          lr_column->set_f4( if_salv_c_bool_sap=>false ).
          lr_column->set_alignment( if_salv_c_alignment=>centered ).
          " ---------- Check status -----------
          if ls_column_ref-columnname = 'STATUS'.
            lr_column->set_key( if_salv_c_bool_sap=>true ).
            lr_column->set_short_text( text-c06 ).  " Check St.
            lr_column->set_medium_text( text-c06 ).
            lr_column->set_long_text( text-c06 ).
          endif.
          " ---------- Object Keys -----------
          if    ls_column_ref-columnname = gc_pgmid
             or ls_column_ref-columnname = gc_object
             or ls_column_ref-columnname = 'OBJ_NAME'.
            lr_column->set_key( if_salv_c_bool_sap=>true ).
          endif.
          " ---------- Object name and development package -----------
          if    ls_column_ref-columnname = 'OBJ_NAME'
             or ls_column_ref-columnname = 'DEVCLASS'.
            lr_column->set_alignment( if_salv_c_alignment=>left ).
          endif.
          " ---------- Object description -----------
          if ls_column_ref-columnname = 'OBJ_DESC'.
            lr_column->set_alignment( if_salv_c_alignment=>left ).
            lr_column->set_short_text( text-c01 ).  " Obj. Desc.
            lr_column->set_medium_text( text-c01 ).
            lr_column->set_long_text( text-c01 ).
          endif.
          " ---------- Source Language -----------
          if ls_column_ref-columnname = 'SLANG'.
            lr_column->set_short_text( text-c02 ).  " Source
            lr_column->set_medium_text( text-c02 ).
            lr_column->set_long_text( text-c02 ).
          endif.
          " ---------- Target Languages -----------
          if ls_column_ref-columnname = 'TLANGS'.
            lr_column->set_short_text( text-c03 ).  " Targets
            lr_column->set_medium_text( text-c03 ).
            lr_column->set_long_text( text-c03 ).
          endif.
          " ---------- Translation status -----------
          if ls_column_ref-columnname = 'STATTRN'.
            lr_column->set_short_text( text-c04 ).  " Trans. St.
            lr_column->set_medium_text( text-c04 ).
            lr_column->set_long_text( text-c04 ).
          endif.
          " ---------- Process status -----------
          if ls_column_ref-columnname = 'STATPROC'.
            lr_column->set_short_text( text-c05 ).  " Proc. St.
            lr_column->set_medium_text( text-c05 ).
            lr_column->set_long_text( text-c05 ).
          endif.
        endloop.
        " ---------- Register ALV Events -----------
        lr_events = go_objects->get_event( ).
        lo_event_handler = new #( ).
        set handler lo_event_handler->on_user_command for lr_events.
        set handler lo_event_handler->on_double_click for lr_events.
        " ---------- Display Objects ALV -----------
        go_objects->display( ).
      catch cx_root into go_exp ##CATCH_ALL.
        message go_exp type 'I' display like 'E'.
    endtry.
  else. " Refresh ALV
    go_objects->refresh( ).
  endif.
endform.

*---------------------------------------------------------- FORMS ADDS *
*&---------------------------------------------------------------------*
*&      Form  CHECK_LANGUAGES
*&---------------------------------------------------------------------*
form check_languages.
  data ls_language like line of gt_languages. " Languages Informations
  data ls_tlang    like line of so_tlang.     " Target Languages

  if p_slang is initial or so_tlang[] is initial.
    " message e398 with text-m01 space space space display like 'W'.  "Please fill all required fields
    message text-m01 type 'I' display like 'W'.  " Please fill all required fields
  endif.
  ls_tlang = gc_ieq.
  ls_tlang-low = p_slang.
  append ls_tlang to so_tlang.
  refresh gt_languages.
  clear gv_tlangs.
  loop at so_tlang into ls_tlang where low is not initial.
    call function 'LXE_T002_CHECK_LANGUAGE'
      ##FM_SUBRC_OK " "#EC CI_SUBRC
      exporting  r3_lang            = ls_tlang-low
      importing  text               = ls_language-text      " Name of Language
                 o_language         = ls_language-o_language " Translation Language
      exceptions language_not_in_cp = 1
                 unknown            = 2
                 others             = 3.
    call function 'CONVERSION_EXIT_ISOLA_OUTPUT'
      exporting input  = ls_tlang-low
      importing output = ls_language-r3_lang.
    ls_language-laiso = ls_tlang-low. " Language according to ISO 639
    if ls_tlang-low <> p_slang.
      if gv_tlangs is initial.
        gv_tlangs = ls_language-r3_lang.
      else.
        concatenate gv_tlangs ls_language-r3_lang into gv_tlangs separated by space.
      endif.
    endif.
    append ls_language to gt_languages.
    clear ls_language.
  endloop.
  delete so_tlang where low = p_slang.
endform.

*&---------------------------------------------------------------------*
*&      Form  EXECUTE_ADD_OBJECTS
*&---------------------------------------------------------------------*
form execute_add_objects.
  data lt_objectlist type table of rseui_set.    " Transfer table (object list) - info system
  data ls_objectlist like line of lt_objectlist.
  data ls_env_dummy  type senvi.                 " Object in Development Environment
  data lv_devclass   type devclass.              " Package

  if p_pgmid is initial or p_object is initial or p_obj_n is initial.
    " message e398 with text-m01 space space space display like 'W'.  "Please fill all required fields
    message text-m01 type 'I' display like 'W'.  " Please fill all required fields
  endif.
  perform progress_bar using text-p01
                             '10'. " Adding object
  case p_object.
    when 'DEVC'.  " Get all development package objects
      lv_devclass = p_obj_n.
      call function 'RS_GET_OBJECTS_OF_DEVCLASS'
        ##FM_SUBRC_OK
        exporting  devclass            = lv_devclass
        tables     objectlist          = lt_objectlist
        exceptions no_objects_selected = 1
                   others              = 2.
      loop at lt_objectlist into ls_objectlist.
        perform check_add_object
          using gc_r3tr
                ls_objectlist-obj_type
                ls_objectlist-obj_name
                ls_env_dummy.
      endloop.
    when others.  " Add object
      perform check_add_object
        using p_pgmid
              p_object
              p_obj_n
              ls_env_dummy.
  endcase.
endform.

*&---------------------------------------------------------------------*
*&      Form  EXECUTE_ADD_FROM_TRANSPORT
*&---------------------------------------------------------------------*
form execute_add_from_transport.
  data lt_request_headers type trwbo_request_headers.
  data ls_request_headers type trwbo_request_header.
  data lt_objects         type tr_objects.
  data ls_object          type e071.
  data ls_env_dummy       type senvi.

  if p_tr is initial.
    " message e398 with text-m01 space space space display like 'W'.  "Please fill all required fields
    message text-m01 type 'I' display like 'W'.  " Please fill all required fields
  endif.
  perform progress_bar using text-p01
                             '10'. " Adding object
  " ---------- Read Requests and Tasks -----------
  call function 'TR_READ_REQUEST_WITH_TASKS'
    exporting  iv_trkorr          = p_tr
    importing  et_request_headers = lt_request_headers
    exceptions invalid_input      = 1
               others             = 2.
  if sy-subrc is not initial.
    " message e398 with text-m14 space space space display like 'W'.  "Error treating transport request
    message text-m14 type 'I' display like 'W'.  " Error treating transport request
  endif.
  " ---------- Read objects inside main request -----------
  read table lt_request_headers into ls_request_headers with key trfunction = 'K'.
  if sy-subrc is not initial.
    " message e398 with text-m14 space space space display like 'W'.  "Error treating transport request
    message text-m14 type 'I' display like 'W'.  " Error treating transport request
  endif.
  call function 'TR_GET_OBJECTS_OF_REQ_AN_TASKS'
    exporting  is_request_header      = ls_request_headers
               iv_condense_objectlist = 'X'
    importing  et_objects             = lt_objects
    exceptions invalid_input          = 1
               others                 = 2.
  if sy-subrc is not initial.
    " message e398 with text-m14 space space space display like 'W'.  "Error treating transport request
    message text-m14 type 'I' display like 'W'.  " Error treating transport request
  endif.
  call function 'TR_SORT_OBJECT_AND_KEY_LIST'
    changing ct_objects = lt_objects.
  loop at lt_objects into ls_object.  " Add found objects to processing
    perform check_add_object
      using ls_object-pgmid
            ls_object-object
            ls_object-obj_name
            ls_env_dummy.
  endloop.
endform.

" ----------------------------------------------- Form CHECK_ADD_OBJECT -
form check_add_object
  using value(i_pgmid) type pgmid
        i_object       type any
        i_obj_n        type any
        is_env_tab     type senvi.

  data lo_wb_object      type ref to cl_wb_object. " Repository Object
  data ls_tadir          type tadir.               " Directory of Repository Objects
  data ls_wb_object_type type wbobjtype.           " Global WB Type
  data ls_object         like line of gt_objects.  " Objects to transport line
  data lv_tr_object      type trobjtype.           " Object Type
  data lv_tr_obj_name    type trobj_name.          " Object Name in Object List
  data lv_trans_pgmid    type pgmid.               " Program ID in Requests and Tasks

  " Düzeltme! M.Dağnilak
  if is_env_tab-type = 'MESS'.
    concatenate is_env_tab-encl_obj is_env_tab-object into i_obj_n.
  endif.

  " ---------- Object convertions -----------
  if i_pgmid <> gc_r3tr.
    select pgmid
      up to 1 rows
      from tadir                "#EC CI_GENBUFF
      into i_pgmid
      where object   = i_object
        and obj_name = i_obj_n.
    endselect.
    " ---------- Is not a TADIR object and Conversion required -----------
    if sy-subrc is not initial.
      lv_tr_object = i_object.
      lv_tr_obj_name = i_obj_n.
      cl_wb_object=>create_from_transport_key( exporting  p_object                = lv_tr_object
                                                          p_obj_name              = lv_tr_obj_name
                                               receiving  p_wb_object             = lo_wb_object
                                               exceptions objecttype_not_existing = 1
                                                          empty_object_key        = 2
                                                          key_not_available       = 3
                                                          others                  = 4 ).
      if sy-subrc is initial.
        lo_wb_object->get_global_wb_key( importing  p_object_type     = ls_wb_object_type
                                         exceptions key_not_available = 1
                                                    others            = 2 ).
        if sy-subrc is initial.
          lo_wb_object->get_transport_key( importing  p_pgmid           = lv_trans_pgmid "#EC CI_SUBRC
                                           exceptions key_not_available = 1
                                                      others            = 2 ).
          " ---------- Check Program ID -----------
          case lv_trans_pgmid.
            when gc_r3tr.  " Main objects
              i_pgmid = lv_trans_pgmid.
            when 'LIMU'.  " Sub object
              call function 'GET_R3TR_OBJECT_FROM_LIMU_OBJ'
                exporting  p_limu_objtype = lv_tr_object
                           p_limu_objname = lv_tr_obj_name
                importing  p_r3tr_objtype = lv_tr_object
                           p_r3tr_objname = lv_tr_obj_name
                exceptions no_mapping     = 1
                           others         = 2.
              if sy-subrc is initial.
                ls_object-pgmid    = gc_r3tr.
                ls_object-object   = lv_tr_object.
                ls_object-obj_name = lv_tr_obj_name.
                perform add_object using ls_object.
                return.
              endif.
            when others.  " Include objects
              i_pgmid = gc_r3tr.
              call function 'GET_TADIR_TYPE_FROM_WB_TYPE'
                exporting  wb_objtype        = ls_wb_object_type-subtype_wb
                importing  transport_objtype = lv_tr_object
                exceptions no_mapping_found  = 1
                           no_unique_mapping = 2
                           others            = 3.
              if sy-subrc is initial.
                i_object = lv_tr_object.
                if is_env_tab-encl_obj is not initial.
                  i_obj_n = is_env_tab-encl_obj.
                endif.
              endif.
          endcase.
        endif.  " Global WB key
      endif.  " Transport_key
    endif.  " No a TADIR
  endif.  " Convertions
  " ---------- Check in TADIR -----------
  select single * from tadir
    into ls_tadir
    where pgmid    = i_pgmid
      and object   = i_object
      and obj_name = i_obj_n.
  " ---------- Add object -----------
  if ls_tadir is not initial.
    move-corresponding ls_tadir to ls_object.
    " ---------- Set SAP Generated object status -----------
    if ls_tadir-genflag is not initial.
      ls_object-status = icon_led_yellow.
    endif.
    " ---------- Add object to be checked -----------
    perform add_object using ls_object.
    " ---------- Error Object not valid -----------
  else.
    if lines( gt_objects ) > 0. " Skip first object
      ls_object-pgmid    = i_pgmid.
      ls_object-object   = i_object.
      ls_object-obj_name = i_obj_n.
      ls_object-status   = icon_led_red.
      perform add_object using ls_object.
    endif.
  endif.
endform.

" ----------------------------------------------------- Form ADD_OBJECT -
form add_object using ps_object type gty_objects.
  data ls_objs_desc like line of gt_objs_desc. " Objects prograns ID line"Info Environment
  data lt_devclass  type scts_devclass.        " Development Packages
  data ls_devclass  type trdevclass.
  data lv_object    type trobjtype.            " Object Type
  data lv_objname   type sobj_name.            " Object Name in Object Directory
  data lv_namespace type namespace.            " Object Namespace

  " ---------- Check if already added -----------
  if line_exists( gt_objects[ pgmid    = ps_object-pgmid
                              object   = ps_object-object
                              obj_name = ps_object-obj_name ] ). " New object
    return.
  endif.

  " ---------- Check if is customer object -----------
  lv_object  = ps_object-object.
  lv_objname = ps_object-obj_name.
  call function 'TRINT_GET_NAMESPACE'
    ##FM_SUBRC_OK
    exporting  iv_pgmid            = ps_object-pgmid
               iv_object           = lv_object
               iv_obj_name         = lv_objname
    importing  ev_namespace        = lv_namespace
    exceptions invalid_prefix      = 1
               invalid_object_type = 2
               others              = 3.
  if lv_namespace <> '/0CUST/'.  " Is customer object
    return.
  endif.

  " ---------- Read object description -----------
  read table gt_objs_desc into ls_objs_desc with key object = ps_object-object.
  if sy-subrc is initial.
    ps_object-obj_desc = ls_objs_desc-text.  " Object type description
  endif.
  " ---------- Read development class tecnical information -----------
  if ps_object-devclass is initial.
    select single devclass from tadir
      into ps_object-devclass
      where pgmid    = ps_object-pgmid
        and object   = ps_object-object
        and obj_name = ps_object-obj_name.
  endif.
  if ps_object-devclass is not initial and ps_object-devclass <> gc_temp.
    ls_devclass-devclass = ps_object-devclass.
    append ls_devclass to lt_devclass.
    call function 'TR_READ_DEVCLASSES'
      exporting it_devclass = lt_devclass
      importing et_devclass = lt_devclass.
    read table lt_devclass into ls_devclass index 1.
    if sy-subrc is initial.
      ps_object-target = ls_devclass-target.  " Development package target
    endif.
  endif.
  ps_object-slang  = p_slang.
  ps_object-tlangs = gv_tlangs.
  " ---------- Add object to transport -----------
  append ps_object to gt_objects.
endform.

" -------------------------------------------------------- FORMS CHECKS -
" ----------------------------------------------------- Form RUN_CHECKS -
form run_checks.
  try.
      " ---------- Dependecies check -----------
      perform objects_dependencies_check.
      " ---------- Translations check -----------
      perform objects_translations_check.
    catch cx_root into go_exp ##CATCH_ALL.
      message go_exp type 'I' display like 'E'.
*      gv_msg_text = go_exp->get_text( ).
*      message s398 with gv_msg_text space space space display like 'E'. "Critical error
  endtry.
endform.

" ------------------------------------- Form OBJECTS_DEPENDENCIES_CHECK -
form objects_dependencies_check.
  data lv_obj_type type seu_obj. " Object type
  data lt_env_tab  type table of senvi.  " Object to check dependencies
  data ls_env_tab  type senvi.   " Info Environment
  field-symbols <ls_object> like line of gt_objects. " Objects to transport

  perform progress_bar using text-p02
                             '30'. " Checking Dependecies
  loop at gt_objects assigning <ls_object> where status is initial.
    " ---------- Get object dependecies -----------
    if p_dep is not initial.
      refresh lt_env_tab.
      lv_obj_type = <ls_object>-object.
      call function 'REPOSITORY_ENVIRONMENT_RFC'
        exporting obj_type        = lv_obj_type
                  object_name     = <ls_object>-obj_name
        tables    environment_tab = lt_env_tab.
      delete lt_env_tab index 1.  " Delete first line
      " ---------- Add founded dependecies -----------
      loop at lt_env_tab into ls_env_tab.                "#EC CI_NESTED
        perform check_add_object
          using space
                ls_env_tab-type
                ls_env_tab-object
                ls_env_tab.
      endloop.
    endif.
    <ls_object>-status = icon_led_green.  " Status checked
  endloop.
endform.

" ------------------------------------- Form OBJECTS_TRANSLATIONS_CHECK -
form objects_translations_check.
  data lt_colob       type table of lxe_colob.    " Object Lists
  data ls_colob       like line of lt_colob.
  data ls_objs_colob  like line of gt_objs_colob. " LXE Objects
  data ls_tlang       like line of so_tlang.      " Target Languages
  data ls_language    like line of gt_languages.  " Languages Informations
  data ls_slanguage   like line of gt_languages.
  data lv_tr_obj_name type trobj_name.            " Object Name in Object List
  data lv_stattrn     type lxestattrn.            " Translation Status of an Object
  field-symbols <ls_object> like line of gt_objects. " Objects to transport

  perform progress_bar using text-p03
                             '60'. " Checking Translations
  " ---------- Checking Translations -----------
  refresh gt_objs_colob.
  loop at gt_objects assigning <ls_object> where status = icon_led_green.
    refresh lt_colob.
    lv_tr_obj_name = <ls_object>-obj_name.
    call function 'LXE_OBJ_EXPAND_TRANSPORT_OBJ'
      exporting  pgmid           = <ls_object>-pgmid
                 object          = <ls_object>-object
                 obj_name        = lv_tr_obj_name
      tables     ex_colob        = lt_colob
      exceptions unknown_object  = 1
                 unknown_ta_type = 2
                 others          = 3.
    " ---------- Check Status -----------
    if sy-subrc is not initial. " Error
      <ls_object>-status = icon_led_red.
      continue.
    endif.
    if lt_colob is initial. " No translation
      <ls_object>-status = icon_led_yellow.
    endif.
    " ---------- Initial Translation status -----------
    " ---------- Add to global LXE object tables -----------
    loop at lt_colob into ls_colob.                      "#EC CI_NESTED
      move-corresponding <ls_object> to ls_objs_colob.
      move-corresponding ls_colob    to ls_objs_colob.
      append ls_objs_colob to gt_objs_colob.
      clear ls_objs_colob.
      if <ls_object>-stattrn = icon_led_yellow.
        continue.
      endif.  " Status

      " ---------- Loop selected target language -----------
      loop at so_tlang into ls_tlang.                  "#EC CI_NESTED
        read table gt_languages into ls_language with key laiso = ls_tlang-low. " Read language tecnical info
        read table gt_languages into ls_slanguage with key laiso = p_slang.
        clear lv_stattrn.
        call function 'LXE_OBJ_TRANSLATION_STATUS2'
          exporting t_lang  = ls_language-o_language
                    s_lang  = ls_slanguage-o_language
                    custmnr = ls_colob-custmnr
                    objtype = ls_colob-objtype
                    objname = ls_colob-objname
          importing stattrn = lv_stattrn.
        if lv_stattrn = 'T'.  " Translated
          <ls_object>-stattrn = icon_led_green.
        else.
          <ls_object>-stattrn = icon_led_yellow.
          exit.
        endif.
      endloop.  " Target Languagues
    endloop.  " LXE Objects
  endloop.
endform.

*------------------------------------------------------- FORMS OPTIONS *
*----------------------------------------------- Form CREATE_TRANSPORT *
form create_transport tables lt_objects type standard table ##PERF_NO_TYPE.
  data lt_e071_temp  type table of e071.        " Change & Transport System: Object Entries of Requests/Tasks
  data lt_e071       type table of e071.
  data lt_e071k_temp type table of e071k.
  data ls_object     like line of gt_objects.
  data lt_targets    type table of tr_target.    " Transport Target of Request
  data ls_target     like line of lt_targets.
  data ls_objs_colob like line of gt_objs_colob. " LXE Objects
  data ls_tlang      like line of so_tlang.      " Target Languages
  data lv_order      type trkorr.                " Request/Task
  data lv_task       type trkorr.

  " ---------- Check selected objects to transport -----------
  loop at lt_objects into ls_object.
    if ls_object-devclass = gc_temp.
      " message i398 with text-m10 space space space display like 'E'.  "Request canceled, at least one object $TEMP detected
      message text-m10 type 'I' display like 'E'.  " Request canceled, at least one object $TEMP detected
      return.
    endif.
    ls_target = ls_object-target.
    append ls_target to lt_targets.
  endloop.
  " ---------- Check targets -----------
  sort lt_targets.
  delete adjacent duplicates from lt_targets.
  if lines( lt_targets ) > 1. " Only one valid target
*    message i398 with text-m05 space space space. "Transport not allowed for multiple targets
    message text-m05 type 'I'. " Transport not allowed for multiple targets
    return.
  endif.
  " ---------- Add translations to transport -----------
  loop at lt_objects into ls_object.
    loop at gt_objs_colob into ls_objs_colob where     pgmid    = ls_object-pgmid "#EC CI_NESTED
                                                   and object   = ls_object-object
                                                   and obj_name = ls_object-obj_name.
      loop at so_tlang into ls_tlang.                    "#EC CI_NESTED
        call function 'LXE_OBJ_CREATE_TRANSPORT_SE63'
          exporting language = ls_tlang-low
                    custmnr  = ls_objs_colob-custmnr
                    objtype  = ls_objs_colob-objtype
                    objname  = ls_objs_colob-objname
          tables    ex_e071  = lt_e071_temp.
        append lines of lt_e071_temp to lt_e071.
        refresh lt_e071_temp.
      endloop.
    endloop.
  endloop.
  " ---------- Check selected translations -----------
  if lt_e071 is initial.
*    message i398 with text-m04 space space space. "No objects selected
    message text-m04 type 'I'. " No objects selected
    return.
  endif.
  " ---------- Create or Select transport request -----------
  read table lt_targets into ls_target index 1.
  call function 'TRINT_ORDER_CHOICE'
    exporting  iv_tarsystem           = ls_target
    importing  we_order               = lv_order
               we_task                = lv_task
    tables     wt_e071                = lt_e071_temp
               wt_e071k               = lt_e071k_temp
    exceptions no_correction_selected = 1
               display_mode           = 2
               object_append_error    = 3
               recursive_call         = 4
               wrong_order_type       = 5
               others                 = 6.
  " ---------- Add object to transport request -----------
  if sy-subrc is initial and lv_task is not initial.
    refresh lt_e071k_temp.
    call function 'TRINT_APPEND_COMM'
      exporting  wi_exclusive       = abap_false
                 wi_sel_e071        = abap_true
                 wi_sel_e071k       = abap_true
                 wi_trkorr          = lv_task
      tables     wt_e071            = lt_e071
                 wt_e071k           = lt_e071k_temp
      exceptions e071k_append_error = 1
                 e071_append_error  = 2
                 trkorr_empty       = 3
                 others             = 4.
    " ---------- Sort and compress request ---------
    if sy-subrc is initial. " Added with success
      call function 'TR_SORT_AND_COMPRESS_COMM'
        ##FM_SUBRC_OK " "#EC CI_SUBRC
        exporting  iv_trkorr                      = lv_task
        exceptions trkorr_not_found               = 1
                   order_released                 = 2
                   error_while_modifying_obj_list = 3
                   tr_enqueue_failed              = 4
                   no_authorization               = 5
                   others                         = 6.
      message i398 with text-m07 lv_order space space display like 'S'.  " Objects added to request
    else.
      message i398 with text-ex2 space space space display like 'E'.  " Executed with errors
    endif.  " Added
  else.
    message s398 with text-m09 space space space display like 'W'.  " Transport canceled
  endif.
endform.

" ---------------------------------------------- Form COPY_TRANSLATIONS -
form copy_translations tables lt_objects type standard table ##PERF_NO_TYPE.
  data ls_object     like line of gt_objects.    " Objects to transport
  data ls_objs_colob like line of gt_objs_colob. " LXE Objects
  data ls_tlang      like line of so_tlang.      " Target Languages
  data lt_pcx_s1     type table of lxe_pcx_s1.  " Text Pairs
  data ls_pcx_s1     like line of lt_pcx_s1.
  data ls_tlanguage  like line of gt_languages.  " Languages Informations
  data ls_slanguage  like line of gt_languages.
  data lv_pstatus    type lxestatprc.            " Process Status
  data lv_stattrn    type lxestattrn.            " Translation Status of an Object
  field-symbols <ls_pcx_s1> like line of lt_pcx_s1.  " Text Pairs
  field-symbols <ls_object> like line of gt_objects. " Objects to translate

  " ---------- Read source language details -----------
  read table gt_languages into ls_slanguage with key laiso = p_slang.
  " ---------- Loop all selected objects -----------
  loop at lt_objects into ls_object.
    " ---------- Loop LXE Sub-Objects -----------
    loop at gt_objs_colob into ls_objs_colob where     pgmid    = ls_object-pgmid "#EC CI_NESTED
                                                   and object   = ls_object-object
                                                   and obj_name = ls_object-obj_name.
      " ---------- Loop selected target language -----------
      loop at so_tlang into ls_tlang.
        " ---------- Read target language details -----------
        clear ls_tlanguage.
        read table gt_languages into ls_tlanguage with key laiso = ls_tlang-low. " Read language tecnical info
        " ---------- Read texts -----------
        clear lv_pstatus.
        refresh lt_pcx_s1.
        call function 'LXE_OBJ_TEXT_PAIR_READ'
          exporting t_lang    = ls_tlanguage-o_language
                    s_lang    = ls_slanguage-o_language
                    custmnr   = ls_objs_colob-custmnr
                    objtype   = ls_objs_colob-objtype
                    objname   = ls_objs_colob-objname
                    read_only = space
          importing pstatus   = lv_pstatus
          tables    lt_pcx_s1 = lt_pcx_s1.
        if lv_pstatus <> 'S' or lt_pcx_s1 is initial. " Not Successful or empty
          continue.
        endif.
        " ---------- Copy and check Overwrite -----------
        if p_ow is initial.
          loop at lt_pcx_s1 assigning <ls_pcx_s1> where t_text is initial. "#EC CI_NESTED
            <ls_pcx_s1>-t_text = <ls_pcx_s1>-s_text.
          endloop.
        else.
          loop at lt_pcx_s1 assigning <ls_pcx_s1>.       "#EC CI_NESTED
            <ls_pcx_s1>-t_text = <ls_pcx_s1>-s_text.
          endloop.
        endif.
        " ---------- Update texts -----------
        call function 'LXE_OBJ_TEXT_PAIR_WRITE'
          exporting t_lang    = ls_tlanguage-o_language
                    s_lang    = ls_slanguage-o_language
                    custmnr   = ls_objs_colob-custmnr
                    objtype   = ls_objs_colob-objtype
                    objname   = ls_objs_colob-objname
          tables    lt_pcx_s1 = lt_pcx_s1.
        " ---------- Create proposal and check status -----------
        loop at lt_pcx_s1 into ls_pcx_s1 where t_text is not initial. "#EC CI_NESTED
          call function 'LXE_PP1_PROPOSAL_EDIT_SE63'
            exporting t_lang         = ls_tlanguage-o_language
                      s_lang         = ls_slanguage-o_language
                      custmnr        = ls_objs_colob-custmnr
                      objtype        = ls_objs_colob-objtype
                      domatyp        = ls_objs_colob-domatyp
                      domanam        = ls_objs_colob-domanam
                      pcx_s1         = ls_pcx_s1
                      direct_command = 'ASTX'
                      direct_status  = '69'.
        endloop.  " Proposal
        " ---------- Check and update translation status -----------
        assign gt_objects[ pgmid    = ls_object-pgmid
                           object   = ls_object-object
                           obj_name = ls_object-obj_name ] to <ls_object>.
        if sy-subrc is initial and <ls_object>-statproc <> icon_led_yellow.
          clear lv_stattrn.
          call function 'LXE_OBJ_TRANSLATION_STATUS2'
            exporting t_lang  = ls_tlanguage-o_language
                      s_lang  = ls_slanguage-o_language
                      custmnr = ls_objs_colob-custmnr
                      objtype = ls_objs_colob-objtype
                      objname = ls_objs_colob-objname
            importing stattrn = lv_stattrn.
          " ---------- Process Translation status -----------
          if lv_stattrn = 'T'.  " Translated
            <ls_object>-statproc = icon_led_green.
          else.
            <ls_object>-statproc = icon_led_yellow.
          endif.
        endif.
      endloop.  " Target language
    endloop.    " LXE Sub-Objects
  endloop.      " Objects
  message i398 with text-ex1 space space space display like 'S'. " Executed with success
endform.

" ---------------------------------------------- Form DOWNLOAD_TEMPLATE -
form download_template tables lt_objects type standard table ##PERF_NO_TYPE.
  data ls_object            like line of gt_objects.    " Objects to transport
  data ls_tlanguage         like line of gt_languages.  " Languages Informations
  data ls_slanguage         like line of gt_languages.
  data ls_tlang             like line of so_tlang.      " Target Languages
  data lt_pcx_s1            type table of lxe_pcx_s1.  " Text Pairs
  data ls_objs_colob        like line of gt_objs_colob. " LXE Objects
  data ls_pcx_s1            like line of lt_pcx_s1.
  data lv_filename          type string.                " File
  data lv_path              type string.
  data lv_fullpath          type string.
  data lv_window_title      type string.                " Popup Windows Title
  data lv_default_file_name type string.                " Default file
  data lv_user_action       type i.                     " User Actions
  data lv_object            type string.                " Excel object
  data lv_lxe_object        type string.                " LXE object
  data lv_column            type i value 1.             " Excel Columns
  data lv_row               type i value 1.             " Excel rows
  data lv_row_lang          type i.                     " Excel languages rows
  data lv_lang_txt          type string.                " Language description
  data lv_add_row           type abap_bool.             " Add new row to excel flag
  data lv_row_init          type i.                     " Language start row
  data lv_obj_text          type lxe0060lin.            " Texts for Object Attributes
  data lo_application       type ole2_object.           " OLE Automation Controller: OLE Typen
  data lo_workbook          type ole2_object.
  data lo_worksheet         type ole2_object.
  data lo_column            type ole2_object.

  " ---------- Save file dialog -----------
  lv_window_title = text-g02. " Download Template
  read table gt_languages into ls_slanguage with key laiso = p_slang.
  concatenate p_obj_n ls_slanguage-r3_lang text-f01 gv_tlangs into lv_default_file_name separated by space.
  concatenate lv_default_file_name '.' gc_excel_ext into lv_default_file_name.
  cl_gui_frontend_services=>file_save_dialog( exporting  window_title         = lv_window_title
                                                         default_extension    = gc_excel_ext
                                                         default_file_name    = lv_default_file_name
                                                         prompt_on_overwrite  = abap_false
                                              changing   filename             = lv_filename
                                                         path                 = lv_path
                                                         fullpath             = lv_fullpath
                                                         user_action          = lv_user_action
                                              exceptions cntl_error           = 1
                                                         error_no_gui         = 2
                                                         not_supported_by_gui = 3
                                                         others               = 4 ).
  if sy-subrc is not initial.
    message i398 with text-ex2 space space space display like 'E'. " Executed with errors
    return.
  endif.
  " ---------- Create excel -----------
  if lv_user_action is not initial.
    return.
  endif.

  create object lo_application 'excel.application' ##NO_TEXT.
  if sy-subrc is not initial.
    message i398 with text-ex2 space space space display like 'E'. " Executed with errors
    return.
  endif.
  set property of lo_application 'visible' = 0 ##NO_TEXT.
  " ---------- Create Workbook -----------
  call method of lo_application 'Workbooks' = lo_workbook. " Get Workbook
  set property of lo_application 'SheetsInNewWorkbook' = 1.
  call method of lo_workbook 'Add'. " Create Workbook
  " ---------- Create Worksheet -----------
  call method of lo_application 'Worksheets' = lo_worksheet " Get worksheet
    exporting #1 = 1.
  call method of lo_worksheet 'Activate'. " Activate worksheet
  set property of lo_worksheet 'Name' = text-f01 ##NO_TEXT.
  " ---------- Create Header Column Object -----------
  perform create_cell
    using    lv_row
             lv_column
             gc_object
             abap_true
    changing lo_worksheet.
  " ---------- Create Header Column LXE Object -----------
  lv_column = lv_column + 1.
  perform create_cell
    using    lv_row
             lv_column
             gc_lxe_object
             abap_true
    changing lo_worksheet.
  " ---------- Create Header Column Text Pair -----------
  lv_column = lv_column + 1.
  perform create_cell
    using    lv_row
             lv_column
             gc_textkey
             abap_true
    changing lo_worksheet.
  " ---------- Create Header Column LXE object description -----------
  lv_column = lv_column + 1.
  perform create_cell
    using    lv_row
             lv_column
             gc_desc
             abap_true
    changing lo_worksheet.
  " ---------- Create Header Column Length -----------
  lv_column = lv_column + 1.
  perform create_cell
    using    lv_row
             lv_column
             gc_length
             abap_true
    changing lo_worksheet.
  " ---------- Create Header Column Source Language column -----------
  lv_column = lv_column + 1.
  concatenate ls_slanguage-r3_lang ls_slanguage-text into lv_lang_txt separated by space.
  perform create_cell
    using    lv_row
             lv_column
             lv_lang_txt
             abap_true
    changing lo_worksheet.
  " ---------- Create Header Columns Target Languages -----------
  loop at so_tlang into ls_tlang.
    read table gt_languages into ls_tlanguage with key laiso = ls_tlang-low. " Read language tecnical info
    if sy-subrc is initial.
      lv_column = lv_column + 1.
      concatenate ls_tlanguage-r3_lang ls_tlanguage-text into lv_lang_txt separated by space.
      perform create_cell
        using    lv_row
                 lv_column
                 lv_lang_txt
                 abap_true
        changing lo_worksheet.
    endif.
  endloop.
  " ---------- Loop all selected objects -----------
  loop at lt_objects into ls_object.
    concatenate ls_object-pgmid ls_object-object ls_object-obj_name into lv_object separated by space.
    lv_add_row = abap_true. " Set add rows for new object
    lv_column = 6.          " Start text column
    lv_row_init = lv_row.  " Get init row
    " ---------- Create Column by target languague -----------
    loop at so_tlang into ls_tlang.                    "#EC CI_NESTED
      lv_column = lv_column + 1.
      clear ls_tlanguage.
      read table gt_languages into ls_tlanguage with key laiso = ls_tlang-low. " Read language tecnical info
      " ---------- Create Rows by LXE object -----------
      loop at gt_objs_colob into ls_objs_colob where     pgmid    = ls_object-pgmid "#EC CI_NESTED
                                                     and object   = ls_object-object
                                                     and obj_name = ls_object-obj_name.
        concatenate ls_objs_colob-objtype ls_objs_colob-objname into lv_lxe_object separated by space.
        " ---------- Read texts -----------
        refresh lt_pcx_s1.
        call function 'LXE_OBJ_TEXT_PAIR_READ'
          exporting t_lang    = ls_tlanguage-o_language
                    s_lang    = ls_slanguage-o_language
                    custmnr   = ls_objs_colob-custmnr
                    objtype   = ls_objs_colob-objtype
                    objname   = ls_objs_colob-objname
          tables    lt_pcx_s1 = lt_pcx_s1.
        " ---------- Read objects description -----------
        clear lv_obj_text.
        call function 'LXE_ATTOB_OBJECT_TYPE_TEXT_GET'
          ##FM_SUBRC_OK
          exporting  obj_type      = ls_objs_colob-objtype
          importing  obj_text      = lv_obj_text
          exceptions no_text_found = 1
                     others        = 2.
        " ---------- Create Rows (LXE Object) -----------
        lv_row_lang = lv_row_init.
        loop at lt_pcx_s1 into ls_pcx_s1.              "#EC CI_NESTED
          if lv_add_row is not initial.
            lv_row = lv_row + 1.
            lv_row_lang = lv_row.
            " ---------- Create Rows (Object) -----------
            perform create_cell
              using    lv_row
                       1
                       lv_object
                       abap_true
              changing lo_worksheet.
            " ---------- Create Rows (LXE Object) -----------
            perform create_cell
              using    lv_row
                       2
                       lv_lxe_object
                       abap_true
              changing lo_worksheet.
            " ---------- Create Rows (Text Pair) -----------
            perform create_cell
              using    lv_row
                       3
                       ls_pcx_s1-textkey
                       abap_true
              changing lo_worksheet.
            " ---------- Create Rows (Description) -----------
            perform create_cell
              using    lv_row
                       4
                       lv_obj_text
                       abap_true
              changing lo_worksheet.
            " ---------- Create Rows (Length) -----------
            perform create_cell
              using    lv_row
                       5
                       ls_pcx_s1-unitmlt
                       abap_true
              changing lo_worksheet.
            " ---------- Create Rows (LXE Object Source Language) -----------
            perform create_cell
              using    lv_row
                       6
                       ls_pcx_s1-s_text
                       abap_true
              changing lo_worksheet.
          else.
            lv_row_lang = lv_row_lang + 1.
          endif.
          " ---------- Create Rows (LXE Object Target languague ) -----------
          perform create_cell
            using    lv_row_lang
                     lv_column
                     ls_pcx_s1-t_text
                     abap_false
            changing lo_worksheet.
        endloop.  " Rows
      endloop.  " LXE object
      clear lv_add_row.
    endloop.  " Column
  endloop.  " Selected objects
  " ---------- Format Columns -----------
  call method of lo_application 'Columns' = lo_column. " Get Column
  call method of lo_column 'Autofit'. " Set Column Autofit
  call method of lo_application 'COLUMNS' = lo_column " Get Column 2
    exporting #1 = 2.
  set property of lo_column 'ColumnWidth' = 1.
  call method of lo_application 'COLUMNS' = lo_column " Get Column 3
    exporting #1 = 3.
  set property of lo_column 'ColumnWidth' = 1.
  " ---------- Save excel worksheet -----------
  call method of lo_worksheet 'SaveAs'                  " Save excel
    exporting #1 = lv_fullpath.
  if sy-subrc is initial.
    " ---------- Closes excel window -----------
    call method of lo_workbook 'CLOSE'. " Close Workbook
    set property of lo_application 'DisplayAlerts' = 0.
    call method of lo_application 'QUIT'. " End excel
    free object lo_column.
    free object lo_worksheet.
    free object lo_workbook.
    free object lo_application.
    message i398 with text-ex1 space space space display like 'S'. " Executed with success
  else.
    message i398 with text-ex2 space space space display like 'E'. " Executed with errors
    return.
  endif.
endform.

" ----------------------------------------------- Form UPLOAD_TEMPLATE -
form upload_template tables lt_objects type standard table ##PERF_NO_TYPE.
  data ls_object          like line of gt_objects.                   " Object to transport
  data lt_files           type table of file_table.                  " Files names
  data ls_file            like line of lt_files.
  data lt_excel_data      type table of alsmex_tabline.              " Rows for Table with Excel Data
  data ls_excel_data      like line of lt_excel_data.
  data lt_component_table type cl_abap_structdescr=>component_table. " Component Description Table
  data ls_component_table like line of lt_component_table.
  data ls_tlanguage       like line of gt_languages.                 " Languages Informations
  data ls_slanguage       like line of gt_languages.
  data ls_objs_colob      like line of gt_objs_colob.                " LXE Objects
  data lt_pcx_s1          type table of lxe_pcx_s1.                  " Text Pairs
  data ls_pcx_s1          like line of lt_pcx_s1.
  data ls_tlang           like line of so_tlang.                     " Target Languages
  data lo_data            type ref to data.                          " Generic data
  data lo_data_line       type ref to data.
  data lo_excel_table     type ref to cl_abap_tabledescr.            " Runtime Type Services
  data lo_excel_type      type ref to cl_abap_structdescr.
  data lv_title           type string.                               " Window title
  data lv_rc              type i.                                    " User action
  data lv_filename        type localfile.                            " File Name
  data lv_object          type string.                               " Object
  data lv_pstatus         type lxestatprc.                           " Process Status
  data lv_stattrn         type lxestattrn.                           " Translation Status of an Object
  data lv_lxe_object      type string.                               " LXE object
  data lv_tlang_exist     type abap_bool.                            " Target Language flag
  data lv_modify          type abap_bool.
  field-symbols <lt_excel_table> type standard table.      " Dynamic excel
  field-symbols <ls_excel_table> type any.
  field-symbols <field>          type any.                " Field pointer
  field-symbols <ls_pcx_s1>      like line of lt_pcx_s1.  " Text Pairs
  field-symbols <ls_object>      like line of gt_objects. " Objects to translate

  " ---------- Open file dialog -----------
  lv_title = text-g01.  " Upload Template
  cl_gui_frontend_services=>file_open_dialog( exporting  window_title            = lv_title
                                                         default_filename        = '*.xlsx'
                                              changing   file_table              = lt_files
                                                         rc                      = lv_rc
                                              exceptions file_open_dialog_failed = 1
                                                         cntl_error              = 2
                                                         error_no_gui            = 3
                                                         not_supported_by_gui    = 4
                                                         others                  = 5 ).
  if sy-subrc is not initial.
    message i398 with text-ex2 space space space display like 'E'. " Executed with errors
    return.
  endif.
  " ---------- Read excel -----------
  if lv_rc <> 1.
    return.
  endif.  " Read excel

  read table lt_files into ls_file index 1.
  if sy-subrc is initial.
    " ---------- Upload excel -----------
    lv_filename = ls_file-filename.
    call function 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      exporting  filename                = lv_filename
                 i_begin_col             = 1
                 i_begin_row             = 1
                 i_end_col               = 10000
                 i_end_row               = 10000
      tables     intern                  = lt_excel_data
      exceptions inconsistent_parameters = 1
                 upload_ole              = 2
                 others                  = 3.
    if sy-subrc is not initial or lt_excel_data is initial.
      message i398 with text-m02 space space space display like 'E'. " Error opening file
      return.
    endif.
    " ---------- Create dynamic table structure -----------
    loop at lt_excel_data into ls_excel_data where row = 1.
      case ls_excel_data-col.
        when 1. " Object
          if ls_excel_data-value <> gc_object.
            message i398 with text-m11 space space space display like 'E'. " File not valid
            return.
          endif.
          ls_component_table-name = gc_object.  " Object Type
          ls_component_table-type = cl_abap_elemdescr=>get_c( '48' ).
        when 2. " LXE Object
          if ls_excel_data-value <> gc_lxe_object.
            message i398 with text-m11 space space space display like 'E'. " File not valid
            return.
          endif.
          ls_component_table-name = gc_lxe_object. " LXE Object
          ls_component_table-type = cl_abap_elemdescr=>get_c( '75' ).
        when 3. " Text Pair
          if ls_excel_data-value <> gc_textkey.
            message i398 with text-m11 space space space display like 'E'. " File not valid
            return.
          endif.
          ls_component_table-name = gc_textkey.  " Text pair
          ls_component_table-type = cl_abap_elemdescr=>get_c( '32' ).
        when 4. " Description
          if ls_excel_data-value <> gc_desc.
            message i398 with text-m11 space space space display like 'E'. " File not valid
            return.
          endif.
          ls_component_table-name = gc_desc.  " Description
          ls_component_table-type = cl_abap_elemdescr=>get_c( '60' ).
        when 5. " Length
          if ls_excel_data-value <> gc_length.
            message i398 with text-m11 space space space display like 'E'. " File not valid
            return.
          endif.
          ls_component_table-name = gc_length.  " Length
          ls_component_table-type = cl_abap_elemdescr=>get_c( '10' ).
        when 6. " Source language
          read table gt_languages into ls_slanguage with key laiso = p_slang.
          if ls_excel_data-value(2) <> ls_slanguage-r3_lang.
            message i398 with text-m12 space space space display like 'E'. " File source language not valid
            return.
          endif.
          ls_component_table-name = ls_excel_data-value(2).  " Languagues
          ls_component_table-type = cl_abap_elemdescr=>get_c( '132' ).
        when others. " Target languages
          read table gt_languages into ls_tlanguage with key r3_lang = ls_excel_data-value(2).
          if sy-subrc is initial.
            lv_tlang_exist = abap_true.
          endif.
          ls_component_table-name = ls_excel_data-value(2).  " Languagues
          ls_component_table-type = cl_abap_elemdescr=>get_c( '132' ).
      endcase.
      append ls_component_table to lt_component_table.
      clear ls_component_table.
    endloop.
    if lv_tlang_exist is initial.
      message i398 with text-m13 space space space display like 'E'. " File target languages not valid
      return.
    endif.
    " ---------- Create dynamic table -----------
    if lt_component_table is not initial.
      lo_excel_type = cl_abap_structdescr=>create( lt_component_table ).
      lo_excel_table = cl_abap_tabledescr=>create( p_line_type  = lo_excel_type
                                                   p_table_kind = cl_abap_tabledescr=>tablekind_std
                                                   p_unique     = abap_false ).
      create data lo_data type handle lo_excel_table.
      assign lo_data->* to <lt_excel_table>.
      if <lt_excel_table> is assigned.
        create data lo_data_line like line of <lt_excel_table>.
        assign lo_data_line->* to <ls_excel_table>.
      endif.
    endif.
    if <lt_excel_table> is not assigned or <ls_excel_table> is not assigned.
      message i398 with text-ex2 space space space display like 'E'. " Executed with errors
      return.
    endif.
    " ---------- Fill dynamic table with excel data -----------
    loop at lt_excel_data into ls_excel_data where row > 1.
      at new row ##LOOP_AT_OK.
        append initial line to <lt_excel_table> assigning <ls_excel_table>.
      endat.
      read table lt_component_table into ls_component_table index ls_excel_data-col.
      if sy-subrc is initial.
        assign component ls_component_table-name of structure <ls_excel_table> to <field>.
        if <field> is not assigned.
          continue.
        endif.
      endif.
      <field> = ls_excel_data-value.
    endloop.
    if <lt_excel_table> is initial.
      message i398 with text-m04 space space space display like 'W'. " No objects selected
    endif.
    " ---------- Translate upload excel data -----------
    " ---------- Loop all selected objects -----------
    loop at lt_objects into ls_object.                 "#EC CI_NESTED
      concatenate ls_object-pgmid ls_object-object ls_object-obj_name into lv_object separated by space.
      assign <lt_excel_table>[ (gc_object) = lv_object ] to <ls_excel_table>.  " Check if object exist in file
      if sy-subrc is not initial. " Object not found in file
        continue.
      endif.
      " ---------- Loop LXE Sub-Objects -----------
      loop at gt_objs_colob into ls_objs_colob where     pgmid    = ls_object-pgmid "#EC CI_NESTED
                                                     and object   = ls_object-object
                                                     and obj_name = ls_object-obj_name.
        concatenate ls_objs_colob-objtype ls_objs_colob-objname into lv_lxe_object separated by space.
        assign <lt_excel_table>[ (gc_object)    = lv_object " Check if object exist in file
                                 (gc_lxe_object) = lv_lxe_object ] to <ls_excel_table>.
        if sy-subrc is not initial. " Object not found in file
          continue.
        endif.
        " ---------- Loop selected target language -----------
        loop at so_tlang into ls_tlang.
          clear ls_tlanguage.
          read table gt_languages into ls_tlanguage with key laiso = ls_tlang-low. " Read language tecnical info
          read table lt_component_table transporting no fields with key name = ls_tlanguage-r3_lang. " Check if target language exist
          if sy-subrc is not initial. " Target Language found
            continue.
          endif.
          " ---------- Read texts -----------
          clear lv_pstatus.
          refresh lt_pcx_s1.
          call function 'LXE_OBJ_TEXT_PAIR_READ'
            exporting t_lang    = ls_tlanguage-o_language
                      s_lang    = ls_slanguage-o_language
                      custmnr   = ls_objs_colob-custmnr
                      objtype   = ls_objs_colob-objtype
                      objname   = ls_objs_colob-objname
                      read_only = space
            importing pstatus   = lv_pstatus
            tables    lt_pcx_s1 = lt_pcx_s1.
          if lv_pstatus <> 'S' or lt_pcx_s1 is initial. " Not Successful or empty
            continue.
          endif.
          " ---------- Update and check Overwrite -----------
          clear lv_modify.
          loop at lt_pcx_s1 assigning <ls_pcx_s1>.     "#EC CI_NESTED
            if p_ow is initial and <ls_pcx_s1>-t_text is not initial. " Check Overwrite
              continue.
            endif.
            assign <lt_excel_table>[ (gc_object)    = lv_object
                                     (gc_lxe_object) = lv_lxe_object
                                     (gc_textkey)    = <ls_pcx_s1>-textkey ] to <ls_excel_table>.
            if sy-subrc is initial.
              assign component ls_tlanguage-r3_lang of structure <ls_excel_table> to <field>.
              if sy-subrc is initial.
                if <field> is not initial.
                  <ls_pcx_s1>-t_text = <field>.
                  lv_modify = abap_true.
                endif.
              endif.
            endif.
          endloop.
          " ---------- Update texts -----------
          if lv_modify is not initial.
            call function 'LXE_OBJ_TEXT_PAIR_WRITE'
              exporting t_lang    = ls_tlanguage-o_language
                        s_lang    = ls_slanguage-o_language
                        custmnr   = ls_objs_colob-custmnr
                        objtype   = ls_objs_colob-objtype
                        objname   = ls_objs_colob-objname
              tables    lt_pcx_s1 = lt_pcx_s1.
            " ---------- Create proposal and check status -----------
            loop at lt_pcx_s1 into ls_pcx_s1 where t_text is not initial. "#EC CI_NESTED
              call function 'LXE_PP1_PROPOSAL_EDIT_SE63'
                exporting t_lang         = ls_tlanguage-o_language
                          s_lang         = ls_slanguage-o_language
                          custmnr        = ls_objs_colob-custmnr
                          objtype        = ls_objs_colob-objtype
                          domatyp        = ls_objs_colob-domatyp
                          domanam        = ls_objs_colob-domanam
                          pcx_s1         = ls_pcx_s1
                          direct_command = 'ASTX'
                          direct_status  = '69'.
            endloop.  " Proposal
          endif.
          " ---------- Check and update log translation status -----------
          assign gt_objects[ pgmid    = ls_object-pgmid
                             object   = ls_object-object
                             obj_name = ls_object-obj_name ] to <ls_object>.
          if sy-subrc is initial.
            clear lv_stattrn.
            call function 'LXE_OBJ_TRANSLATION_STATUS2'
              exporting t_lang  = ls_tlanguage-o_language
                        s_lang  = ls_slanguage-o_language
                        custmnr = ls_objs_colob-custmnr
                        objtype = ls_objs_colob-objtype
                        objname = ls_objs_colob-objname
              importing stattrn = lv_stattrn.
            " ---------- Process Translation status -----------
            if lv_stattrn = 'T'.  " Translated
              if <ls_object>-statproc <> icon_led_yellow.
                <ls_object>-statproc = icon_led_green.
              endif.
            else.
              <ls_object>-statproc = icon_led_yellow.
            endif.
          endif.
        endloop.  " Target Languagens
      endloop.  " LXE Sub-Objects
    endloop.  " Objects
    message i398 with text-ex1 space space space display like 'S'.  " Executed with success
  endif.  " Open excel
endform.

" --------------------------------------------------- Form CREATE_CELL -
form create_cell
  using    p_row_num  type i
           p_cell_num type i
           p_value    type any
           p_bold     type abap_bool
  changing c_sheet    type ole2_object.

  data lo_cell type ole2_object.
  data e_bold  type ole2_object.

  " ---------- Create Excel cell -----------
  call method of c_sheet 'Cells' = lo_cell  " Get Cell
    exporting #1 = p_row_num
              #2 = p_cell_num.
  set property of lo_cell 'Value' = p_value ##NO_TEXT.
  if p_bold is not initial.
    get property of lo_cell 'Font' = e_bold ##NO_TEXT.
    set property of e_bold 'Bold' = 1 ##NO_TEXT.
  endif.
endform.
*---------------------------------- CLASS HANDLE EVENTS IMPLEMENTATION *
class lcl_handle_events implementation.
  " -------------------------------------------------------- User command -
  method on_user_command.
    constants lc_copy type string value 'COPY'. " Copy original to targets
    constants lc_down type string value 'DOWN'. " Download Template
    constants lc_up   type string value 'UP'.   " Upload Template
    constants lc_tr   type string value 'TR'.   " Transport request

    check    e_salv_function = lc_copy or e_salv_function = lc_down
          or e_salv_function = lc_up   or e_salv_function = lc_tr.
    data lr_selections type ref to cl_salv_selections. " ALV Selections
    data lt_rows       type salv_t_row.                " ALV Rows
    data ls_row        type i.
    data lt_objects    type table of gty_objects.  " Objects to translate
    data lv_answer     type c length 1.
    field-symbols <ls_object> like line of gt_objects. " Objects to translate
    try.
        " ---------- Get selected lines -----------
        lr_selections = go_objects->get_selections( ).
        lt_rows = lr_selections->get_selected_rows( ).
        " ---------- Get selected objects -----------
        loop at lt_rows into ls_row.
          assign gt_objects[ ls_row ] to <ls_object>.
          if sy-subrc is initial and <ls_object>-status = icon_led_green. " Object valid if status OK
            clear <ls_object>-statproc.                                  " Clear translation status for reprocessing
            append <ls_object> to lt_objects.                            " Add selected object for processing
          endif.
        endloop.
        if lt_objects is not initial. " Objects selected
          " ---------- Confirmation for copy or update -----------
          if e_salv_function = lc_copy or e_salv_function = lc_up.
            call function 'POPUP_TO_CONFIRM'
              ##FM_SUBRC_OK " "#EC CI_SUBRC
              exporting  titlebar       = text-f01
                         text_question  = text-f02
              importing  answer         = lv_answer
              exceptions text_not_found = 1
                         others         = 2.
            if lv_answer <> '1'.
              return.
            endif.
          endif.
          " ---------- Execution -----------
          case e_salv_function.
            " ---------- Copy original to targets -----------
            when lc_copy.
              perform copy_translations tables lt_objects.
              " ---------- Download Template -----------
            when lc_down.
              perform download_template tables lt_objects.
              " ---------- Upload Template -----------
            when lc_up.
              perform upload_template tables lt_objects.
              " ---------- Transport request -----------
            when lc_tr.
              perform create_transport tables lt_objects.
          endcase.
          " ---------- ALV Refresh for copy or update -----------
          if e_salv_function = lc_copy or e_salv_function = lc_up.
            go_objects->refresh( ).
          endif.
        else.
          message i398 with text-m04 space space space. " No objects selected
        endif.
      catch cx_root into go_exp ##CATCH_ALL.
        message go_exp type 'I' display like 'E'.
*        gv_msg_text = go_exp->get_text( ).
*        message s398 with gv_msg_text space space space display like 'E'. "Critical error
    endtry.
  endmethod.

  " -------------------------------------------------------- Line dbclick -
  method on_double_click.
    data lt_spopli   type table of spopli.      " Language infos
    data ls_spopli   like line of lt_spopli.
    data ls_language like line of gt_languages.
    data ls_e071     type e071.                 " Change & Transport System: Object Entries of Requests/Tasks
    data ls_object   like line of gt_objects.   " Objects to transport
    data lv_answer   type c length 1.           " User Answer
    data lv_tlang    type spras.                " Target Translation Language

    " ---------- Get selected line -----------
    read table gt_objects into ls_object index row.
    if not ( sy-subrc is initial and ls_object-status = icon_led_green ).
      return.
    endif.

    try.
        if lines( so_tlang ) = 1. " Only one target language
          loop at gt_languages into ls_language where laiso <> p_slang.
            lv_tlang = ls_language-laiso.
            exit.
          endloop.
        else. " More that one target language
          " ---------- Fill popup radio buttons -----------
          loop at gt_languages into ls_language where laiso <> p_slang.
            concatenate ls_language-r3_lang ls_language-text into ls_spopli-varoption
                        separated by space.
            append ls_spopli to lt_spopli.
          endloop.
          " ---------- Please select target language to Edit -----------
          call function 'POPUP_TO_DECIDE_LIST'
            exporting  textline1          = text-d01
                       titel              = text-d02
            importing  answer             = lv_answer
            tables     t_spopli           = lt_spopli
            exceptions not_enough_answers = 1
                       too_much_answers   = 2
                       too_much_marks     = 3
                       others             = 4.
          if sy-subrc is initial and lv_answer <> 'A'.  " Selected
            read table lt_spopli into ls_spopli with key selflag = abap_true.                  " Get selected radio button
            read table gt_languages into ls_language with key r3_lang = ls_spopli-varoption(2). " Get selected language
            lv_tlang = ls_language-laiso.
          endif.
        endif.
        " ---------- Edit Target Translation Language -----------
        if lv_tlang is not initial.
          move-corresponding ls_object to ls_e071.
          call function 'LXE_OBJ_CALL_WL_SE63'
            exporting s_lang  = p_slang
                      t_lang  = lv_tlang
                      do_eval = abap_true
                      e071    = ls_e071.
        endif.
      catch cx_root into go_exp ##CATCH_ALL.
        message go_exp type 'I' display like 'E'.
*          gv_msg_text = go_exp->get_text( ).
*          message s398 with gv_msg_text space space space display like 'E'. "Critical error
    endtry.
  endmethod.
endclass.
