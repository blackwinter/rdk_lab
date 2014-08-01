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
require 'unicode'
require 'open4'
require 'nuggets/io/interact'

module RDKLab

  class Article

    include Util

    DBM = 'lemma'.freeze
    KEY = 'ART'.freeze

    class << self

      def all(mw)
        mw.list('')
      end

      def create(mw)
        #ls = all(mw).map { |title| Unicode.downcase(title) }

        each { |article|
          #next if ls.include?(Unicode.downcase(article.title))
          puts article.title
          article.create(mw)
        }
      end

    end

    attr_writer :body

    def body
      @body ||= read
    end

    alias_method :to_s, :body

    def columns
      @columns ||= self['SPA'].split(DBM_FS)
    end

    def range(uniq = true)
      range = columns.values_at(0, -1)
      range.uniq! if uniq
      range
    end

    def pages
      @pages ||= columns.map { |id| Page[id] }
    end

    def volume
      @volume ||= self.class.volume(columns.first)
    end

    def title
      @title ||= id.tr('[]', '()')
    end

    def name
      @name ||= title.gsub(%r{[^\p{Word}]+}u, '_')
    end

    def authors
      @authors ||= self['AUT'].split(DBM_FS).map { |author|
        author.sub(/\s+[\[(].*/, '')
      }.uniq
    end

    def inverted_authors
      @inverted_authors ||= authors.map { |author|
        author =~ /\A([^(][^,]*)(\s+)(\S+)\z/ ? "#{$3},#{$2}#{$1}" : author
      }
    end

    def cats
      @cats ||= (self['SYS'] || '').
        split(DBM_FS).uniq.map { |key| Cat[key].link }
    end

    def tocs
      @tocs ||= begin
        j = nil
        pages.map { |page| page['TU2'] || page['TUE'] }.compact.
          join(DBM_FS).split(DBM_FS).delete_if { |i|
            j, k = i, j; j == k || i =~ /\A\[[^.]*\]\z/
          }
      end
    end

    def images
      @images ||= pages.map { |page| page.images }.flatten.sort.uniq
    end

    def inspect
      "#<#{self.class}:#{title}: #{range.join(' - ')}>"
    end

    def create(mw)
      mw.create(title, to_s, overwrite: true)
    end

    def delete(mw)
      mw.delete(title)
    end

    private

    def read
      body = pages.map { |page| page.body }.join("\n")

      body.gsub!(%r{\s+}, ' ')
      body.gsub!(%r{([\p{Word},;])</p>\s+<p>}u, '\1 ')
      body.gsub!(%r{(\p{Word})-</p>\s+<p>([\p{Word}\s])}u, '\1\2')
      body.gsub!(%r{\s*</?p>\s*}, "\n")
      body.gsub!(%r{^\*(?=[[:upper:]])}, '<nowiki>\&</nowiki>')
      body.strip!

      tire = Regexp.escape(title.sub(/\.\z/, ''))
      body.sub!(%r{\A<b>#{tire}(?:\.\s*</b>|\s*</b>\.)\s*}, '')

      unless tocs.empty?
        tocx, l = [], 1

        tocs.each { |i|
          j, m = i.split(/\s*:\s+/), [-1]

          m.unshift(-2) if l < h = j.size
          m.each { |n| tocx << [j[n], j[0..n].map { |k| k[/[^\[\s]+/] }] }

          l = h
        }

        body.sub!(%r{^#{tocx.map { |i, j|
          "#{Regexp.escape(j.last)}.*?"
        }.uniq.join}$}, '__TOC__')

        tocx.reverse_each { |i, j|
          r = j.map { |k| "^#{Regexp.escape(k)}\\s" }
          q = r.pop

          body.sub!(Regexp.new(
            "(#{r.map { |k| "#{k}(?m:.*?)" }.join})" <<
            "(?:^#{Regexp.escape(i)}[.:]\\s*|#{q})"
          ), "\\1#{h = '=' * j.size} #{i} #{h}\n\n")
        }
      end

      body.gsub!(
        /^(Zur Abbildung|Zu den Abbildungen|Literatur)(?:[.:]\s*)/,
        "= \\1 =\n\n"
      )

      body.sub!(/(\A.*)(^= Literatur =$.*?\z)/m, '\1')
      rest = $2 || ''

      index(body)

      body << rest << " ([[Jahr::#{self['JAH']}]])"

      inverted_authors.each { |author|
        body << "\n[[Autor::#{author}| ]]"
      }

      body << "\n\n[[Band::#{volume}| ]]"

      imgs = images.map { |img| img.link }.join("\n")
      body.insert(0, imgs << "\n\n") unless imgs.empty?

      body << "\n\n" << cats.join("\n") unless cats.empty?

      body
    end

    def index(body, cfg = 'smw', lang = 'cfg/de-bas')
      Open4.popen4(*%W[lingo -c #{cfg} -l #{lang}]) { |_, i, o, _|
        IO.interact({ body.dup => i }, { o => body.clear })
      }
    end

  end

end
