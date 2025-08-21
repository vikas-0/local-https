# frozen_string_literal: true

require "thor"

module LocalHttps
  class CLI < Thor
    desc "add DOMAIN PORT", "Setup cert, /etc/hosts entry, and config mapping"
    def add(domain, port)
      config = Config.load
      CertManager.new.generate!(domain)
      DnsManager.new.add_host!(domain)
      config.add_mapping(domain, port)
      Config.save!(config)
      puts "Added mapping: #{domain} -> localhost:#{port}"
      puts "Certificate stored in ~/.local-https/certs"
      puts "Remember to run 'local-https start' (sudo may be required)"
    rescue => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "list", "List all active mappings"
    def list
      config = Config.load
      if config.mappings.empty?
        puts "No mappings configured."
      else
        puts "Mappings:"
        config.mappings.each do |domain, h|
          puts " - #{domain} => localhost:#{h["port"] || h[:port]}"
        end
      end
      puts "Proxy running: #{config.proxy_running?}#{" (pid #{config.pid})" if config.proxy_running?}"
    end

    desc "remove DOMAIN", "Remove mapping and stop proxy"
    def remove(domain)
      config = Config.load
      unless config.mappings.key?(domain)
        warn "No such domain in config: #{domain}"
        exit 1
      end
      DnsManager.new.remove_host!(domain)
      config.remove_mapping(domain)
      Config.save!(config)
      # Stop proxy so it can be restarted with updated SNI config (no WEBrick required)
      if config.proxy_running?
        begin
          Process.kill("TERM", config.pid)
          sleep 0.2
        rescue Errno::ESRCH, Errno::EPERM
        ensure
          config.clear_pid!
        end
      end
      puts "Removed mapping for #{domain} and stopped proxy. Run 'local-https start' to start again."
    rescue => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "start", "Start the HTTPS reverse proxy (binds to :443; may require sudo)"
    method_option :daemon, type: :boolean, default: true, aliases: "-d", desc: "Run in background"
    method_option :redirect_http, type: :boolean, default: true, desc: "Listen on :80 and redirect HTTP -> HTTPS"
    def start
      config = Config.load
      if config.proxy_running?
        puts "Proxy already running (pid #{config.pid})."
        return
      end
      if config.mappings.empty?
        warn "No mappings configured. Use 'local-https add <domain> <port>' first."
        exit 1
      end
      require_relative "proxy"
      Proxy.new(config: config).start!(daemonize: options[:daemon], redirect_http: options[:redirect_http])
    end

    desc "stop", "Stop the running proxy"
    def stop
      config = Config.load
      if config.proxy_running?
        begin
          Process.kill("TERM", config.pid)
          sleep 0.2
        rescue Errno::ESRCH, Errno::EPERM
        ensure
          config.clear_pid!
        end
        puts "Stopped proxy."
      else
        puts "Proxy not running."
      end
    end
  end
end
