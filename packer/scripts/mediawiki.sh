yum install -q -y patch php php-intl php-mbstring php-mysql policycoreutils-python

mysql -u root -p$PASSWORD <<EOT
  CREATE DATABASE $DATABASE;
  GRANT ALL ON $DATABASE.* TO '$DATABASE'@'localhost' IDENTIFIED BY '$WIKIPASS';
EOT

yum install -q -y "$UPLOAD/php-pecl-apc.rpm"

curl -sSL https://getcomposer.org/installer |\
  php -- --install-dir=/usr/local/bin --filename=composer

if [ -n "$VERSION" ]; then
  wiki="/var/www/html/w"
  conf="wiki.conf"
  base="/opt"

  cp "$UPLOAD/mw-permissions" /usr/local/bin

  for version in ${VERSION//:/ }; do
    name="mediawiki-$version"
    path="$base/$name"

    [ -z "$link" ] && link="$path"

    curl -sSL "$RELEASES/${version%.*}/${name}.tar.gz" | tar xzf - -C "$base"

    cp "$UPLOAD"/*.patch "$path/extensions"
    mw-permissions "$path"
  done

  ln -s "$link" "$wiki"

  sed "s:%WIKI%:$wiki:g" "$UPLOAD/$conf" > "/etc/httpd/conf.d/$conf"
fi
