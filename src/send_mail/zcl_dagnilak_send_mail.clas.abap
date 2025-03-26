class zcl_dagnilak_send_mail definition
  public final
  create public.

  public section.

    class-methods send_mail
      importing
        i_sender       type ad_smtpadr                optional
        i_sender_name  type ad_smtpadr                optional
        i_subject      type so_obj_des                optional
        i_subject_long type string                    optional
        i_type         type so_obj_tp                 default 'RAW'
        i_mail_group   type soobjinfi1-obj_name       optional
        i_importance   type bcs_docimp                optional
        t_receiver     type zdagnilak_mail_rec_tab    optional
        t_text         type soli_tab                  optional
        t_attach       type zdagnilak_mail_attach_tab optional
      exporting
        e_message      type bapi_msg
        e_success      type flag.

endclass.


class zcl_dagnilak_send_mail implementation.

  method send_mail.

    try.
        data(lo_send_request) = cl_bcs=>create_persistent( ).
      catch cx_bcs into data(lx_bcs_exception).
        e_message = lx_bcs_exception->get_text( ).
        return.
    endtry.

    if i_sender is not initial.
      try.
          data(lo_sender) = cl_cam_address_bcs=>create_internet_address( i_address_string = i_sender
                                                                         i_address_name   = i_sender_name ).
          lo_send_request->set_sender( i_sender = lo_sender ).
        catch cx_bcs into data(lv_cx_bcs).
          "Gönderen adresi hatalı:
          e_message = |{ text-002 } { lv_cx_bcs->get_text( ) }|.
          return.
      endtry.

    endif.

    data(lt_receiver) = t_receiver[].

    if i_mail_group is not initial.
      data lt_dli_entries type table of sodlienti1.

      call function 'SO_DLI_READ_API1'
        exporting
          dli_name                   = i_mail_group
          shared_dli                 = 'X'
        tables
          dli_entries                = lt_dli_entries[]
        exceptions
          dli_not_exist              = 1
          operation_no_authorization = 2
          parameter_error            = 3
          x_error                    = 4
          others                     = 5.

      if sy-subrc <> 0.
        message id sy-msgid type 'W' number sy-msgno
                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 into data(lv_text).
        e_message = |{ e_message } { lv_text }.|.
      else.
        lt_receiver[] = value #( base lt_receiver[]
                                 for groups <wa_rec_group> of <wa_rec> in lt_dli_entries
                                 group by
                                 ( receiver = <wa_rec>-member_adr  )
                                 ascending
                                 ( receiver = <wa_rec_group>-receiver ) ).
      endif.

    endif.

    loop at lt_receiver into data(ls_receiver).
      try.
          data(lo_recipient) = cl_cam_address_bcs=>create_internet_address( ls_receiver-receiver ).

          lo_send_request->add_recipient( i_recipient  = lo_recipient
                                          i_copy       = ls_receiver-cc
                                          i_blind_copy = ls_receiver-bcc ).

        catch cx_bcs into lv_cx_bcs.
          continue.
      endtry.
    endloop.

    if sy-subrc <> 0.
      "Mail alıcısı bulunamadı.
      e_message = text-003.
      return.
    endif.

    try.
        data(lo_document) = cl_document_bcs=>create_document( i_type       = i_type
                                                              i_text       = t_text[]
                                                              i_subject    = cond #( when i_subject is not initial
                                                                                     then i_subject
                                                                                     else i_subject_long )
                                                              i_importance = i_importance ).

        loop at t_attach into data(ls_attach).

          if ls_attach-attach is not initial and
             ls_attach-size   is initial.
            data(l_lines) = lines( ls_attach-attach[]  ).
            ls_attach-size = l_lines * 255.
          endif.

          "Add attachment
          lo_document->add_attachment( i_attachment_type    = ls_attach-att_type
                                       i_attachment_subject = ls_attach-att_title
                                       i_attachment_size    = ls_attach-size
                                       i_att_content_text   = ls_attach-attach
                                       i_att_content_hex    = ls_attach-attachx ).

          clear l_lines.

        endloop.

        lo_send_request->set_document( lo_document ).

        if i_subject_long is not initial.
          lo_send_request->set_message_subject( i_subject_long ).
        endif.

      catch cx_bcs into lx_bcs_exception.
        e_message = lx_bcs_exception->get_text( ).
        return.
    endtry.

    try.
        e_success = lo_send_request->send( ).
        "Mail gönderildi.
        e_message = text-001.

      catch cx_bcs into lx_bcs_exception.
        e_message = lx_bcs_exception->get_text( ).
        return.
    endtry.

  endmethod.

endclass.
