# frozen_string_literal: true

require "webrick"
require "webrick/https"
require "openssl"
require "net/http"
require "uri"
require "socket"
require "timeout"
require "fileutils"

module LocalHttps
  class Proxy
    DEFAULT_BIND = "0.0.0.0"
    DEFAULT_PORT = 443
    HOP_BY_HOP = %w[
      connection proxy-connection keep-alive transfer-encoding upgrade te trailer
    ].freeze
    NET_HTTP_CLASS = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PUT" => Net::HTTP::Put,
      "DELETE" => Net::HTTP::Delete,
      "PATCH" => Net::HTTP::Patch,
      "HEAD" => Net::HTTP::Head,
      "OPTIONS" => Net::HTTP::Options
    }.freeze

    def initialize(config: Config.load, cert_manager: CertManager.new)
      @config = config
      @cert_manager = cert_manager
    end

    def start!(bind: DEFAULT_BIND, port: DEFAULT_PORT, daemonize: true, redirect_http: true)
      Process.daemon(true, true) if daemonize

      https_server = build_server(bind, port)
      http_server = nil
      if redirect_http
        begin
          http_server = build_http_redirect_server(bind)
        rescue Errno::EACCES
          warn "Permission denied binding to port 80 for HTTP redirect. Continuing without HTTP redirect."
        rescue Errno::EADDRINUSE
          warn "Port 80 is already in use. Continuing without HTTP redirect."
        rescue StandardError => e
          warn "Failed to initialize HTTP redirect server: #{e.class}: #{e.message}"
        end
      end

      trap("INT") do
        begin
          https_server.shutdown
        rescue StandardError => e
          warn "HTTPS server shutdown error: #{e.class}: #{e.message}"
        end
        begin
          http_server&.shutdown
        rescue StandardError => e
          warn "HTTP redirect server shutdown error: #{e.class}: #{e.message}"
        end
      end
      trap("TERM") do
        begin
          https_server.shutdown
        rescue StandardError => e
          warn "HTTPS server shutdown error: #{e.class}: #{e.message}"
        end
        begin
          http_server&.shutdown
        rescue StandardError => e
          warn "HTTP redirect server shutdown error: #{e.class}: #{e.message}"
        end
      end

      @config.write_pid!(Process.pid)

      # Start HTTP redirector in a thread (if available), then start HTTPS
      if http_server
        Thread.new do
          http_server.start
        rescue StandardError => e
          warn "HTTP redirector stopped: #{e.class}: #{e.message}"
        end
      end

      https_server.start
    rescue Errno::EACCES
      warn "Permission denied binding to port #{port}. Try: sudo local-https start"
      exit 1
    rescue Errno::EADDRINUSE
      warn "Port #{port} is already in use."
      warn "To see which process is listening, run:"
      warn "  sudo lsof -nP -iTCP:#{port} -sTCP:LISTEN"
      if @config.proxy_running?
        warn "If it's local-https (pid #{@config.pid}), stop it with:"
        warn "  sudo local-https stop"
      end
      warn "Otherwise, stop the conflicting process and try again."
      exit 1
    ensure
      @config.clear_pid!
    end

    def stop!
      if @config.proxy_running?
        pid = @config.pid
        Process.kill("TERM", pid)
        sleep 0.2
      end
      @config.clear_pid!
    rescue Errno::ESRCH
      @config.clear_pid!
    end

    private

    def build_server(bind, port)
      # Determine default cert (first mapping or localhost)
      domains = @config.mappings.keys
      default_domain = domains.first || "localhost"
      ensure_domain_cert!(default_domain)
      default_cert = OpenSSL::X509::Certificate.new(File.read(@cert_manager.cert_path(default_domain)))
      default_key  = OpenSSL::PKey.read(File.read(@cert_manager.key_path(default_domain)))

      # Build SNI config for all configured domains
      sni_config = {}
      domains.each do |d|
        ensure_domain_cert!(d)
        cert = OpenSSL::X509::Certificate.new(File.read(@cert_manager.cert_path(d)))
        key  = OpenSSL::PKey.read(File.read(@cert_manager.key_path(d)))
        sni_config[d] = { SSLCertificate: cert, SSLPrivateKey: key }
      rescue StandardError => e
        warn("[local-https] Skipping SNI for #{d}: #{e.class}: #{e.message}")
      end

      httpd = WEBrick::HTTPServer.new(
        BindAddress: bind,
        Port: port,
        SSLEnable: true,
        SSLStartImmediately: true,
        SSLCertificate: default_cert,
        SSLPrivateKey: default_key,
        SSLSNIConfig: sni_config,
        DoNotReverseLookup: true,
        AccessLog: [],
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
        RequestTimeout: 60,
        KeepAliveTimeout: 5,
        MaxClients: 128,
        StartCallback: proc { $stdout.puts "local-https proxy listening on https://#{bind}:#{port}" }
      )

      httpd.mount_proc("/") do |req, res|
        handle_proxy(req, res)
      end

      httpd
    end

    def build_http_redirect_server(bind)
      httpd = WEBrick::HTTPServer.new(
        BindAddress: bind,
        Port: 80,
        DoNotReverseLookup: true,
        AccessLog: [],
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
        RequestTimeout: 30,
        KeepAliveTimeout: 2,
        MaxClients: 128
      )

      httpd.mount_proc("/") do |req, res|
        host = (req["host"] || "").split(":").first
        path = req.path || "/"
        qs = req.query_string
        location = "https://#{host}#{path}"
        location += "?#{qs}" if qs && !qs.empty?
        res.status = 301
        res["Location"] = location
        res["Content-Type"] = "text/html"
        res.body = "<a href=\"#{location}\">Moved Permanently</a>\n"
      end

      httpd
    end

    def handle_proxy(req, res)
      host = (req["host"] || "").split(":").first
      mapping = @config.mappings[host]
      unless mapping
        res.status = 502
        res["content-type"] = "text/plain"
        res.body = "No mapping found for #{host}\n"
        return
      end

      target_host = "127.0.0.1"
      target_port = begin
        Integer(mapping["port"])
      rescue StandardError
        Integer(mapping[:port])
      end

      uri = URI::HTTP.build(host: target_host, port: target_port, path: req.path)

      Net::HTTP.start(uri.host, uri.port, read_timeout: 60, open_timeout: 5) do |http|
        klass = net_http_class(req.request_method)
        proxy_req = klass.new(uri.request_uri)

        req.each do |k, v|
          kk = k.to_s.downcase
          next if HOP_BY_HOP.include?(kk)

          proxy_req[k] = v
        end
        proxy_req.body = req.body if req.body && !req.body.empty?

        http.request(proxy_req) do |proxy_res|
          res.status = proxy_res.code.to_i
          proxy_res.each_header do |k, v|
            kk = k.to_s.downcase
            next if HOP_BY_HOP.include?(kk)

            res[k] = v
          end
          if proxy_res.body
            res.body = proxy_res.body
          else
            # stream chunks
            buf = +""
            proxy_res.read_body do |chunk|
              buf << chunk
            end
            res.body = buf
          end
        end
      end
    rescue StandardError => e
      res.status = 502
      res["content-type"] = "text/plain"
      res.body = "Proxy error: #{e.class}: #{e.message}\n"
    end

    def net_http_class(method)
      NET_HTTP_CLASS[method.to_s.upcase] || Net::HTTP::Get
    end

    def ensure_domain_cert!(domain)
      # Generate for known mappings or localhost
      return if domain.nil? || domain.empty?

      if domain == "localhost"
        @cert_manager.generate!(domain) unless @cert_manager.have_cert?(domain)
        return
      end
      return unless @config.mappings.key?(domain)

      @cert_manager.generate!(domain)
    end
  end
end
