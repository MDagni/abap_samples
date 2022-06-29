************************************************************************
* Developer        : Mehmet Dağnilak
* Description      :
*   Bir sistemdeki ALV layout'larının diğer bir sisteme taşınması
*   işlemini yapar. Canlıdan Dev/Test sistemlerine taşınma yapılabilir.
************************************************************************
* History
*----------------------------------------------------------------------*
* User-ID     Date      Description
*----------------------------------------------------------------------*
* MDAGNILAK   20160524  Program created
* <userid>    yyyymmdd  <short description of the change>
************************************************************************

report zdagnilak_alv_layout_download line-size 255.

tables: ltdx.

parameters: p_downl radiobutton group op.
select-options: s_report for ltdx-report,
                s_handle for ltdx-handle,
                s_varian for ltdx-variant,
                s_user   for ltdx-username default space.
selection-screen skip.
parameters: p_upload radiobutton group op.

types: begin of ty_contents,
         s_ltvariant  type ltvariant,
         i_dbfieldcat type standard table of ltdxdata with default key,
         i_dbsortinfo type standard table of ltdxdata with default key,
         i_dbfilter   type standard table of ltdxdata with default key,
         i_dblayout   type standard table of ltdxdata with default key,
       end of ty_contents.

start-of-selection .

  if p_downl eq abap_true.
    perform download.
  else.
    perform upload.
  endif.

*&---------------------------------------------------------------------*
*&      Form  DOWNLOAD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form download.

  data: lt_variants  type table of ltvariant,
        lt_contents  type standard table of ty_contents,
        lt_binary    type table of char255,
        ls_varkey    type ltdxkey,
        lv_xcontents type xstring,
        lv_size      type i,
        lv_filename  type string,
        lv_path      type string,
        lv_fullpath  type string.

  field-symbols: <ls_variant>  type ltvariant,
                 <ls_contents> type ty_contents.

  if s_report[] is initial.
    message 'Program adını giriniz.' type 'S'.
    return.
  endif.

**********************************************************************
  call function 'LT_VARIANTS_READ_FROM_LTDX'
    tables
      et_variants    = lt_variants
      it_ra_report   = s_report
      it_ra_handle   = s_handle
      it_ra_variant  = s_varian
      it_ra_username = s_user
    exceptions
      not_found      = 1
      others         = 2.

  if sy-subrc <> 0.
    message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            display like sy-msgty.
    return.
  endif.

  loop at lt_variants assigning <ls_variant>.

    append initial line to lt_contents assigning <ls_contents>.
    <ls_contents>-s_ltvariant = <ls_variant>.

    write:/ <ls_contents>-s_ltvariant-report,
            <ls_contents>-s_ltvariant-handle,
            <ls_contents>-s_ltvariant-variant,
            <ls_contents>-s_ltvariant-text,
            <ls_contents>-s_ltvariant-defaultvar.

    move-corresponding <ls_variant> to ls_varkey.

    call function 'LT_DBDATA_READ_FROM_LTDX'
      exporting
        is_varkey    = ls_varkey
      tables
        t_dbfieldcat = <ls_contents>-i_dbfieldcat
        t_dbsortinfo = <ls_contents>-i_dbsortinfo
        t_dbfilter   = <ls_contents>-i_dbfilter
        t_dblayout   = <ls_contents>-i_dblayout
      exceptions
        not_found    = 1
        wrong_relid  = 2
        others       = 3.

    if sy-subrc <> 0.
      message id sy-msgid type sy-msgty number sy-msgno
              with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
              display like sy-msgty.
      return.
    endif.

  endloop.

**********************************************************************
  export lt_contents to data buffer lv_xcontents compression on.

  call function 'SCMS_XSTRING_TO_BINARY'
    exporting
      buffer        = lv_xcontents
    importing
      output_length = lv_size
    tables
      binary_tab    = lt_binary.

  call method cl_gui_frontend_services=>file_save_dialog
    exporting
      default_extension = '.layout'
      default_file_name = s_report-low && `.layout`
      file_filter       = `ALV layouts|*.layout|`
    changing
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
    exceptions
      others            = 5.

  if sy-subrc <> 0.
    message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            display like sy-msgty.
    return.
  endif.

  check lv_fullpath is not initial.

  call method cl_gui_frontend_services=>gui_download
    exporting
      bin_filesize = lv_size
      filename     = lv_fullpath
      filetype     = 'BIN'
    changing
      data_tab     = lt_binary
    exceptions
      others       = 24.

  if sy-subrc <> 0.
    message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            display like sy-msgty.
    return.
  endif.

  write:/ 'Dosya indirildi:', lv_fullpath.

endform.          " DOWNLOAD


*&---------------------------------------------------------------------*
*&      Form  UPLOAD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form upload.

  data: lt_contents   type standard table of ty_contents,
        lt_binary     type table of char255,
        ls_varkey     type ltdxkey,
        ls_disvariant type disvariant,
        lv_xcontents  type xstring,
        lv_size       type i,
        lt_files      type filetable,
        lv_rc         type i,
        ls_ltdxd      type ltdxd,
        lv_role       type t000-cccategory,
        lv_answer     type char1,
        ls_ltdxt      type ltdxt.

  field-symbols: <ls_files>    type file_table,
                 <ls_contents> type ty_contents.

**********************************************************************
* Canlı sistem kontrolü
  call function 'TR_SYS_PARAMS'
    importing
      system_client_role = lv_role.

  if lv_role = 'P'.
    call function 'POPUP_TO_CONFIRM'
      exporting
        text_question  = 'Canlı sisteme yükleme yapmak istediğinize emin misiniz?'
        default_button = '2'
      importing
        answer         = lv_answer.
    check lv_answer = 1.
  endif.

**********************************************************************
  call method cl_gui_frontend_services=>file_open_dialog
    exporting
      default_extension = '.layout'
      file_filter       = `ALV layouts|*.layout|`
      multiselection    = abap_true
    changing
      file_table        = lt_files
      rc                = lv_rc
    exceptions
      others            = 5.

  if sy-subrc <> 0.
    message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            display like sy-msgty.
    return.
  endif.

  check lt_files is not initial.

  loop at lt_files assigning <ls_files>.

    write:/ 'Dosya yükleniyor:', (*) <ls_files>-filename.

    call method cl_gui_frontend_services=>gui_upload
      exporting
        filename   = conv #( <ls_files>-filename )
        filetype   = 'BIN'
      importing
        filelength = lv_size
      changing
        data_tab   = lt_binary
      exceptions
        others     = 19.

    if sy-subrc <> 0.
      message id sy-msgid type sy-msgty number sy-msgno
              with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
              display like sy-msgty.
      return.
    endif.

    call function 'SCMS_BINARY_TO_XSTRING'
      exporting
        input_length = lv_size
      importing
        buffer       = lv_xcontents
      tables
        binary_tab   = lt_binary
      exceptions
        failed       = 1
        others       = 2.

    if sy-subrc <> 0.
      message id sy-msgid type sy-msgty number sy-msgno
              with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
              display like sy-msgty.
      return.
    endif.

    try.
        import lt_contents from data buffer lv_xcontents.
      catch cx_root into data(lx_root).
        write:/ lx_root->get_text( ).
        return.
    endtry.

**********************************************************************
    loop at lt_contents assigning <ls_contents>.

      write:/ <ls_contents>-s_ltvariant-report,
              <ls_contents>-s_ltvariant-handle,
              <ls_contents>-s_ltvariant-variant,
              <ls_contents>-s_ltvariant-text,
              <ls_contents>-s_ltvariant-defaultvar.

      move-corresponding <ls_contents>-s_ltvariant to ls_varkey.
      move-corresponding <ls_contents>-s_ltvariant to ls_disvariant.

      call function 'LT_DBDATA_WRITE_TO_LTDX'
        exporting
          is_varkey    = ls_varkey
          is_variant   = ls_disvariant
        tables
          t_dbfieldcat = <ls_contents>-i_dbfieldcat
          t_dbsortinfo = <ls_contents>-i_dbsortinfo
          t_dbfilter   = <ls_contents>-i_dbfilter
          t_dblayout   = <ls_contents>-i_dblayout
        exceptions
          not_found    = 1
          wrong_relid  = 2
          others       = 3.

      if sy-subrc <> 0.
        message id sy-msgid type sy-msgty number sy-msgno
                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
                display like sy-msgty.
        return.
      endif.

      move-corresponding <ls_contents>-s_ltvariant to ls_ltdxt.
      ls_ltdxt-langu = sy-langu.
      modify ltdxt from ls_ltdxt.

*     Default variant
      if <ls_contents>-s_ltvariant-defaultvar is not initial.

        move-corresponding <ls_contents>-s_ltvariant to ls_ltdxd.

        call function 'LT_DB_UPDATE_LTDXD'
          exporting
            is_ltdxd     = ls_ltdxd
            i_updatekz   = 'I'
          exceptions
            update_error = 1
            wrong_relid  = 2
            others       = 3.
        if sy-subrc <> 0.
          message id sy-msgid type sy-msgty number sy-msgno
                  with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
                  display like sy-msgty.
          return.
        endif.

      endif.

    endloop.

  endloop.

  commit work.

endform.          " UPLOAD
