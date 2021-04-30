#!/bin/bash
# setup-ansible-user
# create ansible user for Ansible/ansible/kubespray automation
# and configuration management

########## create ansible user ##########
echo "Create user myansible..."
getentUser=$(/usr/bin/getent passwd myansible)
if [ -z "$getentUser" ]
then
  echo "User ansible does not exist.  Will Add..."
  /usr/sbin/groupadd -g 2002 myansible
  /usr/sbin/useradd -u 2002 -g 2002 -c "Ansible Automation Account" -s /bin/bash -d /home/myansible myansible

echo "myansible:fdgSDKSMD3dsamfckdc" | /usr/sbin/chpasswd

mkdir -p /home/myansible/.ssh
fi

########## add user to sudo group ##########
echo "Configure sudo permissions..."
if [ ! -s /etc/sudoers.d/myansible ]
then
echo "User myansible sudoers does not exist.  Will Add..."
touch /etc/sudoers.d/myansible
cat << 'EOF' > /etc/sudoers.d/myansible
%myansible ALL=(ALL)      NOPASSWD: ALL
EOF
chmod 400 /etc/sudoers.d/myansible
fi

########## import ssh key ##########
echo "Set passwordless SSH Key for user myansible"
cat << 'EOF' >> /home/myansible/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAgCkAeTK0fu1SWlBbEhCYuAUeZ7+qIKY1yc6CJ+hHTq3UZszyvgeOfKHVYq4JPGevVWMETrJtkFHUAAGE3yRtjqKMM/hDugJeemGAL9KPgSS3kNVjblqpylVguMTqjR+HphDZYVZkpgw3lBn/pq4l6S59SBkvIvn7wjCq60x86uLraTd+SYRI1mjcYXg8HKTwKAuJzQRAcuBKlOQcBflbYWFi2DlHQ8LFAbIWez+dZGIK3ommFvFS+S++bOqt50DtsppfyEL6itOA2jpL6yrD1k7FWKvefxB8y1+RFWra1GYOvDfm2uwyd6zB9JjfO5J6K/a7VUkxu+HyvrpHfcU9ck8VHraNaD6pRDmHRrwaRHycziq8vKXkrV+CYJ8OD6FsLylJACqU6AbwssKWoeKIDMmGgxGou0/imY4RqKMReoi6TllZ8HF9oFgiNKTHg/HaFcrG3sz6C0K7GDhUjNBr0qo2GnBxr++ddmjX3t4k7ffrt99IS5MwHor6l0D+u2g1+bQEuR96OKL+bMIG5GyQ== myansible
EOF
chown -R myansible:myansible /home/myansible/.ssh
chmod 700 /home/myansible/.ssh

########## modify ssh config ##########
echo "Configure SSH daemon..."
# disable login for ansible except through
# ssh keys
cat << 'EOF' >> /etc/ssh/sshd_config
Match User myansible
        PasswordAuthentication no
        AuthenticationMethods publickey
EOF

########## restart sshd ##########
echo "Restarting SSH daemon..."
systemctl restart sshd

echo "Pre-Setup finished!"