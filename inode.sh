#!/bin/bash

#Activation des quotas inode sur /data 

# Modifier /etc/fstab
if ! grep -q "usrquota,grpquota" /etc/fstab; then
   sed -i '/\/data/ s/\(defaults\)/\1,usrquota,grpquota/' /etc/fstab
fi

# Remount et creation de fichiers de quotas
mount -o remount /data
quotacheck -cum /data
quotaon /data

# Defini le temps de grace
# 7 jours en secondes pour soft et hard grace period
setquota -t 604800 604800 /data

#Definition des limites inodes 
INODE_SOFT=5000
INODE_HARD=10000

# Application des quotas inode a tous les utilisateurs existants
for u in $(awk -F: '$3 >=1000 {print $1}' /etc/passwd); do
    setquota -u "$u" 0 0 $INODE_SOFT $INODE_HARD /data
done

# Application des quotas inode a tous les groupes existants
for g in $(awk -F: '$3 >=1000 {print $1}' /etc/group); do
    setquota -g "$g" 0 0 $INODE_SOFT $INODE_HARD /data
done

#--------------------------------------------------------------------------------------------

#Creation d'un Script Rapport de quotas qui sera automatise
cat > /usr/local/sbin/check_quotas_data.sh << 'EOF'
#!/bin/bash

HOMEFS="/home"
INODE_WARN=75
INODE_ALERT=90

# Verification pour les utilisateurs
for u in $(awk -F: '$1 >=1000 {print $1}' /etc/passwd); do
    MAIL="$u"
    DATA=$(quota -u -i $u 2>/dev/null | awk 'NR==3')
    INODE_USED=$(echo $DATA | awk '{print $2}')
    INODE_SOFT=$(echo $DATA | awk '{print $3}')
    INODE_HARD=$(echo $DATA | awk '{print $4}')

    if [[ "$INODE_SOFT" == "0" && "$INODE_HARD" == "0" ]]; then
        continue
    fi

    PERCENT=$(echo "scale=2; 100*$INODE_USED/$INODE_SOFT" | bc)
    MESSAGE="Bonjour $u,
Voici votre rapport d'utilisation du quota inode :

- Quota maximum (soft) : $INODE_SOFT fichiers
- Limite absolue (hard) : $INODE_HARD fichiers
- Utilisation actuelle : $INODE_USED fichiers
- Pourcentage utilisé : $PERCENT %

"

    if (( $(echo "$PERCENT > $INODE_ALERT" | bc -l) )); then
        MESSAGE+="ATTENTION : Vous avez depasse 90% de votre quota inode ! Supprimez des fichiers inutiles."
    elif (( $(echo "$PERCENT > $INODE_WARN" | bc -l) )); then
        MESSAGE+="Vous avez depasse 75% de votre quota inode. Faites attention."
    fi

    echo "$MESSAGE" | mail -s "Rapport quota inode – $u" "$MAIL"
done

# Verification pour les groupes
for g in $(awk -F: '$1 >=1000 {print $1}' /etc/group); do
    MAIL="$g"
    DATA=$(quota -g -i $g 2>/dev/null | awk 'NR==3')
    INODE_USED=$(echo $DATA | awk '{print $2}')
    INODE_SOFT=$(echo $DATA | awk '{print $3}')
    INODE_HARD=$(echo $DATA | awk '{print $4}')

    if [[ "$INODE_SOFT" == "0" && "$INODE_HARD" == "0" ]]; then
        continue
    fi

    PERCENT=$(echo "scale=2; 100*$INODE_USED/$INODE_SOFT" | bc)
    MESSAGE="Bonjour $g,
Voici votre rapport d'utilisation du quota inode (groupe) :

- Quota maximum (soft) : $INODE_SOFT fichiers
- Limite absolue (hard) : $INODE_HARD fichiers
- Utilisation actuelle : $INODE_USED fichiers
- Pourcentage utilise : $PERCENT %

"

    if (( $(echo "$PERCENT > $INODE_ALERT" | bc -l) )); then
        MESSAGE+="ATTENTION : Le groupe a dépassé 90% de son quota inode !"
    elif (( $(echo "$PERCENT > $INODE_WARN" | bc -l) )); then
        MESSAGE+="Le groupe a depasse 75% de son quota inode. Faites attention."
    fi

    echo "$MESSAGE" | mail -s "Rapport quota inode – $g" "$MAIL"
done
EOF

chmod +x /usr/local/sbin/check_quotas_data.sh 2>/dev/null

#Automatisation du Check_quotas_home tout les 7 jours a 8h
( crontab -l 2>/dev/null; echo "0 8 */7 * * /usr/local/sbin/check_quotas_data.sh" ) | crontab -
