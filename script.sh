xlsx2csv accounts.xlsx > accounts.csv

mkdir "/home/shared"
chown root "/home/shared"
chmod +rx "/home/shared"

echo "Entrez le port :"
read port

echo "Entrez mail :"
read mail_smtp

echo "Serveur smtp"
read smtp_serveur

echo "Entrez le mot de passe :"
read password_smtp

ssh -i /home/id_rsa troyer25@10.30.48.100 mkdir -p saves

#nextcould
#
touch /home/tunnel_ssh
chmod +x /home/tunnel_ssh

echo '#!/bin/bash' > /home/tunnel_ssh
echo 'ssh /home/id_rsa troyer25@10.30.48.100 -N -L 4242:localhost:80' >> /home/tunnel_ssh

ssh /home/id_rsa troyer25@10.30.48.100 apt install snapd -y
ssh /home/id_rsa troyer25@10.30.48.100 snap install nextcloud
ssh /home/id_rsa troyer25@10.30.48.100 nextcloud.manual-install "nextcloud-admin" "N3x+_Cl0uD"


#eclipte
wget -P /home/ https://download.eclipse.org/technology/epp/downloads/release/2021-09/R/eclipse-java-2021-09-R-linux-gtk-x86_64.tar.gz
tar -zxf /home/eclipse-java-2021-09-R-linux-gtk-x86_64.tar.gz
rm /home/eclipse-java-2021-09-R-linux-gtk-x86_64.tar.gz

tail -n +2 accounts.csv | while IFS=',' read col1 col2 col3 col4
do
    # Récupérer la première lettre du prenom
    premiere_lettre=$(echo "$col2" | cut -c 1)
    premiere_lettre_maj=$(echo "$premiere_lettre" | tr '[:lower:]' '[:upper:]')

    #  Récupérer le nom de famille
    col1_min=$(echo "$col1"| tr '[:upper:]' '[:lower:]')
    
    #enregistrer l'identifiant et le mdp
    id="$premiere_lettre_maj$col1_min"
    password=$(echo "$col4")
    
    # Vérifier si le dernier caractère est un espace
    if [ "${password: -1}" = " " ]; then
        # Supprimer le dernier caractère
        password="${password%?}"
    fi
    
    #Create the user
    useradd -m -p "$(openssl passwd -1 "$password")" "$id"
    chage -d 0 "$id"

    mkdir "/home/$id/a_sauver"
    mkdir "/home/shared/$id"
    chown "$id" "/home/$id/a_sauver"
    chown "$id" "/home/shared/$id"
    
    chmod +rx "/home/shared/$id"
    chmod u+w "/home/shared/$id"

    #lien symbolique entre eclipte et les users
    ln -s /home/eclipse /home/$id

    #send mail
    mail_smtp=$(echo $mail_smtp | sed 's/@/%40/g')
    password_smtp=$(echo $password_smtp | sed 's/@/%40/g')
    ssh -i /home/id_rsa troyer25@10.30.48.100 "mail --subject \"Création de votre session\" --exec \"set sendmail=smtp://$mail_smtp:$password_smtp@$smtp_server:$port\" --append \"From:<$mail_smtp>\" $col4 <<< \"Votre compte à bien été créer! Votre compte :\"identifiant : $id | password:$password"

    #Creation clée ssh pour chaque user
    mkdir "/home/$id/.ssh"
    chmod 700 "/home/$id/.ssh"
    ssh-keygen -t ed25519 -f "/home/$id/.ssh/id_ed25519" -q -N "" -C "$id@$(hostname)"
    chown -R "$id:$id" "/home/$id/.ssh"

    #Ajout de la clé publique dans le répertoire authorized_keys
    ssh-copy-id -i "/home/$id/.ssh/id_ed25519.pub" troyer25@10.30.48.100

    #create user nextcloud
    ssh -i /home/id_rsa troyer25@10.30.48.100 "nextcloud.occ" user:add --password-from-env "$id"
    ssh -i /home/id_rsa troyer25@10.30.48.100 "nextcloud.occ" user:setting "$id" password "$password"

done


#creer le fichier de sauvegarde
touch backup_file

echo '#!/bin/bash' > backup_file
echo 'folders=$(ls /home/shared)' >> backup_file
echo "# Parcourir la liste et afficher le nom de chaque dossier" >> backup_file
echo 'for folder in $folders; do' >> backup_file
echo '     tar -czf "/home/$(basename $folder)/save_$(basename $folder).tgz"  --directory="/home/$(basename $folder)/a_sauver" .'>> backup_file
echo '     ssh -i ~/.ssh/id_rsa troyer25@10.30.48.100 rm ~/saves/save_$(basename $folder).tgz' >> backup_file
echo '     scp -i /home/id_rsa /home/$(basename $folder)/save_$(basename $folder).tgz troyer25@10.30.48.100:saves/' >> backup_file
echo '     rm /home/$(basename $folder)/save_$(basename $folder).tgz '>> backup_file
echo 'done'>> backup_file



#Save
nouvelle_tache='0 23 * * 1-5 backup_file'
# Créer une tâche à ajouter à crontab
crontab -l > tmp
echo "$nouvelle_tache" >> tmp
crontab tmp
rm tmp


# retablir_sauvegarde
touch  "/home/retablir_sauvegarde"
chmod +rx /home/retablir_sauvegarde

echo '#!/bin/bash' > /home/retablir_sauvegarde
echo 'name=$(whoami)' >> /home/retablir_sauvegarde
echo 'scp -i /home/id_rsa troyer25@10.30.48.100:saves/save_$name.tgz /home/$name/a_sauver' >> /home/retablir_sauvegarde
echo 'tar -m -xf /home/$name/a_sauver/save_$name.tgz -C /home/$name/a_sauver/' >> /home/retablir_sauvegarde
echo 'rm /home/$name/save_$name.tgz' >> /home/retablir_sauvegarde

#Pare-feu
#FTP
iptables -A INPUT -p tcp -j DROP
#UDP
iptables -A INPUT -p udp -j DROP


#Monitoring

#sudo apt-get install sysstat

ssh -i /home/id_rsa troyer25@10.30.48.100 touch monitoring
ssh -i /home/id_rsa troyer25@10.30.48.100 mkdir save_monitoring
ssh -i /home/id_rsa troyer25@10.30.48.100 echo '#!/bin/bash'>monitoring
ssh -i /home/id_rsa troyer25@10.30.48.100 echo 'timestamp=$(date +"%Y-%m-%d_%H-%M-%S")'>>monitoring
ssh -i /home/id_rsa troyer25@10.30.48.100 echo 'touch /save_monitoring/$timestamp'>>monitoring
ssh -i /home/id_rsa troyer25@10.30.48.100 echo 'sar -n DEV 1 1 > /save_monitoring/$timestamp'>>monitoring
ssh -i /home/id_rsa troyer25@10.30.48.100 echo 'mpstat -P ALL >> /save_monitoring/$timestamp'>>monitoring
ssh -i /home/id_rsa troyer25@10.30.48.100 echo 'sar -r >> /save_monitoring/$timestamp'>>monitoring

# Créer une tâche à ajouter à crontab
ssh -i /home/id_rsa troyer25@10.30.48.100 crontab -l > tmp
ssh -i /home/id_rsa troyer25@10.30.48.100 echo "* * * * 1-5 monitoring" >> tmp
ssh -i /home/id_rsa troyer25@10.30.48.100 crontab tmp
ssh -i /home/id_rsa troyer25@10.30.48.100 rm tmp

exit
