# frozen_string_literal: true

require "json"
require "fileutils"
require "etc"

module LocalHttps
  class Config
    DEFAULT_DIR = begin
      if ENV["LOCAL_HTTPS_HOME"]
        File.expand_path(ENV["LOCAL_HTTPS_HOME"]) 
      elsif ENV["SUDO_USER"] && Process.uid == 0
        File.join(Etc.getpwnam(ENV["SUDO_USER"]).dir, ".local-https")
      else
        File.expand_path("~/.local-https")
      end
    end.freeze
    CONFIG_PATH = File.join(DEFAULT_DIR, "config.json").freeze
    PID_PATH = File.join(DEFAULT_DIR, "proxy.pid").freeze

    attr_reader :data

    def self.ensure_dirs!
      FileUtils.mkdir_p(DEFAULT_DIR)
      FileUtils.mkdir_p(File.join(DEFAULT_DIR, "certs"))
    end

    def self.load
      ensure_dirs!
      if File.exist?(CONFIG_PATH)
        new(JSON.parse(File.read(CONFIG_PATH)))
      else
        new({ "mappings" => {}, "created_at" => Time.now.to_i, "updated_at" => Time.now.to_i })
      end
    end

    def self.save!(config)
      ensure_dirs!
      config.data["updated_at"] = Time.now.to_i
      File.write(CONFIG_PATH, JSON.pretty_generate(config.data))
    end

    def initialize(hash)
      @data = hash
      @data["mappings"] ||= {}
    end

    def add_mapping(domain, port)
      @data["mappings"][domain] = { "port" => Integer(port) }
    end

    def remove_mapping(domain)
      @data["mappings"].delete(domain)
    end

    def mappings
      @data["mappings"]
    end

    def pid
      Integer(File.read(PID_PATH)) if File.exist?(PID_PATH)
    rescue
      nil
    end

    def write_pid!(pid)
      File.write(PID_PATH, pid.to_s)
    end

    def clear_pid!
      FileUtils.rm_f(PID_PATH)
    end

    def proxy_running?
      p = pid
      return false unless p
      Process.kill(0, p)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end
  end
end
