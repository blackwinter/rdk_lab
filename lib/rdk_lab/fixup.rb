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
require 'highline/import'
require 'nuggets/integer/roman'

module RDKLab

  module FixUp

    extend self

    @config = {}

    def fixname(fix)
      "__fix__#{fix}"
    end

    def fixup(fix, content = '', title = nil)
      respond_to?(name = fixname(fix)) ?
        send(name, content, title) : abort("Invalid fix: #{fix}")
    rescue Exception => err
      raise if err.is_a?(SignalException)

      warn "#{title}: #{err}" if title
      raise unless agree('Continue? ')
    end

    def fix(fix, &block)
      !respond_to?(name = fixname(fix)) ? define_method(name, &block) :
        abort('Duplicate fix at line %d: %p. Previous definition at line %d.' % [
          block.source_location.last, fix, method(name).source_location.last
        ])
    end

    fix 'txt' do |content, title|
      dir = 'txt'

      Dir.mkdir(dir) unless title && File.exist?(dir)
      File.write("#{dir}/#{title}.txt", content) if title

      nil
    end

    fix 'empty lines' do |content, _|
      content.gsub!(/\n\n\n+/, "\n\n")
    end

    fix '*-lemma' do |content, _|
      config(:fixup_asterisk_lemma)[content]
    end

    fix 'see also' do |content, title|
      v = nomenclature(title)['Verweis beidseitig']
      return if v.empty?

      content.sub!(/(?=\n\[\[Category:)/) { "\n= Siehe auch =\n".tap { |b|
        list(b, v) { |l| b << "\n* [[#{l}]]" }
      } }
    end

    fix 'synonyms/pointers' do |content, title|
      h = nomenclature(title)

      content.sub!(/\s*\z/, "\n")

      !%w[Synonym Verweis].map { |k|
        h[k].each { |v| content << "\n[[#{k}::#{v}| ]]" }
      }.all?(&:empty?)
    end

    fix 'new categories (2)' do |*a|
      %w[drop new].each { |f| fixup("#{f} categories", *a) }
    end

    fix 'new categories' do |content, title|
      k = nomenclature(title)['Kategorie']
      return if k.empty?

      content.sub!(/\s*\z/, "\n")
      k.each { |c| content << "\n[[Category:#{c}]]" }
    end

    fix 'drop categories' do |content, _|
      content.gsub!(/\s*\[\[Category:.*?\]\]/, '')
    end

    fix 'span class' do |content, _|
      content.gsub!(/<span class=.*?>(.*?)<\/span>/im, '\1')
    end

    fix 'lemma tagging' do |content, _|
      content.gsub!(/\[\[Lemma::.*?\|(.*?)\]\]/i, '\1')
    end

    fix 'term tagging' do |content, _|
      content.gsub!(/\[\[Term::.*?\|(.*?)\]\]/i, '\1')
    end

    fix 'caption' do |content, _|
      content.gsub!(/(\[\[File:(\d{2})-(\d{4}).*?\|thumb\|)(?!RDK)(.*?)(\]\])/i) {
        a, b, c, d, e = $1, $2.to_i.to_roman, $3.to_i, $4, $5
        d.gsub!(/(?:\A|<\/i>)\s*(?=\d)/, '\&Abb. ')
        "#{a}RDK #{b}, #{c}, #{d}#{e}"
      }
    end

    fix 'caption2' do |content, title|
      return unless title =~ /:(\d{2})-(\d{4})/

      a, b = $1.to_i.to_roman, $2.to_i

      content.gsub!(/\A(?!RDK).*/) { |match|
        "RDK #{a}, #{b}, #{match.gsub(/(?:\A|<\/i>)\s*(?=\d)/, '\&Abb. ')}"
      }
    end

    fix 'volume/columns' do |content, title|
      columns = config(:columns)[title] or return
      content.sub!(/\[\[Band::(.*?)\|\s*\]\]/i) {
        "[[Band::#{$1}|RDK #{$1.to_i.to_roman}]], #{columns}"
      }
    end

    fix 'volume/columns2' do |content, _|
      content.prepend($&) if content.sub!(/(?<=\n)\[\[Band::.*\n+/i, '')
    end

    fix 'TOC' do |content, _|
      return if content.include?('__TOC__')
      content.sub!(/^=\s/, "__TOC__\n\n\\&") if content.scan(/^=\s/).size > 2
    end

    fix 'NOTOC' do |content, _|
      content.sub!(/^__TOC__\n+/, '') if content.scan(/^=\s/).size < 3
    end

    fix 'volume/columns3' do |content, _|
      content.sub!(/^(\[\[Band::.*)-/, '\1–')
    end

    fix 'authors' do |content, _|
      content.sub!(/^.*\n(^\[\[Autor::.*\n)+\n/, '') or return
      content.prepend($&.gsub(/\n(?=.)/, '').gsub(/<(\/?)i>/, '<\1big>'))
    end

    fix 'translations' do |content, title, _|
      translations = config(:translations)[title] or return
      translations = translations.map { |key, val|
        unless val.empty?
          val = val.map { |translation| "''#{translation}''" }.join(', ')
          "#{key}: #{val}"
        end
      }.compact.join('; ')

      content.prepend("#{translations}.\n\n") unless translations.empty?
    end

    def setup(file)
      case file
        when /\.dbm\z/i
          require 'midos'

          columns, translations =
            config(:columns, {}), config(:translations, {})

          Midos::Reader.parse_file(file, vs: ' | ') { |id, record|
            lemma = record['ART'].encode('UTF-8')

            columns[lemma], translations[lemma] =
              record['SPU'][/[\d-]+/], translation = {}

            %w[englisch französisch italienisch].each { |key|
              translation[key] = Array(record["X#{key[0, 2].upcase}"])
                                   .map { |val| val.encode('UTF-8') }
            }
          }
        when /gesamtnomenklatur/i
          require 'csv'

          nomenclature, re = config(:nomenclature, {}), /\s*;\s*/

          Dir[File.join(file, 'Gesamtnomenklatur-*.csv')].each { |csv|
            category = File.basename(csv)[/-(.+)\./, 1]

            CSV.foreach(csv, headers: true) { |row|
              hash = nomenclature[row['Lemma'] || row['Lemma neu']] ||= {}

              cats, row_h = hash['Kategorie'] ||= [], row.to_h
              cats << category
              cats.sort!.uniq!

              %w[Synonym Verweis Verweis\ beidseitig].each { |key|
                (hash[key] ||= []).concat(
                  (row_h[key] || '').split(re)).sort!.uniq!
              }
            }
          }

          lemma = config(:lemma, {})

          nomenclature.each { |l, h|
            s = h.values_at(*%w[Synonym Verweis]).flatten
            s.push($`) if l =~ /\s*\(.*?\)\z/

            s.each { |t|
              if lemma.key?(k = Unicode.downcase(t))
                lemma.delete(k) unless lemma[k] == l
              else
                lemma[k] = l
              end
            }
          }.each_key { |l| lemma[Unicode.downcase(l)] = l }

          sub = lambda { |a, b, c| (l = lemma(b)) ? "#{a}[[Lemma::#{l}|#{c}]]" : $& }

          tag_re = '\[\[\w+::\s*(%s)\s*\|\s*([^\]]+)\s*\]\]'
          pre_re = '(?:<nowiki>)?\*(?:</nowiki>)?\s*([,„])?'

          lemmata = lemma.keys.sort_by(&:length).reverse

          le1_re = /(?:#{lemmata.map(&Regexp.method(:escape)).join('|')})/i
          le2_re = lemmata.each_slice(1000).map { |slice|
            /#{pre_re}(?:#{slice.map { |l| l.split(/(\s+)/)
            .map(&Regexp.method(:escape)).each_slice(2).map { |x, y|
            "(?:(#{x})\\b|#{tag_re % x})(#{y})" }.join }.join('|')})/i }

          config(:fixup_asterisk_lemma, lambda { |content| any?(
            *le2_re.map { |re2| content.gsub!(re2) { u = $~.captures
              a, b, c = u.shift, '', ''; u.each_slice(4) { |w, x, y, z|
              b << "#{w || x}#{z}"; c << "#{w || y}#{z}" }; sub[ a,  b,  c] } },
            content.gsub!(/#{pre_re}#{tag_re % le1_re}/i) { sub[$1, $2, $3] },
            content.gsub!(/#{pre_re}(#{le1_re})\b/i)      { sub[$1, $2, $2] }
          ) })
        else
          abort "Invalid file: #{file}"
      end
    end

    def lemma(title)
      lemma = config(:lemma)
      title.nil? ? lemma.values.sample : lemma[Unicode.downcase(title)] ||
        lemma[lemma.keys.grep(/\A#{Regexp.escape(title)}\z/i).first]
    end

    def nomenclature(title)
      config(:nomenclature).fetch(lemma(title))
    end

    def config(key, value = nil)
      value ? @config[key] = value : @config.fetch(key)
    rescue KeyError
      abort "Config missing: #{key}"
    end

    private

    def list(content, ary, max = 20, num = 2, &block)
      num += 1 if ary.size > max * num
      content << list_begin(num) if ary.size > max
      ary.each(&block)
      content << list_end if ary.size > max
      content << "\n"
    end

    def list_begin(num = 2)
      style = ['', '-moz-', '-webkit-'].map { |prefix|
        "#{prefix}column-count:#{num}"
      }.join('; ')

      %Q{\n<div style="#{style}">}
    end

    def list_end
      "\n</div>"
    end

    def any?(*args)
      yield args if block_given?
      args.any?
    end

  end

end
