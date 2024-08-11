# Migrate to Amazon Linux 2

## Create volume snapshot
* data.shwchurch
* os-hugo

## Create instance
* With Amazon Linux 2
* With 16  GB SSD volume for OS
* With 32  GB SSD volume from the snapshot `data`
* With 128 GB HDD volume from the snapshot `hugo`

## Assign temporary DNS for the migration (for https and test)
- Assign A record `tmp202408.shwchurch.org` in Moniker to the new server IP with TTL 300

## Install Nginx/Mysql/PHP
```zsh
sudo yum update -y
sudo yum install -y zsh
sudo yum install -y git
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
sudo su
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

exit 
exit 

sudo passwd ec2-user 

sudo yum install -y util-linux-user socat

chsh -s $(which zsh)
sudo chsh -s $(which zsh)

zsh

sudo amazon-linux-extras install -y mariadb10.5
sudo amazon-linux-extras install -y php7.4
sudo yum install -y php-gd php-xml php-mbstring php-pecl-memcache php-opcache php-pecl-apcu

sudo amazon-linux-extras list | grep nginx
sudo amazon-linux-extras install -y nginx1


sudo systemctl enable nginx
sudo systemctl start nginx

sudo usermod -a -G apache ec2-user

sudo vim /etc/php-fpm.d/www.conf 
# php_flag[display_errors] = on
# php_admin_value[error_log] = /mnt/data/shwchurch/log/php-fpm/error.log

```

## Mount EBS volumes
```zsh
lsblk

sudo file -s  /dev/xvdb

# note down the uuid of the volumes
sudo lsblk -f

sudo mkdir -p /mnt/data
sudo mount /dev/xvdb /mnt/data

sudo mkdir -p /mnt/hugo
sudo mount /dev/xvdc /mnt/hugo

sudo cp /etc/fstab /etc/fstab.orig

# note down the uuid of the volumes
sudo blkid

# Update the fstab accordingly (mount path; last digits are 0, 2)
sudo vim /etc/fstab

## UUID=aebf131c-*****-***** /mnt/data  xfs  defaults,nofail  0  2
## UUID=**** /mnt/hugo  xfs  defaults,nofail  0  2

sudo umount /mnt/data
sudo umount /mnt/hugo
sudo mount -a

df

sudo groupadd hugo
sudo useradd -g hugo hugo

sudo chown -R ec2-user:ec2-user /mnt/data
sudo chown -R apache:apache /mnt/data/shwchurch/web
sudo chown -R hugo:hugo /mnt/hugo

ln -s /mnt/data .
ln -s /mnt/hugo .

```

## Setup acme.sh

- Check DNS record
```zsh
# Make sure the DNS record is setup and propagated correctly in the previous step
ping tmp202408.shwchurch.org
```

- Setup Let's encrypt
```zsh

sudo amazon-linux-extras install -y epel
sudo yum install -y certbot-nginx

# replace 
# server_name  _;
# to 
# server_name tmp202408.shwchurch.org;
sudo vi /etc/nginx/nginx.conf
sudo systemctl restart nginx

sudo certbot --nginx -d tmp202408.shwchurch.org

sudo certbot renew --dry-run


```
* Try to use Chrome to open [https://tmp202408.shwchurch.org/](https://tmp202408.shwchurch.org/)

## Update nginx conf
```zsh
# restore 
# server_name tmp202408.shwchurch.org; 
# to server_name  _;
sudo vi /etc/nginx/nginx.conf

# 

sudo ln -s /mnt/data/nginx_conf/shwchurch.org /etc/nginx/conf.d/shwchurch.org.conf

# point to the temporary SSL in /etc/letsencrypt/live/tmp202408.shwchurch.org/*
vim /mnt/data/nginx_conf/shwchurch.org
sudo systemctl restart nginx

# Update wp-config to hard code tmp domain
sudo vim /mnt/data/shwchurch/web/wp-config.php 

echo "Set as follows"

#define('WP_HOME', 'https://tmp202408.shwchurch.org'); // no trailing slash
#define('WP_SITEURL', 'https://tmp202408.shwchurch.org');  // no trailing slash

```

## (optional) Update php.ini
```zsh
vim /etc/php.ini

echo Edit accordingly
# memory_limit = 1024M
# max_execution_time = 120
# post_max_size = 50M
# upload_max_filesize = 50M

sudo service php-fpm restart
```

## Update Database
### Database security update
```zsh
sudo systemctl enable mariadb.service
sudo systemctl start mariadb.service

# Set root password according to the password table
sudo mysql_secure_installation
```
### Database create
```zsh
sudo mv /mnt/data/shwchurch/tmp/pma_sw /mnt/data/shwchurch/web/
```
- Chrome open: https://tmp202408.shwchurch.org/pma_sw
- Root and its password last step
- Create user
    - Only allow localhost
    - with its same name database with all privileges
    -

```zsh
sudo mv /mnt/data/shwchurch/web/pma_sw /mnt/data/shwchurch/tmp/
```
### Database import

```zsh
cd /home/ec2-user/data/shwchurch/backup
tar zxf shwchurch_bak_2024-********.tar.gz
mysql -u shwchurch -p shwchurch < shwchurch_bak_2024-08-09.sql
```

### wp-content sync
```zsh
scp_sw  /mnt/data/shwchurch/web/wp-content/uploads/2024/08 $SW_USER_IP_OLD
```

## Cleanup
## DNS
- Change all DNS records to the new server
```zsh
# Make sure the change take effect
ping t5.shwchurch.org
```

### Update certs with DNS option

```zsh
# Get the DNS TXT token and update Moniker DNS
sudo certbot certonly --manual --preferred-challenges dns -d shwchurch.org  -d '*.shwchurch.org' 

```
- Update Moniker with the TXT with TTL 300 seconds and then verify; then precess continue on the step above
```zsh
# in remote linux server
nslookup -type=TXT _acme-challenge.shwchurch.org
```

### Update Nginx 
```zsh
# Point the the certs in the 
vim /mnt/data/nginx_conf/shwchurch.org

sudo systemctl restart nginx  
```

### Restore wordpress config
```zsh
sudo vim /mnt/data/shwchurch/web/wp-config.php 
#define('WP_HOME', 'https://t5.shwchurch.org'); // no trailing slash
#define('WP_SITEURL', 'https://t5.shwchurch.org');  // no trailing slash

```
### Detect W3 total cache 
- To go console and see if it works

### Start crontab
```zsh
cd /mnt/data/crontab
ls |  grep cron_ | grep -v grep | grep -v .bak | xargs -I{} sudo zsh {}
```

## Other tests and backup policy
* Label all AWS volumes with easy name
* Label AWS Volume backup policy (Data Lifecycle Manager)
    * data volume tag: 
        - backup:weekly
        - bak-yearly:true
    * hugo volume tag: 
        - No-need (will be backed with the instance monthly backup)
    * Instance tag: 
        - backup2:monthly
* Perform completion backup for all AWS volumes

* Try hugo sync
    - `(sudo -u hugo /mnt/hugo/github/t5/bin/sync.sh > /mnt/hugo/github/sync.log 2>&1 &); tail -f /mnt/hugo/github/sync.log`
* Set reminder to see if Database was backup in a week
* Set reminder to remove all volumes and the old instance in 2 week