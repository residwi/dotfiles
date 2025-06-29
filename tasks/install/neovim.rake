namespace :install do
  desc "Setup Neovim config"
  task :neovim do
    include Utils

    section "Setup Neovim config"

    config_dir = File.expand_path("~/.config")
    ensure_directory config_dir

    nvim_src = File.join(DOTFILES_BASE, "nvim")
    nvim_dst = File.expand_path("~/.config/nvim")

    link_path(nvim_src, nvim_dst)

    info "Installing Neovim plugins"
    if command_exists?("nvim")
      run 'nvim --headless "+Lazy! sync" +qa'
    else
      warning "Neovim not found. Install it first"
    end
  end
end
