#!/bin/bash


curl -k -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt
update-ca-trust
rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm

subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}

dnf install httpd nano python3-pip java-21-openjdk.x86_64 ansible-core wget -y
pip install ansible-rulebook
pip install aiokafka

ansible-galaxy collection install ansible.eda
wget https://dlcdn.apache.org/kafka/3.9.1/kafka_2.12-3.9.1.tgz -O /tmp/kafka_2.12-3.9.1.tgz
echo "Creating /tmp/kafka directory..."
mkdir -p /tmp/kafka
tar -xzf /tmp/kafka_2.12-3.9.1.tgz -C /tmp/kafka --strip-components=1
sudo cp /tmp/kafka/bin/* /usr/local/bin/
sudo chmod +x /usr/local/bin/kafka-*
sudo chmod +x /usr/local/bin/connect-*
sudo chmod +x /usr/local/bin/trogdor.sh

tee /home/rhel/kafka-example.yml << EOF
---
- name: Read messages from a kafka topic and act on them
  hosts: all
  ## Define our source for events
  sources:   
    - ansible.eda.kafka:
        host: broker
        port: 9092
        topic: eda-topic
        group_id:

  ## Define the conditions we are looking for
  rules:
    - name: Say Hello
      condition: event.message == "Ansible is cool"
      ## Define the action we should take should the condition be met
      action:
        run_playbook:
          name: say-what.yml

EOF

tee /home/rhel/hello-events.yml << EOF
---
- name: Hello Events
  hosts: all
  ## Define our source for events
  sources:
    - benthomasson.eda.range:
        limit: 5
  ## Define the conditions we are looking for
  rules:
    - name: Say Hello
      condition: event.i == 1
      ## Define the action we should take should the condition be met
      action:
        run_playbook:
          name: benthomasson.eda.hello

EOF

tee /home/rhel/say-what.yml << EOF
---
- name: say thanks
  hosts: localhost
  gather_facts: false
  tasks:
    - debug:
        msg: "Thank you, {{ ansible_eda.event.sender | default('my friend') }}!"
EOF

tee /home/rhel/webhook-example.yml << EOF
---
- name: Listen for events on a webhook
  hosts: all
  ## Define our source for events
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000
  ## Define the conditions we are looking for
  rules:
    - name: Say Hello
      condition: event.payload.message == "Ansible is super cool"
  ## Define the action we should take should the condition be met
      action:
        run_playbook:
          name: say-what.yml
EOF

tee /home/rhel/inventory.yml << EOF
localhost

EOF

tee /home/rhel/wowza.yml << EOF
---
- name: Site is up
  hosts: all
  gather_facts: false
  tasks:
    - debug:
        msg: "All is up and well"

EOF

tee /home/rhel/url-check-example.yml << EOF
---
- name: Listen for events on a webhook
  hosts: web
  ## Define our source for events
  sources:
     - ansible.eda.url_check:
        urls:
          - http://webserver
        delay: 10

  rules:
    ## Define the conditions we are looking for 
    - name: Web site is up
      condition: event.url_check.status == "up"
    ## Define the action we should take should the condition be met  
      action:
        run_playbook:
          name: wowza.yml

    - name: Web site is down
      condition: event.url_check.status == "down"
    ## Define the action we should take should the condition be met  
      action:
        run_playbook:
          name: fix_web.yml

EOF

tee /home/rhel/fix_web.yml << EOF
---
- name: Site Down
  hosts: all
  gather_facts: false
  become: true
  
  tasks:
    - debug:
        msg: "Website is down!"

    - name: Replace website
      copy:
       remote_src: yes
       src: /tmp/index.html
       dest: /var/www/html/
       owner: apache
       group: apache
       mode: '0644'

EOF

tee /home/rhel/inventory_web.yml << EOF
all:
  hosts:
    localhost:
      ansible_connection: local
web:
  hosts:
    webserver:
      ansible_user: rhel
      ansible_password: ansible123!
EOF
#

pip install aiohttp

cat <<EOF | tee /var/www/html/index.html


<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nothing to See Here</title>
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            font-family: Arial, sans-serif;
            background-color: #f4f4f9;
            color: #333;
        }
        h1 {
            font-size: 3em;
            text-align: center;
        }
    </style>
</head>
<body>
    <h1>Nothing to See Here - Not Yet Anyway - Node03</h1>
</body>
</html>

EOF

systemctl start httpd

mkdir /backup
chmod -R 777 /backup
