#--
###############################################################################
#                                                                             #
# rdk_lab -- RDK-SMW tools                                                    #
#                                                                             #
# Copyright (C) 2011-2016 Jens Wille                                          #
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

require 'csv'
require 'rdk_lab'
require 'forwardable'
require 'nuggets/module/lazy_attr_mixin'

module RDKLab

  class CSV

    AUTHOR_COUNT = 8

    def self.export(*args)
      new(*args).export
    end

    def initialize(gnd = nil)
      @api, @date, @gnd = API.new, Date.today.strftime('%d.%m.%Y'), {}

      ::CSV.foreach(gnd) { |row| @gnd[row[0]] = row[1] } if gnd
    end

    attr_reader :api, :date, :gnd

    def export(io = $stdout)
      csv = ::CSV.new(io) << headers
      each { |row| csv << row.to_a }
    end

    def each
      api.each_page { |title|
        row = Row.new(self, title)

        begin
          yield row unless row.skip?
        rescue MediaWiki::Exception => err
          warn "#{title}: #{err} (#{err.class})"
        end
      }
    end

    private

    def headers
      Array.new(AUTHOR_COUNT) { |i| [
        "#{i + 1}. Autor in Ansetzungsform",
        "#{i + 1}. GND-Nummer" ] }.flatten.push(
        'Lemma',
        '1. Paralleltitel',
        '2. Paralleltitel',
        '3. Paralleltitel',
        'Name(n) in Vorlageform',
        'Herstellungsjahr',
        'Erscheinungsjahr',
        'Datum des Datenbankauszuges',
        'Revisionsnummer',
        'Hinweise'
      )
    end

    class Row

      extend Forwardable

      extend Nuggets::Module::LazyAttrMixin

      TRANSLATION_LINE_RE = /^englisch:(.*)/

      TRANSLATION_SEP_RE = /;.*?:/

      AUTHOR_LINE_RE = /^.*\[\[Autor::.*/

      AUTHORS_RE = /\[\[Autor::([^|\]]+)/

      NAMES_RE = /<big>(.*?)<\/big>/

      NAME_RE = /\[\[.*?\|(.*?)\]\]/

      YEAR_RE = /\[\[Jahr::\s*([^\s|\]]+)/

      SKIP_RE = /#{API::REDIRECT_RE}|\{\{Artikel_(erstellen|in_Bearbeitung)\}\}/

      SEPARATOR = '; '

      def self.note_attr(name, &block)
        lazy_attr(name) { instance_eval(&block) or note(name, 'missing') }
      end

      def initialize(rc, title)
        @rc, @title, @notes = rc, title, []
      end

      attr_reader :title, :notes

      def_delegators :@rc, :api, :date, :gnd

      lazy_attr(:skip?) { content =~ SKIP_RE || author_line.nil? }

      lazy_attr(:content) { api.get(title) }

      lazy_attr(:author_line) { content[AUTHOR_LINE_RE] }

      lazy_attr(:authors, freeze: false) {
        author_line.scan(AUTHORS_RE).flatten.each(&:strip!) }

      lazy_attr(:gnd_numbers, freeze: false) { gnd.values_at(*authors) }

      lazy_attr(:translation_line) {
        content[TRANSLATION_LINE_RE, 1].tap { |line|
          if line
            line.chomp!('.')
            line.chomp!(';')
            line.delete!("'")
          end
        } }

      lazy_attr(:translations, freeze: false) {
        translation_line.to_s.split(TRANSLATION_SEP_RE).each(&:strip!) }

      lazy_attr(:names, freeze: false) {
        author_line.scan(NAMES_RE).flatten.each { |name|
          name.gsub!(NAME_RE, '\1')
          name.strip!
          name.chomp!(',')
        } }

      note_attr(:year) { author_line[YEAR_RE, 1] || content[YEAR_RE, 1] }

      note_attr(:revision) { api.revision(title) }

      def to_a
        return [] if skip?

        count1, count2 = authors.size, names.size
        mismatch(:name, count1, count2) if count1 != count2

        slice(authors).zip(
        slice(gnd_numbers)).flatten.push(
        title).concat(
        slice(translations, 3, :translation)).push(
        slice(names).compact.join(SEPARATOR),
        year,
        year,
        date,
        revision,
        notes.join(SEPARATOR))
      end

      private

      def note(what, msg)
        notes << "#{what.capitalize} #{msg}"
      end

      def mismatch(type, expected, actual)
        note type, "mismatch (expected #{expected}, got #{actual})"
      end

      def slice(ary, size = AUTHOR_COUNT, type = nil)
        unless ary.size == size
          mismatch(type, size, ary.size) if type
          ary.size > size ? ary.slice!(size .. -1) : ary[size - 1] = nil
        end

        ary
      end

    end

  end

end
