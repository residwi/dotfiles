namespace :install do
  desc "Setup symlinks for dotfiles"
  task :symlinks do
    include Utils

    section "Setup symlinks for dotfiles"

    unless File.exist?(SYMLINK_CONFIG)
      error "Symlink config not found: #{SYMLINK_CONFIG}"
      next
    end

    config = YAML.load_file(SYMLINK_CONFIG, symbolize_names: true)
    symlinks = config[:links]

    info "Processing #{symlinks.length} symlink entries"

    symlinks.each do |symlink|
      source_path = File.join(DOTFILES_BASE, symlink[:source])
      target_path = File.expand_path(symlink[:target])

      unless File.exist?(source_path)
        warning "Source file not found: #{source_path}"
        next
      end

      link_path(source_path, target_path)
    end
  end
end
