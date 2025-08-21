# frozen_string_literal: true

require "fileutils"

module LocalHttps
  class CertManager
    CERTS_DIR = File.join(Config::DEFAULT_DIR, "certs").freeze

    def initialize
      FileUtils.mkdir_p(CERTS_DIR)
    end

    def cert_path(domain)
      File.join(CERTS_DIR, "#{domain}.pem")
    end

    def key_path(domain)
      File.join(CERTS_DIR, "#{domain}-key.pem")
    end

    def have_cert?(domain)
      File.exist?(cert_path(domain)) && File.exist?(key_path(domain))
    end

    def ensure_mkcert!
      return true if system("which mkcert > /dev/null 2>&1")
      raise "mkcert is required but not found. Please run install.sh or install mkcert manually."
    end

    def generate!(domain)
      ensure_mkcert!
      return if have_cert?(domain)

      cert = cert_path(domain)
      key  = key_path(domain)
      cmd = [
        "mkcert",
        "-cert-file", cert,
        "-key-file", key,
        domain
      ]
      system(*cmd) or raise "Failed to generate certificate for #{domain} via mkcert"
    end

    # Generate a bundle cert that includes all domains (optional optimization)
    def ensure_combined_cert!(domains)
      return if domains.empty?
      combined = File.join(CERTS_DIR, "combined.pem")
      combined_key = File.join(CERTS_DIR, "combined-key.pem")
      return if File.exist?(combined) && File.exist?(combined_key)
      ensure_mkcert!
      cmd = [
        "mkcert", "-cert-file", combined, "-key-file", combined_key,
      ] + domains
      system(*cmd) or raise "Failed to generate combined certificate"
    end
  end
end
