# -*- coding: utf-8 -*-
# vim: set syntax=yaml ts=2 sw=2 sts=2 et :

include:
  - fpf-apt-test-repo

{% if "template" in grains['id'] or grains['id'] in ["securedrop-workstation-buster", "whonix-gw-15"] %}
# Install securedrop-log package in TemplateVMs only
install-securedrop-log-package:
  pkg.installed:
    - pkgs:
      - securedrop-log
    - require:
      - sls: fpf-apt-test-repo
{% endif %}

{% if grains['id'] == "sd-log-buster-template" %}
install-redis-for-sd-log-template:
  pkg.installed:
    - pkgs:
      - redis-server
      - redis
remove-sd-rsyslog-config-for-logserver:
  file.absent:
    - name: /etc/rsyslog.d/sdlog.conf

{% elif grains['id'] == "sd-log" %}
# Only for the "sd-log" AppVM, configure /rw/config to disable
# custom log config, and also start the necessary services.
sd-log-remove-rsyslog-qubes-plugin:
  file.blockreplace:
    - name: /rw/config/rc.local
    - append_if_not_found: True
    - marker_start: "### BEGIN securedrop-workstation ###"
    - marker_end: "### END securedrop-workstation ###"
    - content: |
        # Removes sdlog.conf file for rsyslog
        rm -f /etc/rsyslog.d/sdlog.conf
        systemctl restart rsyslog
        systemctl start redis
        systemctl start securedrop-log
  cmd.run:
    - name: /rw/config/rc.local
    - require:
      - file: sd-log-remove-rsyslog-qubes-plugin

{% elif grains['id'] == "sd-whonix" %}
# We can not place the file on the template under /etc/rsyslog.d/ because of whonix
# template. This sdlog.conf file is the same from the securedrop-log package, to
# make sure that rsyslogd use our logging plugin.
sd-rsyslog-sdlog-conf-for-sd-whonix:
  file.managed:
    - name: /rw/config/sdlog.conf
    - source: "salt://sdlog.conf"

# Because whonix-gw-15 template is not allowing to create the config file on
# package install time, we do it via rc.local call.
sd-rc-enable-logging:
  file.blockreplace:
    - name: /rw/config/rc.local
    - append_if_not_found: True
    - marker_start: "### BEGIN securedrop-workstation ###"
    - marker_end: "### END securedrop-workstation ###"
    - content: |
        # Add sd-rsyslog.conf file for syslog
        ln -sf /rw/config/sd-rsyslog.conf /etc/sd-rsyslog.conf
        if [ ! -f /etc/rsyslog.d/sdlog.conf ]; then
            ln -sf /rw/config/sdlog.conf /etc/rsyslog.d/sdlog.conf
        fi
        systemctl restart rsyslog
  cmd.run:
    - name: ln -sf /rw/config/sd-rsyslog.conf /etc/sd-rsyslog.conf && systemctl restart rsyslog

{% else %}
# For all other VMs, configure to send to sd-log
configure-rsyslog-for-sd:
  file.managed:
    - name: /etc/sd-rsyslog.conf
    - source: "salt://sd-rsyslog.conf.j2"
{% endif %}
