{%- from "apache/map.jinja" import server with context %}
{%- if server.enabled %}

{%- if server.site is defined %}
{%- set ssl_certificates = {} %}

{%- for site_name, site in server.site.iteritems() %}

{% if site.enabled %}

{{ server.vhost_dir }}/{{ site.type }}_{{ site.name }}{{ server.conf_ext }}:
  file.managed:
  {%- if site.type in ['proxy', 'redirect', 'static', 'stats'] %}
  - source: salt://apache/files/{{ site.type }}.conf
  {%- else %}
  - source: salt://{{ site.type }}/files/apache.conf
  {%- endif %}
  - template: jinja
  - defaults:
    site_name: "{{ site_name }}"
  - require:
    - pkg: apache_packages
  {% if not grains.get('noservices', False) %}
  - watch_in:
    - service: apache_service
  {% endif %}

{%- if site.get('webdav', {}).get('enabled', False) %}
{{ site.name }}_webdav_dir:
  file.directory:
  - name: {{ site.root }}
  - user: {{ server.service_user }}
  - group: {{ server.service_group }}
  - makedirs: true
{%- endif %}

{%- for location in site.get('locations', []) %}
{%- if location.get('webdav', {}).get('enabled', False) %}
{{ site.name }}_webdav_{{ location.uri }}_dir:
  file.directory:
  - name: {{ location.path }}
  - user: {{ server.service_user }}
  - group: {{ server.service_group }}
  - makedirs: true
{%- endif %}
{%- if location.get('auth', {}).get('cert', {}).allowed_cert_dns is defined %}
{{ site.name }}_{{ location.uri }}_allowed_cert_dns:
  file.managed:
  - name: {{ server.htpasswd_dir }}/{{ location.auth.htpasswd }}
  - source: salt://apache/files/allowed_cert_dns
  - template: jinja
  - user: root
  - group: root
  - mode: 644
  - defaults:
      allowed_cert_dns: {{ location.auth.cert.allowed_cert_dns }}
{%- endif %}
{%- endfor %}

{%- if site.get('auth', {}).get('cert', {}).allowed_cert_dns is defined %}
{{ site.name }}_allowed_cert_dns:
  file.managed:
  - name: {{ server.htpasswd_dir }}/{{ site.auth.htpasswd }}
  - source: salt://apache/files/allowed_cert_dns
  - template: jinja
  - user: root
  - group: root
  - mode: 644
  - defaults:
      allowed_cert_dns: {{ site.auth.cert.allowed_cert_dns }}
{%- endif %}

{%- if site.get('ssl', {'enabled': False}).enabled and site.ssl.get('install_cert', true) and site.host.name not in ssl_certificates.keys() %}
{%- set _dummy = ssl_certificates.update({site.host.name: []}) %}

/etc/ssl/certs/{{ site.host.name }}.crt:
  file.managed:
  {%- if site.ssl.cert is defined %}
  - contents_pillar: apache:server:site:{{ site_name }}:ssl:cert
  {%- else %}
  - source: salt://pki/{{ site.ssl.authority }}/certs/{{ site.host.name }}.cert.pem
  {%- endif %}
  - require:
    - pkg: apache_packages

/etc/ssl/private/{{ site.host.name }}.key:
  file.managed:
  {%- if site.ssl.key is defined %}
  - contents_pillar: apache:server:site:{{ site_name }}:ssl:key
  {%- else %}
  - source: salt://pki/{{ site.ssl.authority }}/certs/{{ site.host.name }}.key.pem
  {%- endif %}
  - require:
    - pkg: apache_packages

/etc/ssl/certs/{{ site.host.name }}-ca-chain.crt:
  file.managed:
  {%- if site.ssl.chain is defined %}
  - contents_pillar: apache:server:site:{{ site_name }}:ssl:chain
  {%- else %}
  - source: salt://pki/{{ site.ssl.authority }}/{{ site.ssl.authority }}-chain.cert.pem
  {%- endif %}
  - require:
    - pkg: apache_packages

{%- endif %}

{%- if grains.os_family == "Debian" %}

/etc/apache2/sites-enabled/{{ site.type }}_{{ site.name }}{{ server.conf_ext }}:
  file.symlink:
  - target: {{ server.vhost_dir }}/{{ site.type }}_{{ site.name }}{{ server.conf_ext }}
  - require:
    - file: {{ server.vhost_dir }}/{{ site.type }}_{{ site.name }}{{ server.conf_ext }}
  {% if not grains.get('noservices', False) %}
  - watch_in:
    - service: apache_service
  {% endif %}

/etc/apache2/sites-enabled/{{ site.type }}_{{ site.name }}:
  file.absent

{%- endif %}

{%- if site.type == "static" %}

{%- if site.source is defined %}

{{ site.name }}_dir:
  file.directory:
  - name: /srv/static/sites/{{ site.name }}
  - makedirs: true

{%- if site.source.engine == 'git' %}

{{ site.source.address }}:
  git.latest:
  - target: /srv/static/sites/{{ site.name }}
  - rev: {{ site.source.revision }}
  - require:
    - file: {{ site.name }}_dir

{%- endif %}

{%- endif %}

{%- endif %}

{%- else %}

{{ server.vhost_dir }}/{{ site.type }}_{{ site.name }}{{ server.conf_ext }}:
  file.absent

{%- if grains.os_family == "Debian" %}

/etc/apache2/sites-enabled/{{ site.type }}_{{ site.name }}{{ server.conf_ext }}:
  file.absent

{%- endif %}

{%- endif %}

{%- endfor %}
{%- endif %}

{%- endif %}
