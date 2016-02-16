yum install -q -y httpd

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https

systemctl enable httpd
systemctl start httpd
