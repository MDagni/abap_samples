*&---------------------------------------------------------------------*
*& Report  ZBC_VIEWMAINTENANCE
*& Create by Mehmet Dagnilak, 21.07.2006
*&---------------------------------------------------------------------*
*& Calls View Maintenance screen for given table/view, with a
*& selection-screen for the given fields and obligatory fields
*& (maintenance attribute S in view definition).
*&
*& You can create a transaction called ZSM30 for this report to use it
*& in other parameter transactions.
*&---------------------------------------------------------------------*

report zbc_viewmaintenance.

*&---------------------------------------------------------------------*
*& Data
*&---------------------------------------------------------------------*
tables: dd27s, dd03l.
data: sellist type vimsellist occurs 0 with header line,
      pfield01(30),
      pfield02(30),
      pfield03(30),
      pfield04(30),
      pfield05(30),
      parfield01(30),
      parfield02(30),
      parfield03(30),
      parfield04(30),
      parfield05(30),
      selfield01(30),
      selfield02(30),
      selfield03(30),
      selfield04(30),
      selfield05(30),
      pmemor01 like dd04l-memoryid,
      pmemor02 like dd04l-memoryid,
      pmemor03 like dd04l-memoryid,
      pmemor04 like dd04l-memoryid,
      pmemor05 like dd04l-memoryid,
      typec(45) type c.
ranges: r_typec for typec.
field-symbols: <value> type any.

*&---------------------------------------------------------------------*
*& Selection-screen 1000: Main
*&---------------------------------------------------------------------*
selection-screen begin of block bl0.
parameters: viewname like dd03l-tabname obligatory value check,
            field01  like dd03l-fieldname,
            field02  like dd03l-fieldname,
            field03  like dd03l-fieldname,
            field04  like dd03l-fieldname,
            field05  like dd03l-fieldname,
            memor01  like dd04l-memoryid,
            memor02  like dd04l-memoryid,
            memor03  like dd04l-memoryid,
            memor04  like dd04l-memoryid,
            memor05  like dd04l-memoryid,
            text01   type text79_d,
            text02   type text79_d,
            text03   type text79_d,
            text04   type text79_d,
            text05   type text79_d,
            action type c default 'U'.
selection-screen end of block bl0.

*&---------------------------------------------------------------------*
*& Selection-screen 5000: Dynamically created
*&---------------------------------------------------------------------*
selection-screen begin of screen 5000 title tabtitle.
selection-screen begin of block bl1 with frame.
parameters: p_par01 like (parfield01) modif id p01,
            p_par02 like (parfield02) modif id p02,
            p_par03 like (parfield03) modif id p03,
            p_par04 like (parfield04) modif id p04,
            p_par05 like (parfield05) modif id p05.
select-options: s_sel01 for (selfield01) modif id s01,
                s_sel02 for (selfield02) modif id s02,
                s_sel03 for (selfield03) modif id s03,
                s_sel04 for (selfield04) modif id s04,
                s_sel05 for (selfield05) modif id s05.
selection-screen skip.
selection-screen comment /1(79) p_text01 modif id t01.
selection-screen comment /1(79) p_text02 modif id t02.
selection-screen comment /1(79) p_text03 modif id t03.
selection-screen comment /1(79) p_text04 modif id t04.
selection-screen comment /1(79) p_text05 modif id t05.
selection-screen end of block bl1.
selection-screen end of screen 5000.

*&---------------------------------------------------------------------*
*& Macros
*&---------------------------------------------------------------------*
define set_selfield.
  if field&1 is not initial.
    concatenate viewname '-' field&1 into selfield&1.
    get parameter id memor&1 field s_sel&1-low.
    if s_sel&1-low is not initial.
      s_sel&1-sign = 'I'.
      s_sel&1-option = 'EQ'.
      append s_sel&1.
    endif.
  endif.
end-of-definition.

define set_parfield.
  pfield&1 = dd27s-viewfield.
  concatenate viewname '-' pfield&1 into parfield&1.
  select single memoryid from dd04l into pmemor&1
         where rollname eq dd27s-rollname
           and as4local eq 'A'
           and as4vers eq '0000'.
  get parameter id pmemor&1 field p_par&1.
end-of-definition.

define disable_screen.
  if &1 is initial.
    screen-active = 0.
    modify screen.
  endif.
end-of-definition.

define add_sellist.
  if selfield&1 is not initial.
    if memor&1 is not initial.
      set parameter id memor&1 field s_sel&1-low.
    endif.
    call function 'VIEW_RANGETAB_TO_SELLIST'
      exporting
        fieldname          = field&1
        append_conjunction = 'AND'
      tables
        sellist            = sellist
        rangetab           = s_sel&1.
  endif.
end-of-definition.

define add_parlist.
  if parfield&1 is not initial.
    if pmemor&1 is not initial.
      set parameter id pmemor&1 field p_par&1.
    endif.
    refresh r_typec.
    r_typec = 'IEQ'.
    r_typec-low = p_par&1.
    append r_typec.
    call function 'VIEW_RANGETAB_TO_SELLIST'
      exporting
        fieldname          = pfield&1
        append_conjunction = 'AND'
      tables
        sellist            = sellist
        rangetab           = r_typec.
  endif.
end-of-definition.

*&---------------------------------------------------------------------*
*& at selection-screen
*&---------------------------------------------------------------------*
at selection-screen output.
  check sy-dynnr eq '5000'.
  loop at screen.
    case screen-group1.
      when 'P01'. disable_screen parfield01.
      when 'P02'. disable_screen parfield02.
      when 'P03'. disable_screen parfield03.
      when 'P04'. disable_screen parfield04.
      when 'P05'. disable_screen parfield05.
      when 'S01'. disable_screen selfield01.
      when 'S02'. disable_screen selfield02.
      when 'S03'. disable_screen selfield03.
      when 'S04'. disable_screen selfield04.
      when 'S05'. disable_screen selfield05.
      when 'T01'. disable_screen text01.
      when 'T02'. disable_screen text02.
      when 'T03'. disable_screen text03.
      when 'T04'. disable_screen text04.
      when 'T05'. disable_screen text05.
    endcase.
    if screen-group1(2) eq 'T0'.
      screen-intensified = 1.
      modify screen.
    endif.
  endloop.

*&---------------------------------------------------------------------*
*& start-of-selection
*&---------------------------------------------------------------------*
start-of-selection.

  select single ddtext from dd25t into tabtitle
         where ddlanguage eq sy-langu
           and viewname eq viewname
           and as4local eq 'A'
           and as4vers eq ''.

  case action.
    when 'U'. concatenate 'Maintain "' tabtitle '"' into tabtitle.
    when 'S'. concatenate 'Display "' tabtitle '"' into tabtitle.
    when others.
      message 'Action can be U or S' type 'I'.
      exit.
  endcase.

  select * from dd27s
         where viewname eq viewname
           and as4local eq 'A'
           and keyflag eq 'X'
           and rdonly eq 'S'
         order by objpos.
    case space.
      when parfield01. set_parfield 01.
      when parfield02. set_parfield 02.
      when parfield03. set_parfield 03.
      when parfield04. set_parfield 04.
      when parfield05. set_parfield 05.
    endcase.
  endselect.

  set_selfield: 01, 02, 03, 04, 05.
  p_text01 = text01.
  p_text02 = text02.
  p_text03 = text03.
  p_text04 = text04.
  p_text05 = text05.

  do.
    call selection-screen 5000.
    if sy-subrc ne 0.
      exit.
    endif.

    refresh sellist.
    add_parlist: 01, 02, 03, 04, 05.
    add_sellist: 01, 02, 03, 04, 05.

*   Values based on field type
    loop at sellist.
      select single * from dd03l
             where tabname eq viewname
               and fieldname eq sellist-viewfield
               and as4local eq 'A'.
      case dd03l-inttype.
        when 'N'.
          sellist-numc_value(dd03l-intlen) = sellist-value.
        when 'D'.
          sellist-date_value = sellist-value.
        when 'T'.
          sellist-time_value = sellist-value.
        when 'P'.
          assign sellist-raw_value(dd03l-intlen) to <value>
                 type dd03l-inttype decimals dd03l-decimals.
          <value> = sellist-value.
        when others.
          sellist-raw_value = sellist-value.
          sellist-invd_value = sellist-value.
      endcase.
      sellist-converted = 'X'.
      modify sellist.
    endloop.

    call function 'VIEW_MAINTENANCE_CALL'
      exporting
        action      = action
        view_name   = viewname
      tables
        dba_sellist = sellist
      exceptions
        others      = 15.

    if sy-subrc <> 0.
      message id sy-msgid type sy-msgty number sy-msgno
              with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endif.
  enddo.
