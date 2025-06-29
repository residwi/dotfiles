namespace :install do
  desc "Setup work environment"
  task :work do
    include Utils

    section "Setup work environment"

    work_dir = File.expand_path("~/Work")
    ensure_directory(work_dir)

    info "Creating work gitconfig"
    work_gitconfig = File.join(work_dir, ".gitconfig")
    if File.exist?(work_gitconfig)
      success "Work gitconfig already exists"
      next
    end

    if dry_run?
      debug "touch #{work_gitconfig}"
    else
      FileUtils.touch(work_gitconfig)
    end
    success "Work gitconfig created"

    section "Create work utility scripts"

    info "Creating work utility scripts"
    script_path = File.join(work_dir, "prepare-work-env")
    if File.exist?(script_path)
      success "Work utility already exists"
      next
    end

    if dry_run?
      debug "touch #{script_path}"
      debug "chmod 755 #{script_path}"
    else
      FileUtils.touch(script_path)
      FileUtils.chmod(0o755, script_path)
    end
    success "Work utility scripts created"
  end
end
