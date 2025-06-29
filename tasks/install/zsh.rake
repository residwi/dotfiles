namespace :install do
  desc "Setup Oh My Zsh"
  task :zsh do
    include Utils

    section "Setup Oh My Zsh"

    zsh_path = ["/bin/zsh", "/usr/bin/zsh"].find { |path| File.exist?(path) }
    if zsh_path
      success "Zsh found at #{zsh_path}"
    else
      error "Zsh not found! Install it first."
    end

    oh_my_zsh_dir = ENV.fetch("ZSH", File.expand_path("~/.oh-my-zsh"))
    if Dir.exist?(oh_my_zsh_dir)
      success "Oh My Zsh already installed"
    else
      run 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    end

    section "Setup zsh plugins"

    plugins_dir = ENV.fetch("ZSH_CUSTOM", File.join(oh_my_zsh_dir, "custom", "plugins"))
    autosuggestions_dir = File.join(plugins_dir, "zsh-autosuggestions")
    if Dir.exist?(File.join(autosuggestions_dir, ".git"))
      success "zsh-autosuggestions plugin already installed"
      info "Run 'rake update:zsh' to update"
    else
      run "git clone https://github.com/zsh-users/zsh-autosuggestions #{autosuggestions_dir}"
    end

    highlighting_dir = File.join(plugins_dir, "zsh-syntax-highlighting")
    if Dir.exist?(File.join(highlighting_dir, ".git"))
      success "zsh-syntax-highlighting plugin already installed"
      info "Run 'rake update:zsh' to update"
    else
      run "git clone https://github.com/zsh-users/zsh-syntax-highlighting #{highlighting_dir}"
    end
  end
end
