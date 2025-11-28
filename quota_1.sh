#!/bin/bash

#Activation des quotas utilisateur sur /home...

# Modifier /etc/fstab
if ! grep -q "usrquota" /etc/fstab; then
   sed -i '/\/home/ s/\(defaults\)/\1,usrquota/' /etc/fstab
fi
#echo "1-----------------------------------------"

# Remount et creation de fichiers de quotas
mount -o remount /home
#echo "2---------------------------------------"

quotacheck -cumf /home
#echo "3--------------------------------"

quotaon /home
#echo "4--------------------------------"

#defini le temps de grace 7 jours
setquota -t 604800 604800  /home
#echo "5-------------------------------"

#Definition des limites espace
B_SOFT=1048576
B_HARD=2097152

#Application des quotas a tous les utilisateurs existants Soft 1G , Hard 2G

for u in $(awk -F: '$3>=1000{print $1}' /etc/passwd); do
      setquota -u "$u" $B_SOFT  $B_HARD 0 0 /home
done
#echo "6-------------------------------"

#Creation d'un Script Rapport de quotas
cat > /usr/local/sbin/check_quotas_home.sh << 'EOF'
#!/bin/bash

HOME_SYS="/home"

for u in $(ls $HOME_SYS); do
    MAIL="$u"

    DATA=$(quota -u $u | awk 'NR==3')

    BLK_USED=$(echo $DATA | awk '{print $2}')
    BLK_SOFT=$(echo $DATA | awk '{print $3}')
    BLK_HARD=$(echo $DATA | awk '{print $4}')

    if [[ "$BLK_SOFT" == "0" && "$BLK_HARD" == "0" ]]; then
        continue
    fi

    USED_GB=$(echo "scale=2; $BLK_USED/1024/1024" | bc)
    SOFT_GB=$(echo "scale=2; $BLK_SOFT/1024/1024" | bc)
    HARD_GB=$(echo "scale=2; $BLK_HARD/1024/1024" | bc)

    #PERCENT=$(echo "scale=2; 100*$BLK_USED/$BLK_SOFT" | bc)
    
    if [ "$BLK_SOFT" -ne 0 ]; then
      PERCENT=$(echo "scale=2; 100*$BLK_USED/$BLK_SOFT" | bc)
    else
      PERCENT=0
    fi

    MESSAGE="Bonjour $u,
Voici votre rapport d'utilisation du quota disque :

- Quota maximum (soft) : $SOFT_GB Go
- Limite absolue (hard) : $HARD_GB Go
- Utilisation actuelle : $USED_GB Go
- Pourcentage utilise : $PERCENT %

"

    if (( $(echo "$PERCENT > 90" | bc -l) )); then
        MESSAGE+="ATTENTION : Vous avez dépassé 90% de votre quota !Veuillez supprimer des fichiers inutiles."
    elif (( $(echo "$PERCENT > 75" | bc -l) )); then
        MESSAGE+="Vous avez dépassé 75% de votre quota. Faites attention."
    fi

    echo "$MESSAGE" | mail -s "Rapport quota – $u" "$MAIL"
done
EOF
#echo "7----------------------------------------------"

chmod +x /usr/local/sbin/check_quotas_home.sh
#echo "8---------------------"

#Automatisation du Check_quotas_home tout les 7 jours a 8h
( crontab -l 2>/dev/null; echo "0 8 */7 * * /usr/local/sbin/check_quotas_home.sh" ) | crontab -

