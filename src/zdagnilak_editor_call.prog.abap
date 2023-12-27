*&---------------------------------------------------------------------*
*& Report  ZDAGNILAK_EDITOR_CALL
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*
report zdagnilak_editor_call.

parameters: program  radiobutton group prg,
            progname type trdir-name.
selection-screen skip.
parameters: function radiobutton group prg,
            funcname type tfdir-funcname.
selection-screen skip.
parameters: method   radiobutton group prg,
            class    type seoclskey-clsname,
            methname type seocpdkey-cpdname.

data: gt_lines    type table of string,
      gt_includes type seop_methods_w_include with header line,
      gs_clskey   type seoclskey,
      gv_subrc    type sy-subrc,
      gv_suffix   type c length 2.

initialization.
  data: lv_role type t000-cccategory.

  call function 'TR_SYS_PARAMS'
    importing
      system_client_role = lv_role.
  if lv_role = 'P'.
    message 'Canlıda çalıştıramazsınız!' type 'E'.
  endif.

start-of-selection.

  case 'X'.
    when function.
      call function 'FUNCTION_EXISTS'
        exporting
          funcname           = funcname
        importing
          include            = progname
        exceptions
          function_not_exist = 1
          others             = 2.
      if sy-subrc <> 0.
        message 'Fonksiyon mevcut değil' type 'S'.
        return.
      endif.

    when method.
      gs_clskey-clsname = class.

      call function 'SEO_CLASS_GET_METHOD_INCLUDES'
        exporting
          clskey                       = gs_clskey
        importing
          includes                     = gt_includes[]
        exceptions
          _internal_class_not_existing = 1
          others                       = 2.
      if sy-subrc <> 0.
        message 'Class mevcut değil' type 'S'.
        return.
      endif.

      read table gt_includes with key cpdkey-cpdname = methname.
      if sy-subrc <> 0.
        message 'Method mevcut değil' type 'S'.
        return.
      endif.

      progname = gt_includes-incname.

  endcase.

  read report progname into gt_lines.
  if sy-subrc ne 0.
    message 'Program mevcut değil' type 'S'.
    return.
  endif.

*  editor-call for gt_lines title progname.

  call function 'EDITOR_TABLE'
    importing
      subrc   = gv_subrc
    tables
      content = gt_lines.

  if gv_subrc = 0.

    if strlen( progname ) > 30. "special includes
      if progname+30(1) = 'E' "enhancement include
        or progname+30(1) = 'B' "????
        or progname+30(1) = 'D'. "definition include
        gv_suffix = progname+30(1).
      else.
        gv_suffix = progname+30(2).
      endif.

      insert report progname from gt_lines
        extension type gv_suffix
        state 'A'.
    else.
      insert report progname from gt_lines state 'A'.
    endif.

    if sy-subrc eq 0.
      message 'Değişiklikler kaydedildi' type 'S'.
    else.
      message 'Hata çıktı!' type 'S'.
    endif.

  endif.
