require File.expand_path(%q{../lib/rdk_lab/version}, __FILE__)

begin
  require 'hen'

  Hen.lay! {{
    gem: {
      name:         %q{rdk_lab},
      version:      RDKLab::VERSION,
      summary:      %q{RDK-SMW tools.},
      description:  %q{Tooling for the Semantic MediaWiki implementation of the German art history encyclopedia.},
      author:       %q{Jens Wille},
      email:        %q{jens.wille@gmail.com},
      license:      %q{AGPL-3.0},
      homepage:     :blackwinter,
      dependencies: %w[highline nokogiri nuggets open4 unicode] << ['mediawiki-gateway', '> 0.6'],

      required_ruby_version: '>= 1.9.3'
    }
  }}
rescue LoadError => err
  warn "Please install the `hen' gem. (#{err})"
end
