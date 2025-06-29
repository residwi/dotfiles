namespace :update do
  desc "Update Neovim plugins"
  task :neovim do
    include Utils

    section "Update Neovim plugins"

    info "Updating Neovim plugins"
    if command_exists?("nvim")
      run 'nvim --headless "+Lazy! sync" +qa'
      success "Neovim plugins updated"
    else
      error "Neovim not found. Install it first"
    end
  end
end
