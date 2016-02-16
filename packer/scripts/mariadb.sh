yum install -q -y mariadb-server

systemctl enable mariadb
systemctl start mariadb

mysql -u root <<EOT
  UPDATE mysql.user SET Password=PASSWORD('$PASSWORD') WHERE User='root';
  DELETE FROM mysql.user WHERE User<>'root';
  DELETE FROM mysql.db;
  DROP DATABASE test;
  FLUSH PRIVILEGES;
EOT
