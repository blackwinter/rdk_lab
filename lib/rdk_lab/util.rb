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

module RDKLab

  module Util

    DBM_PATH = ENV['RDKLAB_DBM'] || 'dbm/%s.dbm'.freeze

    SOURCE_ENCODING = 'WINDOWS-1252'.freeze
    TARGET_ENCODING = 'UTF-8'.freeze

    DBM_RE = %r{\A(\w+):(.+)}
    DBM_FS = ' | '.freeze
    DBM_RS = '&&&'.freeze

    VOLUME_RE = %r{\A(\d+)-}

    module ClassMethods

      def [](key)
        map[key]
      end

      def each(&block)
        map.each_value(&block)
      end

      def volume(id)
        id[VOLUME_RE, 1].to_i
      end

      private

      def map
        @map ||= parse_dbm(DBM_PATH % self::DBM, self::KEY)
      end

      def parse_dbm(dbm, key)
        map, record = {}, {}

        File.foreach(dbm,
          external_encoding: SOURCE_ENCODING,
          internal_encoding: TARGET_ENCODING
        ) { |line|
          line.chomp!

          if line.empty?
            next
          elsif line == DBM_RS
            map[record[key]], record = new(record), {}
          elsif line =~ DBM_RE
            record[$1] = $2
          else
            warn "Illegal line #{dbm}:#{$.}: #{line.inspect}"
          end
        }

        map
      end

    end

    def initialize(hash)
      @hash = hash
    end

    def <=>(other)
      id <=> other.id
    end

    def [](key)
      @hash[key]
    end

    def id
      self[self.class::KEY]
    end

    def volume
      @volume ||= self.class.volume(id)
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end

end
