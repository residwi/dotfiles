require_relative "tasks/utils"

Dir.glob("./tasks/**/*.rake").each { |file| load file }

task default: [:install]

desc "Install Everything"
task :install do
  include Utils

  Rake::Task["install:homebrew"].invoke
  Rake::Task["install:brew_packages"].invoke
  Rake::Task["install:zsh"].invoke
  Rake::Task["install:symlinks"].invoke
  Rake::Task["install:neovim"].invoke
  Rake::Task["install:work"].invoke
  Rake::Task["install:tools"].invoke

  success "Install dotfiles completed successfully!" if $?.success?
end

desc "Backup Everything"
task :backup do
  include Utils

  Rake::Task["backup:homebrew"].invoke

  success "Backup completed successfully!" if $?.success?
end

desc "Update Everything"
task :update do
  include Utils

  Rake::Task["update:homebrew"].invoke
  Rake::Task["update:zsh"].invoke
  Rake::Task["update:neovim"].invoke

  success "Update completed successfully!" if $?.success?
end

desc "Show dotfiles status"
task :status do
  include Utils

  section "Dotfiles Status"

  success "Ruby: #{RUBY_VERSION}"

  if command_exists?("zsh")
    success "Zsh: installed"
  else
    error "Zsh: not installed"
  end

  if command_exists?("brew")
    success "Homebrew: installed"
  else
    error "Homebrew: not installed"
  end

  unless File.exist?(SYMLINK_CONFIG)
    error "Symlink config not found: #{SYMLINK_CONFIG}"
  end

  symlink_config = YAML.load_file(SYMLINK_CONFIG, symbolize_names: true)
  symlinks = symlink_config[:links]

  linked_count = 0
  missing_links = []

  symlinks.each do |symlink|
    target_path = File.expand_path(symlink[:target])
    if File.symlink?(target_path)
      linked_count += 1
    else
      missing_links << target_path
    end
  end

  if missing_links.empty?
    success "Symlinks: #{linked_count}/#{symlinks.length} (all linked)"
  else
    warning "Symlinks: #{linked_count}/#{symlinks.length} (some missing)"
    warning "Missing links: [#{missing_links.join(", ")}]"
  end

  nvim_config = File.expand_path("~/.config/nvim")
  if File.symlink?(nvim_config)
    success "Neovim config: linked"
  else
    info "Neovim config: not linked"
  end
end
