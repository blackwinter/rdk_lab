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
require 'nokogiri'

module RDKLab

  class Page

    include Util

    PATH = ENV['RDKLAB_PAG'] || 'pag/%02d/%s.html'.freeze

    DBM = 'seite'.freeze
    KEY = 'SPA'.freeze

    IMG_MAP = {
      'Christusmonogramm_P+'             => nil,
      'Christusmonogramm_SchraegstrichP' => nil,
      'Christusmonogramm_X'              => nil,
      'Christusmonogramm_XI'             => nil,
      'Christusmonogramm_XP'             => "\u2627",
      'Christusmonogramm_XP+'            => nil,
      'Christusmonogramm_gespiegeltP+'   => nil,
      'Christusmonogramm_gespiegeltX'    => nil,
      'Christusmonogramm_gespiegeltXP'   => nil,
      'Emblem_153'                       => nil,
      'Meister_W'                        => nil,
      'Minuskel_ihs'                     => nil,
      'Minuskel_yhs'                     => nil,
      'Monogrammist_AHP'                 => nil,
      'Monogrammist_ia'                  => nil,
      'Nilschluessel_707'                => "\u2625",
      'Rune'                             => "\u16C9",
      'Tabelle_835'                      => nil,
      'a_mit_e'                          => "a\u0364",
      'e_mit_cedilla'                    => "\u0229",
      'g_mit_ueberstrich'                => "g\u0305",
      'gefallen'                         => "\u2694",
      'ihs_mit_strich'                   => nil,
      'kursiv_e_mit_tilde'               => "\u1EBD",
      'kursiv_u_mit_e'                   => "u\u0364",
      'm_mit_Strich'                     => "m\u0305",
      'm_mit_strich'                     => "m\u0305",
      'm_mit_strich_kursiv'              => "m\u0305",
      'n_gross_mit_strich'               => "N\u0305",
      'n_mit_Strich'                     => "n\u0305",
      'n_mit_Ueberstrich'                => "n\u0305",
      'n_mit_strich'                     => "n\u0305",
      'o_mit_cedilla'                    => "o\u0327",
      'o_mit_e'                          => "o\u0364",
      'o_mit_u'                          => "o\u0367",
      'r_mit_Strich'                     => "r\u0305",
      'r_mit_strich'                     => "r\u0305",
      'ra_mit_Welle'                     => nil,
      'russisches_inventar'              => nil,
      's_mit_strich'                     => "S\u0305",
      'sampi_fingerzahlen'               => nil,
      'u_mit_e'                          => "u\u0364",
      'u_mit_hochgestelltem_e'           => "u\u0364",
      'u_mit_o'                          => "u\u0366",
      'v_mit_hochgestelltem_e'           => "v\u0364",
      'x_mit_strich'                     => "x\u0305",
      'y_mit_ueberstrich'                => "y\u0305"
    }

    def path
      @path ||= PATH % [volume, id]
    end

    def body
      @body ||= read_body
    end

    alias_method :to_s, :body

    def images
      @images ||= Img.for(id)
    end

    def inspect
      "#<#{self.class}:#{path}>"
    end

    private

    def read_body
      node = Nokogiri::HTML(File.read(path), nil, SOURCE_ENCODING)
      node.encoding = TARGET_ENCODING

      body = node.root.at_xpath('body')

      [
        '//p[span[contains(., "SPALTENWECHSEL")]]',
        '//span[contains(., "SPALTENWECHSEL")]',
        'table[tr[@id="navlinks"]]'
      ].each { |x| body.xpath(x).each { |n| n.remove } }

      [
        '*/span[@class="font1" or @class="font2" or @class="font3" or @class="font4"]'
      ].each { |x| body.xpath(x).each { |n| n.replace(n.inner_html) } }

      body.xpath('//img').each { |n|
        n.replace(IMG_MAP[File.basename(src = n['src'], '.gif')] || src)
      }

      body.inner_html
    end

  end

end
