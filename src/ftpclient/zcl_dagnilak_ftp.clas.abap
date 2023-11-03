class zcl_dagnilak_ftp definition
  public final
  create public.

  public section.

    types ty_contents_tab type standard table of ixbcmime.

    data mv_ftphandle type i read-only.
    data mv_host      type ftp_cname.
    data mv_password  type ftp_passwd.
    data mv_path      type catfilnam.
    data mv_rfcdest   type rfcdest.
    data mv_username  type ftp_user.

    methods change_dir
      importing
        dir type clike
      raising
        cx_bapi_error.

    methods connect
      raising
        cx_bapi_error.

    methods constructor
      importing
        host     type clike
        username type clike
        password type clike
        !path    type clike   optional
        rfcdest  type rfcdest default 'SAPFTPA'.

    methods delete_file
      importing
        filename type clike
      raising
        cx_bapi_error.

    methods disconnect.

    methods ftp_command
      importing
        !command type char255
      exporting
        ftplines type tttext255
      raising
        cx_bapi_error.

    methods get_binary_file
      importing
        filename     type clike
        percent      type i optional
      exporting
        filesize     type i
        contents     type xstring
        contents_tab type ty_contents_tab
      raising
        cx_bapi_error.

    methods get_file_list
      returning
        value(files) type tttext255
      raising
        cx_bapi_error.

    methods get_text_file
      importing
        filename     type clike
        percent      type i optional
      exporting
        contents_tab type standard table
      raising
        cx_bapi_error.

    methods open_in_explorer
      importing
        programname type clike optional.

    methods send_binary_file
      importing
        filename     type clike
        contents_tab type ty_contents_tab
        filesize     type i
        percent      type i optional
      raising
        cx_bapi_error.

    methods send_text_file
      importing
        filename     type clike
        contents_tab type standard table
        percent      type i optional
      raising
        cx_bapi_error.

  protected section.
    data mv_msg type string.

    methods chartab_to_stringtab
      importing
        chartab_ref type ref to data
      changing
        text_tab    type standard table.

    methods get_table_line_type
      importing
        p_data          type any table
      returning
        value(rv_value) type abap_typekind.

    methods progress
      importing
        msg     type clike
        percent type i optional.

    methods raise_error
      raising
        cx_bapi_error.

    methods stringtab_to_chartab
      importing
        text_tab           type standard table
      returning
        value(chartab_ref) type ref to data.

endclass.


class zcl_dagnilak_ftp implementation.

  method change_dir.

    try.
        ftp_command( exporting command  = |cd { dir }|
                     importing ftplines = data(lt_ftplines) ).

      catch cx_bapi_error.

        "If it's a command error, details will be in table
        if sy-msgid = '04' and '207/209' cs sy-msgno.
          read table lt_ftplines into data(lv_line) index 2.
          if sy-subrc = 0.
            message e001 with lv_line(50) lv_line+50(50) lv_line+100(50) lv_line+150(50) into mv_msg.
            raise_error( ).
          endif.
        endif.

        "Otherwise
        raise_error( ).
    endtry.

  endmethod.


  method chartab_to_stringtab.

    field-symbols <f_itab> type standard table.

    if chartab_ref is not initial and
       chartab_ref is bound.
      assign chartab_ref->* to <f_itab>.
    endif.
    if <f_itab> is not assigned.
      return.
    endif.

    append lines of <f_itab> to text_tab.

  endmethod.


  method connect.

    constants scramble_key type i value 26101957.
    data: lv_password type text40,
          lv_len      type i.

    progress( |{ text-001 } { mv_host }| ).

    lv_len = strlen( mv_password ).

    call function 'HTTP_SCRAMBLE'
      exporting
        source      = mv_password
        sourcelen   = lv_len
        key         = scramble_key
      importing
        destination = lv_password.

    call function 'FTP_CONNECT'
      exporting
        user            = mv_username
        password        = lv_password
        host            = mv_host
        rfc_destination = mv_rfcdest
      importing
        handle          = mv_ftphandle
      exceptions
        not_connected   = 1
        others          = 2.

    if sy-subrc <> 0.
      raise_error( ).
    endif.

    "Change Directory
    if mv_path is not initial.
      change_dir( mv_path ).
    endif.

  endmethod.


  method constructor.

    mv_host     = host.
    mv_username = username.
    mv_password = password.
    mv_path     = path.
    mv_rfcdest  = rfcdest.

  endmethod.


  method delete_file.

    "Delete file
    progress( |{ text-006 } { filename }| ).

    try.
        ftp_command( exporting command  = |delete { filename }|
                     importing ftplines = data(lt_ftplines) ).

      catch cx_bapi_error.

        "If it's a command error, details will be in table
        if sy-msgid = '04' and '207/209' cs sy-msgno.
          read table lt_ftplines into data(lv_line) index 2.
          if sy-subrc = 0.
            message e005 with lv_line(50) lv_line+50(50) lv_line+100(50) lv_line+150(50) into mv_msg.
            raise_error( ).
          endif.
        endif.

        "Otherwise
        raise_error( ).
    endtry.

  endmethod.


  method disconnect.

    "Error message is retained on return of this method.
    data symsg type symsg.

    move-corresponding syst to symsg.

    progress( text-005 ).

    if mv_ftphandle is not initial.
      call function 'FTP_DISCONNECT'
        exporting
          handle = mv_ftphandle.

      clear mv_ftphandle.
    endif.

    call function 'RFC_CONNECTION_CLOSE'
      exporting
        destination          = mv_rfcdest
      exceptions
        destination_not_open = 1
        others               = 2.

    move-corresponding symsg to syst.

  endmethod.


  method ftp_command.

    refresh ftplines.

    clear sy-msgid.

    call function 'FTP_COMMAND'
      exporting
        handle        = mv_ftphandle
        command       = command
      tables
        data          = ftplines
      exceptions
        tcpip_error   = 1
        command_error = 2
        data_error    = 3
        others        = 4.

    if sy-subrc <> 0.
      if sy-msgid is initial.
        message e002 into mv_msg.
      endif.
      raise_error( ).
    endif.

  endmethod.


  method get_binary_file.

    refresh contents_tab.

    "Binary mode
    ftp_command( |bin| ).

    "Get file
    progress( msg     = |{ text-004 } { filename }|
              percent = percent ).

    clear sy-msgid.

    call function 'FTP_SERVER_TO_R3'
      exporting
        handle         = mv_ftphandle
        fname          = conv localfile( filename )
        character_mode = abap_false
      importing
        blob_length    = filesize
      tables
        blob           = contents_tab
      exceptions
        tcpip_error    = 1
        command_error  = 2
        data_error     = 3
        others         = 4.

    if sy-subrc <> 0.
      if sy-msgid is initial or
         ( sy-msgid = '04' and sy-msgno = '209' ).
        message e003 into mv_msg.
      endif.
      raise_error( ).
    endif.

    if contents is requested.
      try.
          contents = cl_bcs_convert=>xtab_to_xstring( contents_tab ).
          contents = contents(filesize).
        catch cx_bcs into data(lv_msg). " TODO: variable is assigned but never used (ABAP cleaner)
          "ignore?
      endtry.
    endif.

  endmethod.


  method get_file_list.

    refresh files.

    "Change to Ascii mode
    ftp_command( |ascii| ).

    "Get file list
    try.
        ftp_command( exporting command  = `nlist`
                     importing ftplines = data(lt_ftplines) ).

      catch cx_bapi_error.

        "If it's a command error, details will be in table
        if sy-msgid = '04' and '207/209' cs sy-msgno.
          "If no files found, just exit
          read table lt_ftplines into data(lv_line) index 3.
          if lv_line(4) = '550 '.
            exit.
          endif.
          read table lt_ftplines into lv_line index 2.
          if sy-subrc = 0.
            message e001 with lv_line(50) lv_line+50(50) lv_line+100(50) lv_line+150(50) into mv_msg.
            raise_error( ).
          endif.
        endif.

        "Otherwise
        raise_error( ).
    endtry.

    "Remove system comment lines
    do 3 times.
      read table lt_ftplines into lv_line index 1.
      if ( lv_line = 'nlist' ) or
         ( lv_line(3) co '1234567890' and lv_line+3(1) = space ).
        delete lt_ftplines index 1.
      else.
        exit.
      endif.
    enddo.

    describe table lt_ftplines lines sy-tfill.
    read table lt_ftplines into lv_line index sy-tfill.
    if ( lv_line(3) co '1234567890' and lv_line+3(1)  = space        ) or
       ( lv_line(1)  = space        and lv_line+1(3) co '1234567890' ).
      delete lt_ftplines index sy-tfill.
    endif.

    "Return file list
    files = lt_ftplines.

  endmethod.


  method get_table_line_type.

    data lv_ref_descr type ref to cl_abap_typedescr.

    lv_ref_descr = cl_abap_tabledescr=>describe_by_data( p_data ).

    if lv_ref_descr->type_kind = 'h'.
      call method lv_ref_descr->('GET_TABLE_LINE_TYPE')
        receiving
          p_descr_ref = lv_ref_descr.

      rv_value = lv_ref_descr->type_kind.
    endif.

  endmethod.


  method get_text_file.

    refresh contents_tab.

    "Character mode
    ftp_command( |ascii| ).

    "Get file
    progress( msg     = |{ text-004 } { filename }|
              percent = percent ).

    clear sy-msgid.

    call function 'FTP_SERVER_TO_R3'
      exporting
        handle         = mv_ftphandle
        fname          = conv localfile( filename )
        character_mode = abap_true
      tables
        text           = contents_tab
      exceptions
        tcpip_error    = 1
        command_error  = 2
        data_error     = 3
        others         = 4.

    if sy-subrc <> 0.
      if sy-msgid is initial.
        message e003 into mv_msg.
      endif.
      raise_error( ).
    endif.

  endmethod.


  method open_in_explorer.

    data: lv_url type service_rl,
          lv_val type service_rl.

    lv_val = escape( val    = mv_username
                     format = cl_abap_format=>e_uri_full ).
    concatenate 'ftp://' lv_val into lv_url.

    lv_val = escape( val    = mv_password
                     format = cl_abap_format=>e_uri_full ).
    concatenate lv_url ':' lv_val into lv_url.

    concatenate lv_url '@' mv_host into lv_url.

    lv_val = escape( val    = mv_path
                     format = cl_abap_format=>e_uri_full ).
    if lv_val(1) = '/' or
       lv_val(1) = '\'.
      concatenate lv_url lv_val into lv_url.
    else.
      concatenate lv_url '/' lv_val into lv_url.
    endif.

    if programname is initial.
      call function 'GUI_RUN'
        exporting
          command = lv_url.
    else.
      call function 'GUI_RUN'
        exporting
          command   = programname
          parameter = lv_url.
    endif.

  endmethod.


  method progress.

    call function 'SAPGUI_PROGRESS_INDICATOR'
      exporting
        percentage = percent
        text       = msg.

  endmethod.


  method raise_error.

    data ls_symsg type symsg.

    move-corresponding syst to ls_symsg.

    raise exception type cx_bapi_error
      exporting
        t100_msgid = ls_symsg-msgid
        t100_msgno = ls_symsg-msgno
        t100_msgv1 = ls_symsg-msgv1
        t100_msgv2 = ls_symsg-msgv2
        t100_msgv3 = ls_symsg-msgv3
        t100_msgv4 = ls_symsg-msgv4.

  endmethod.


  method send_binary_file.

    "Binary mode
    ftp_command( |bin| ).

    "Send file
    progress( msg     = |{ text-003 } { filename }|
              percent = percent ).

    clear sy-msgid.

    call function 'FTP_R3_TO_SERVER'
      exporting
        handle         = mv_ftphandle
        fname          = conv localfile( filename )
        blob_length    = filesize
        character_mode = abap_false
      tables
        blob           = contents_tab
      exceptions
        tcpip_error    = 1
        command_error  = 2
        data_error     = 3
        others         = 4.

    if sy-subrc <> 0.
      if sy-msgid is initial.
        message e004 into mv_msg.
      endif.
      raise_error( ).
    endif.

  endmethod.


  method send_text_file.

    field-symbols <f_text> type standard table.

    "Character mode
    ftp_command( |ascii| ).

    "If the TEXT table is of type String, convert to a type C table
    if get_table_line_type( contents_tab ) = 'g'.
      data(lr_chartab_ref) = stringtab_to_chartab( contents_tab ).
      assign lr_chartab_ref->* to <f_text>.
    else.
      "Use the table itself
      assign contents_tab to <f_text>.
    endif.

    "Send file
    progress( msg     = |{ text-003 } { filename }|
              percent = percent ).

    call function 'FTP_R3_TO_SERVER'
      exporting
        handle         = mv_ftphandle
        fname          = conv localfile( filename )
        character_mode = abap_true
      tables
        text           = <f_text>
      exceptions
        tcpip_error    = 1
        command_error  = 2
        data_error     = 3
        others         = 4.

    if sy-subrc <> 0.
      "message e004 into mv_msg.
      raise_error( ).
    endif.

  endmethod.


  method stringtab_to_chartab.

    data lv_ref_line type ref to data.
    data line_size   type i value 1.

    field-symbols: <f_wa>   type any,
                   <f_line> type any,
                   <f_itab> type standard table.

    loop at text_tab assigning <f_wa>.
      if line_size < strlen( <f_wa> ).
        line_size = strlen( <f_wa> ).
      endif.
    endloop.

    create data lv_ref_line type c length line_size.
    assign lv_ref_line->* to <f_line>.
    create data chartab_ref like standard table of <f_line>.
    assign chartab_ref->* to <f_itab>.

    append lines of text_tab to <f_itab>.

  endmethod.

endclass.
