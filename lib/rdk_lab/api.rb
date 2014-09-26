#--
###############################################################################
#                                                                             #
# rdk_lab -- RDK-SMW tools                                                    #
#                                                                             #
# Copyright (C) 2011-2014 Jens Wille                                          #
#                                                                             #
# Authors:                                                                    #
#     Jens Wille <jens.wille@gmail.com>                                       #
#                                                                             #
# rdk_lab is free software; you can redistribute it and/or modify it          #
# under the terms of the GNU Affero General Public License as published by    #
# the Free Software Foundation; either version 3 of the License, or (at your  #
# option) any later version.                                                  #
#                                                                             #
# rdk_lab is distributed in the hope that it will be useful, but              #
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY  #
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public      #
# License for more details.                                                   #
#                                                                             #
# You should have received a copy of the GNU Affero General Public License    #
# along with rdk_lab. If not, see <http://www.gnu.org/licenses/>.             #
#                                                                             #
###############################################################################
#++

require 'rdk_lab'
require 'media_wiki'
require 'highline/import'

REXML::Document.entity_expansion_text_limit *= 10

module RDKLab

  class API < MediaWiki::Gateway

    URL = ENV['RDK_LAB_URL'] || 'https://ixtrieve.fh-koeln.de/w/api.php'.freeze

    REDIRECT_RE = /^#(?:REDIRECT|WEITERLEITUNG)\s*\[\[(.*)\]\]/

    DEFAULT_LIMIT = 500

    class << self

      attr_accessor :dryrun

      def get(*args)
        dryrun ? Local.new : new(*args)
      end

      def gather_contents(block)
        titles, redirects, num = {}, {}, 0

        yield lambda { |api, title|
          print "\r", num += 1

          begin
            content = api.get(title)
          rescue MediaWiki::Exception => err
            puts "\n#{title}: #{err} (#{err.class})"
          else
            if content !~ REDIRECT_RE
              titles[title] = content
            else
              (redirects[redirect = $1] ||= []) << title

              if block and prematch = $` and !prematch.empty?
                block[title, redirect, $&, prematch, api.get(redirect)]
              end
            end
          end
        }

        puts if num > 0

        [titles, redirects]
      end

    end

    self.dryrun = ENV['DRYRUN']

    def initialize(login = false, options = {})
      super(URL, options, verify_ssl: false)
      self.login if login
    end

    def login(user = nil, pw = nil)
      user ||= ask("User for #{sitename}: ") { |q|
        q.default = ENV['USER'].capitalize if ENV['USER']
      }

      pw ||= ask("Password for #{user}: ") { |q|
        q.echo = false
      }

      super
    end

    %w[create delete upload].each { |name|
      class_eval <<-EOT, __FILE__, __LINE__ + 1
        def #{name}(*args)
          super
        rescue MediaWiki::Exception => err
          warn err.to_s
        end
      EOT
    }

    def allcontents(namespace = 0, &block)
      self.class.gather_contents(block) { |handler|
        iterate_list(:pages, 'title', '//p',
          'apnamespace' => namespace) { |title| handler[self, title] }
      }
    end

    def allimages
      iterate_list(:images, 'name', 'img')
    end

    def allcategories
      iterate_list(:categories, nil, 'c').map!(&:text)
    end

    def sitename
      siteinfo['sitename']
    rescue MediaWiki::APIError => err
      err.code == 'readapidenied' ? URL : raise
    end

    private

    def iterate_list(name, attr, res_xpath = nil, options = {}, &block)
      list, letter = "all#{name}", name[0]

      iterate_query(list, res_xpath, attr, "a#{letter}continue",
        options.merge("a#{letter}limit" => DEFAULT_LIMIT), &block)
    end

    class Local

      def initialize(dir = 'txt', out = nil)
        unless File.directory?(@dir = File.expand_path(dir))
          abort "No such directory: #{@dir}"
        end

        if File.directory?(@out = out ? File.expand_path(out) : "#{@dir}.out")
          require 'fileutils'
          FileUtils.rm_r(@out)
        elsif File.exist?(@out)
          abort "File exists: #{@out}"
        end

        Dir.mkdir(@out)
      end

      def get(title)
        File.read(filename(title))
      end

      def edit(title, content, _options = {})
        File.write(filename(title, @out), content)
      end

      def allcontents(&block)
        API.gather_contents(block) { |handler|
          Dir[filename('*')].sort.each { |txt|
            handler[self, File.basename(txt, '.txt')]
          }
        }
      end

      private

      def filename(title, dir = @dir)
        File.join(dir, "#{title}.txt")
      end

    end

  end

end
