# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "local-https"
  spec.version       = File.read(File.expand_path("lib/local_https/VERSION", __dir__)).strip
  spec.authors       = ["Vikas Kumar"]
  spec.email         = ["vikas_kr@live.in"]

  spec.summary       = "Run any local app with HTTPS and a custom domain"
  spec.description   = "A simple Ruby CLI that generates mkcert certificates, " \
                       "updates /etc/hosts, and runs a HTTPS reverse proxy to your localhost apps."
  spec.homepage      = "https://github.com/vikas-0/local-https"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    Dir["bin/*", "lib/**/*", "README.md", "LICENSE*"].select { |f| File.file?(f) }
  end
  spec.bindir        = "bin"
  spec.executables   = ["local-https"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "thor", ">= 1.2", "< 2.0"
  spec.add_dependency "webrick", ">= 1.8", "< 2.0"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => File.join(spec.homepage, "issues"),
    "rubygems_mfa_required" => "true"
  }
end
