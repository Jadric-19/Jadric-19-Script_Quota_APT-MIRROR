#!/bin/bash

REP="/var/www/html/depot"
PAG="/var/www/html/depot/Paquet.html"


#On a copie certains .deb das REP pour l'exercice et au lieu de les telecharges depuis une source officielle ,
#on fait une download local depuis un site local generer par le Script

touch $PAG

echo -e "<!DOCTYPE html> \n" > $PAG
echo -e "<html> \n<head><meta charset=\"UTF-8\"><title>Paquet Download</title></head> \n <body>\n" >> $PAG
echo -e "<br/><h1>Les Paquet disponnible Actuellement : </h1><br/>" >> $PAG

#Extraction des fichier .deb seulement
for fichier in $REP/*.deb ; do
  name=$(basename $fichier)
  echo -e "<a href=\"$name\" title=\"Download\" download> Download  :  $name </a><br>" >> $PAG
done

echo -e "</body></html>" >> $PAG

#Fonction de configuration de /etc/apache2/sites-available/Paquet.conf
configuration()
{

echo -e "<VirtualHost *:80>\n
    ServerAdmin webmaster@localhost\n
    ServerName Paquet.com\n
    DocumentRoot /var/www/html/depot\n

    <Directory \"/var/www/html/depot\">\n
        Options +Indexes +FollowSymLinks\n
        AllowOverride None\n
        Require all granted\n
    </Directory>\n
    ErrorLog ${APACHE_LOG_DIR}/post_1_error.log\n
    CustomLog ${APACHE_LOG_DIR}/post_1_access.log combined\n
   </VirtualHost>\n"
}

#Configuration de /etc/hosts
if ! grep -q "Paquet.com" /etc/hosts; then
    echo "127.0.0.1 Paquet.com" >> /etc/hosts
fi
 
#Configuration de /etc/apache2/sites-available/Paquet.conf 
configuration > "/etc/apache2/sites-available/Paquet.conf"

#Mise en site et relance de apache
a2ensite Paquet.conf
systemctl reload apache2
systemctl enable apache2

