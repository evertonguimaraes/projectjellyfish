class SMTPListener
  def project_create(project, current_user)
    return nil unless smtp_enabled
    SMTPMailer.project_create(project, current_user).deliver_now unless Setting[:smtp_async_enabled]
    SMTPMailer.delay.project_create(project, current_user) if Setting[:smtp_async_enabled]
  end

  def order_create(_order, _current_user)
    return nil unless smtp_enabled
  end

  def project_approval_update(_project)
    return nil unless smtp_enabled
  end

  def smtp_enabled
    false if Setting[:smtp_enabled].nil?
    Setting[:smtp_enabled]
  end
end
