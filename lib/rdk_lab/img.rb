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

  class Img

    include Util

    URL = 'http://rdk.zikg.net/rdkdaten/abb'.freeze

    DBM = 'bild'.freeze
    KEY = 'ABB'.freeze

    class << self

      def for(id)
        (@for ||= by_id)[id]
      end

      def all(mw)
        mw.allimages
      end

      def create(mw)
        ls = all(mw)

        each { |img|
          next if ls.include?(img.name)
          puts img.name
          img.create(mw)
        }
      end

      def delete(mw)
        all(mw).each { |name|
          puts name
          mw.delete("File:#{name}")
        }
      end

      private

      def by_id
        hash, keys = Hash.new { |h, k| h[k] = [] }, %w[ZSP BIL ZSB]

        each { |img| keys.each { |key|
          val = img[key]
          hash[val] << img if val
        } }

        hash
      end

    end

    def name
      "#{id}.jpg"
    end

    def title
      "File:#{name}"
    end

    def url
      File.join(URL, '%02d' % volume, name)
    end

    def caption
      self['BUN']
    end

    def text
      self['TZB']
    end

    def legend
      self['LEG']
    end

    def body
      body = [caption, text].compact.join(': ')
      (l = legend) ? body << "\n\n#{l}" : body
    end

    alias_method :to_s, :body

    def link
      "[[#{title}|thumb|#{caption}]]"
    end

    def inspect
      "#<#{self.class}:#{url}>"
    end

    def create(mw)
      mw.upload(nil,
        'url'            => url,
        'text'           => to_s,
        'filename'       => name,
        'ignorewarnings' => true
      )
    end

    def delete(mw)
      mw.delete(title)
    end

  end

end
