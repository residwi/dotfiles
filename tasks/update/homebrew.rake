namespace :update do
  desc "Update Homebrew and packages"
  task :homebrew do
    include Utils

    section "Update Homebrew and packages"

    if command_exists?("brew")
      info "Updating Homebrew"
      run "brew update"

      info "Upgrading packages"
      run "brew upgrade"

      info "Cleaning up old versions"
      run "brew cleanup"

      success "Homebrew update completed"
    else
      error "Homebrew not installed"
    end
  end
end
