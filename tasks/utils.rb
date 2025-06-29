require "fileutils"
require "pathname"
require "open-uri"
require "tempfile"
require "yaml"

module Utils
  DOTFILES_BASE = File.expand_path("~/dotfiles")
  BACKUP_DIR = File.join(DOTFILES_BASE, "backup")
  BACKUP_TIMESTAMP = Time.now.strftime("%Y%m%d%H%M%S")
  SYMLINK_CONFIG = File.join(DOTFILES_BASE, "symlink.yaml")

  COLORS = {
    info: 36,        # cyan
    success: 32,     # green
    error: 31,       # red
    warning: 33,     # yellow
    dim: 90,         # bright black
    highlight: 96    # bright cyan
  }

  SYMBOLS = {
    success: "✓",
    error: "✗",
    warning: "⚠",
    info: "ℹ"
  }

  def run command
    return debug(command) if dry_run?

    info "Executing '#{command}'"
    system(command)
  end

  def link_path(source, destination)
    source_relative = Pathname.new(source).relative_path_from(Pathname.new(DOTFILES_BASE))

    info "Linking #{source_relative} to #{destination}"

    if File.exist?(destination)
      return success "#{source_relative} already linked" if File.symlink?(destination)

      warning "#{destination} already exists"
      backup_file destination
    end

    dest_dirname = File.dirname(destination)
    if dry_run?
      debug "mkdir -p #{dest_dirname}"
      debug "ln -s #{source} #{destination}"
    else
      FileUtils.mkdir_p(dest_dirname)
      FileUtils.ln_s(source, destination)
    end

    success "#{source_relative} → #{destination} linked"
  end

  def backup_file(source)
    info "Backing up #{source}"

    backup_path = File.join(BACKUP_DIR, BACKUP_TIMESTAMP)
    if dry_run?
      debug "mkdir -p #{backup_path}"
      debug "mv #{source} #{backup_path}"
    else
      FileUtils.mkdir_p(backup_path)
      FileUtils.mv(source, backup_path)
    end

    success "#{source} backed up to #{backup_path}"
  end

  def download_file(url, destination)
    info "Downloading from #{url}"
    dest_path = File.expand_path(destination)
    filename = File.basename(destination)

    return debug "Download #{url} to #{dest_path}" if dry_run?

    FileUtils.mkdir_p(File.dirname(dest_path))

    begin
      open_uri_file = URI.parse(url).open

      Tempfile.create(filename) do |tempfile|
        tempfile.binmode
        tempfile.write(open_uri_file.read)
        tempfile.flush

        FileUtils.mv(tempfile.path, dest_path)
      end

      FileUtils.chmod(0o755, dest_path) if File.executable?(dest_path)

      success "#{filename} downloaded"
    rescue => e
      error "Failed to download #{url}: #{e.message}"
    end
  end

  def ensure_directory(path)
    expanded_path = File.expand_path(path)
    return success "Directory #{expanded_path} exists" if Dir.exist?(expanded_path)

    info "Creating directory #{expanded_path}"
    if dry_run?
      debug "mkdir -p #{expanded_path}"
    else
      FileUtils.mkdir_p(expanded_path)
    end

    success "Directory #{expanded_path} created"
  end

  def section(title)
    puts "\n#{colorize(title, :highlight)}"

    title_length = title.length
    puts colorize("─" * title_length, :dim)
  end

  def colorize(text, color_code)
    code = color_code.is_a?(Symbol) ? COLORS[color_code] : color_code
    return "\e[#{code}m#{text}\e[0m" if code

    text
  end

  def info(message)
    puts "#{colorize(SYMBOLS[:info], :info)}  #{colorize(message, :info)}"
  end

  def success(message)
    puts "#{colorize(SYMBOLS[:success], :success)}  #{colorize(message, :success)}"
  end

  def error(message)
    puts "#{colorize(SYMBOLS[:error], :error)}  #{colorize(message, :error)}"
    exit 1 unless dry_run?
  end

  def debug(message)
    return unless dry_run?
    puts "#{colorize(SYMBOLS[:warning], :warning)}  #{colorize("[DRY RUN]", :dim)} #{colorize(message, :dim)}"
  end

  def warning(message)
    puts "#{colorize(SYMBOLS[:warning], :warning)}  #{colorize(message, :warning)}"
  end

  def dry_run?
    ENV["DRY_RUN"] == "true"
  end

  def command_exists?(command)
    system("which #{command} > /dev/null 2>&1")
  end

  def macos?
    RUBY_PLATFORM.include?("darwin")
  end
end
