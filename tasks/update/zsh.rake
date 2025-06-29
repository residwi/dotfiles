namespace :update do
  desc "Update Oh My Zsh and plugins"
  task :zsh do
    include Utils

    section "Update Oh My Zsh"
    run "#{ENV["ZSH"]}/tools/upgrade.sh" if File.exist?("#{ENV["ZSH"]}/tools/upgrade.sh")

    section "Update zsh plugins"
    plugins_dir = ENV.fetch("ZSH_CUSTOM", File.expand_path("~/.oh-my-zsh/custom/plugins"))

    autosuggestions_dir = File.join(plugins_dir, "zsh-autosuggestions")
    run "git -C #{autosuggestions_dir} pull" if Dir.exist?(File.join(autosuggestions_dir, ".git"))

    highlighting_dir = File.join(plugins_dir, "zsh-syntax-highlighting")
    run "git -C #{highlighting_dir} pull" if Dir.exist?(File.join(highlighting_dir, ".git"))

    success "Zsh plugins update completed"
  end
end
