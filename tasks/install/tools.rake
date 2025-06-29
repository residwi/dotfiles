namespace :install do
  desc "Setup development tools"
  task :tools do
    include Utils

    section "Setup development tools"

    tools_dir = File.expand_path("~/Development/tools")
    ensure_directory(tools_dir)

    docker_compose_src = File.join(DOTFILES_BASE, "tools", "compose.yaml")
    docker_compose_dst = File.join(tools_dir, "compose.yaml")

    if File.exist?(docker_compose_src)
      link_path(docker_compose_src, docker_compose_dst)
    else
      warning "#{docker_compose_src} not found, skipping"
    end
  end
end
