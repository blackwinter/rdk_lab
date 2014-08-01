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
require 'csv'

module RDKLab

  class Cat

    PATH = ENV['RDKLAB_SYS'] || 'sys-gsdl.txt'.freeze

    class << self

      def [](key)
        map[key]
      end

      def map
        @map ||= parse
      end

      def each
        map.each_value { |cat| yield cat }
      end

      def all(mw)
        mw.allcategories
      end

      def create(mw)
        each { |cat|
          puts cat.title
          cat.create(mw)
        }
      end

      def delete(mw)
        all(mw).each { |name|
          puts name
          mw.delete("Category:#{name}")
        }
      end

      private

      def parse
        map, hash, names = {}, {}, Hash.new(0)

        CSV.foreach(PATH, col_sep: ' ') { |row|
          key, sys, name = row
          parent = hash[sys.sub(/\.[^.]+\z/, '')] if sys.include?('.')

          names[name] += 1
          map[key] = hash[sys] = new(key, name, parent)
        }

        map.each_value { |cat| cat.ambiguous = names[cat.name] > 1 }
      end

    end

    attr_reader :key, :name, :parent

    attr_accessor :ambiguous

    def initialize(key, name, parent)
      @key, @name, @parent = key, name, parent
    end

    def fullname_parts
      @fullname_parts ||= begin
        parts = [name]
        parts.concat(parent.fullname_parts) if ambiguous
        parts
      end
    end

    def fullname
      @fullname ||= begin
        fullname = ''

        fullname_parts.each_with_index { |part, index|
          part = " (#{part})" if index > 0
          fullname << part
        }

        fullname
      end
    end

    def title
      "Category:#{fullname}"
    end

    def link
      "[[#{title}]]"
    end

    def body
      parent ? parent.link : '<!-- n/a -->'
    end

    alias_method :to_s, :body

    def create(mw)
      mw.create(title, to_s)
    end

    def delete(mw)
      mw.delete(title)
    end

  end

end
