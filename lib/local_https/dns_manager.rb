# frozen_string_literal: true

require "tempfile"

module LocalHttps
  class DnsManager
    HOSTS_PATH = "/etc/hosts".freeze
    MARKER = "# local-https".freeze

    def add_host!(domain)
      return if hosts_lines.any? { |l| l.include?(" #{domain}") }
      line = "127.0.0.1 #{domain} #{MARKER}"
      sh_with_sudo!("echo '#{line}' >> #{HOSTS_PATH}")
    end

    def remove_host!(domain)
      lines = hosts_lines.reject { |l| l.include?(" #{domain}") && l.include?(MARKER) }
      tmp = Tempfile.new("hosts-local-https")
      begin
        tmp.write(lines.join)
        tmp.close
        sh_with_sudo!("cp #{tmp.path} #{HOSTS_PATH}")
      ensure
        tmp.unlink
      end
    end

    private

    def hosts_lines
      File.read(HOSTS_PATH).lines
    rescue Errno::EACCES
      warn "Permission denied reading #{HOSTS_PATH}. Try running with sudo."
      []
    end

    def sh_with_sudo!(cmd)
      full = ["sudo", "sh", "-c", cmd]
      system(*full) or raise "Failed to run: #{full.join(' ')}"
    end
  end
end
