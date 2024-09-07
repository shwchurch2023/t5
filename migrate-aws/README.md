# Migrate to Amazon Linux 2

## Create volume snapshot

- data.shwchurch
- os-hugo

## Create instance

- With Amazon Linux 2
- With 16 GB SSD volume for OS
- With 32 GB SSD volume from the snapshot `data`
- With 128 GB HDD volume from the snapshot `hugo`

## Assign temporary DNS for the migration (for https and test)

- Assign A record `tmp202408.shwchurch.org` in Moniker to the new server IP with TTL 300

## Install Nginx/Mysql/PHP

```zsh
sudo yum update -y
sudo yum groupinstall "Development Tools"
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


sudo amazon-linux-extras list | grep nginx
sudo amazon-linux-extras install -y mariadb10.5 epel php7.4 nginx1

sudo yum install -y php-gd php-xml php-mbstring php-pecl-memcache php-opcache php-pecl-apcu php-cli php-common php-gd php-jsonc php-mbstring php-mysqlnd php-odbc php-pdo php-pecl-apcu php-process php-soap php-xml php-devel php-xdebug php-pear 

sudo pecl channel-update pecl.php.net
sudo pecl install xdebug-3.1.6
# After xdebug is installed, follow the prompt by adding 

# zend_extension=/usr/lib64/php/modules/xdebug.so
#xdebug.mode=profile
#xdebug.output_dir=/mnt/data/shwchurch/log/xdebug_profiling
# to /etc/php.ini

# For xdebug SSH portforwarding
# ssh -i ****.pem -R 9003:localhost:9003 ec2-user@t5.shwchurch.org
# Then install VSCode PHP Debug

sudo systemctl enable php-fpm
sudo systemctl restart php-fpm
php -r 'xdebug_info();'

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
ln -s /mnt/data/shwchurch/web/wp-content/themes/shwchurch .

```

## Setup acme.sh

- Check DNS record

```zsh
# Make sure the DNS record is setup and propagated correctly in the previous step
ping tmp202408.shwchurch.org
```

- Setup Let's encrypt

```zsh

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

- Try to use Chrome to open [https://tmp202408.shwchurch.org/](https://tmp202408.shwchurch.org/)

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

## Optimize php-fpm threads

```zsh
sudo vim  /etc/php-fpm.d/www.conf

echo Edit accordingly

# pm = dynamic
# pm.max_children = 100
# pm.start_servers = 32
# pm.min_spare_servers = 16
# pm.max_spare_servers = 32
# pm.max_requests = 200

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
ls | grep cron | grep -v grep | xargs -I{} sudo zsh -c 'zsh ./{} &'
ls /etc/cron.d/*
```

### Setup github SSH key auth

- Setup zsh
  - with user hugo `sudo -u hugo zsh`

```zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

- GitHub Config
  - with user hugo `sudo -u hugo zsh`

```zsh
git config --global user.name "ShouwangChurch"
git config --global user.email "shwchurch3@gmail.com"
git config --global --add safe.directory /mnt/hugo/github/t5
ls | grep github.io | grep -v grep | xargs -I{} git config --global --add safe.directory /mnt/hugo/github/t5/{}
git config --global --add safe.directory /mnt/hugo/github/t5/themes/hugo-theme-shwchurch
exit
```

    - with ec2-user

```zsh
git config --global user.name "ShouwangChurch"
git config --global user.email "shwchurch3@gmail.com"
git config --global --add safe.directory /mnt/data/shwchurch/web/wp-content/themes/shwchurch
```

- t5
  - with user hugo `sudo -u hugo zsh`

```zsh
source /mnt/hugo/github/t5/bin/backup-t5-to-multiple-origins.sh
testMigratedPush
```

- t5 hugo media

```zsh
cd /mnt/hugo/github/t5
ls | grep github.io | grep -v grep | xargs -I{} zsh -c 'source /mnt/hugo/github/t5/bin/backup-t5-to-multiple-origins.sh; testMigratedPush /mnt/hugo/github/t5/{} {}'
```

- t5 theme

```zsh

source /mnt/hugo/github/t5/bin/backup-t5-to-multiple-origins.sh
testMigratedPush /mnt/hugo/github/t5/themes/hugo-theme-shwchurch hugo-theme-shwchurch

```

- init hugo env
```zsh
cd /mnt/hugo
sudo -u hugo zsh
whoami
env > .env
cat .env
```

- SW theme

```zsh
source /mnt/hugo/github/t5/bin/backup-t5-to-multiple-origins.sh
testMigratedPush /mnt/data/shwchurch/web/wp-content/themes/shwchurch wordpress_theme_shwchurch
```

## Health checkup

- Clean all W3 Total cache
- Category permanent link: https://t5.shwchurch.org/category/%e7%bd%91%e7%bb%9c%e6%9c%9f%e5%88%8a/%e8%81%8c%e5%9c%ba%e5%91%bc%e5%8f%ac/
- Feed https://t5.shwchurch.org/category/sermon/sermon_archived_0/feed/
- Latest post
- amp: https://t5.shwchurch.org/2024/08/10/beijingshouwangjiaohui2024nian8yue11rizhurijingbaichengxu/amp/

## Backups

### Other tests and backup policy

- Label all AWS volumes with easy name
- Label AWS Volume backup policy (Data Lifecycle Manager)
  - data volume tag:
    - backup:weekly
    - bak-yearly:true
  - hugo volume tag:
    - No-need (will be backed with the instance monthly backup)
  - Instance tag:
    - backup2:monthly
- Remove all backup related tags for
  - The old instance
  - And all of its volumes
- Perform completion backup for all AWS volumes

- Try hugo sync
    - Change php.ini `sudo vim /etc/php.ini`
```ini
memory_limit=1024M
```

```zsh
sudo service php-fpm restart
(cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/sync.sh > /mnt/hugo/github/sync.log 2>&1' &); tail -f /mnt/hugo/github/sync.log
```
- Set reminder to see if Database was backup in a week
- Set reminder to remove all volumes and the old instance in 2 week
- Remove all of the old manual snapshots for the old instance/volumes

* Create a backup from the instance (all volumes)
* https://ap-southeast-1.console.aws.amazon.com/ec2/home?region=ap-southeast-1#Snapshots:visibility=owned-by-me;v=3

- Add hints to `~/.zshrc`
```zsh
cp ~/.zshrc ~/.zshrc.bak.$(date +%s)
echo "echo \"(cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/sync.sh > /mnt/hugo/github/sync.log 2>&1' &); tail -f /mnt/hugo/github/sync.log\"" >> ~/.zshrc
source ~/.zshrc
```