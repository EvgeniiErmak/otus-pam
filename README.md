# Vagrant-стенд с PAM

Домашнее задание курса OTUS «Администратор Linux. Professional».

## Структура репозитория

| Путь | Описание |
|---|---|
| [Vagrantfile](Vagrantfile) | Разворачивает ВМ `pam` (ubuntu/jammy64, 192.168.57.10) |
| [ansible/](ansible/) | Ansible-провижининг |
| [ansible/playbook.yml](ansible/playbook.yml) | Плейбук: пользователи, группа admin, PAM, Docker, polkit |
| [ansible/files/](ansible/files/) | Скрипт `login.sh`, список праздников, правило polkit |
| [screenshots/](screenshots/) | Скриншоты выполнения |
| [push_to_github.sh](push_to_github.sh) | Скрипт создания и пуша репозитория |

## Текст задания

1. Ограничить доступ к системе для всех пользователей, кроме группы администраторов, в выходные дни (суббота и воскресенье), за исключением праздничных дней.
2. ⭐ Предоставить определённому пользователю доступ к Docker и право перезапускать Docker-сервис.

## Окружение

- Хост: Ubuntu 26.04.1 LTS, ядро 7.0, VirtualBox 7.2.6, Vagrant 2.4.9, ansible-core 2.20.1
- ВМ: `ubuntu/jammy64` v20241002.0.0 (Ubuntu 22.04.5), 2 CPU, 1 GB RAM, IP 192.168.57.10

## Подготовка хоста

VirtualBox не может работать одновременно с загруженным KVM (AMD-V занят), поэтому KVM на хосте отключён:

~~~
# cat /etc/modprobe.d/blacklist-kvm.conf
blacklist kvm_amd
blacklist kvm
install kvm_amd /bin/false
install kvm /bin/false
~~~

## Развёртывание

~~~bash
git clone https://github.com/EvgeniiErmak/otus-pam.git
cd otus-pam
vagrant up
~~~

Провижининг: shell (разрешает вход по паролю), затем Ansible — [playbook.yml](ansible/playbook.yml).

~~~
PLAY RECAP *****************************************************************
pam    : ok=13   changed=10   unreachable=0    failed=0    skipped=1
~~~

## Задание 1. Запрет входа в выходные (PAM)

### Что делает Ansible

1. Создаёт пользователей `otus` и `otusadm` с паролем `Otus2022!`.
2. Создаёт группу `admin`, добавляет в неё `otusadm`, `root`, `vagrant`.
3. Кладёт скрипт [login.sh](ansible/files/login.sh) в `/usr/local/bin/login.sh`.
4. Кладёт список праздников [pam_holidays](ansible/files/pam_holidays) в `/etc/pam_holidays`.
5. Добавляет в `/etc/pam.d/sshd` модуль `pam_exec` со скриптом.

### Логика скрипта

| День | Группа admin | Остальные |
|---|---|---|
| Пн–Пт | вход разрешён | вход разрешён |
| Сб–Вс | вход разрешён | **вход запрещён** |
| Сб–Вс, праздник из `/etc/pam_holidays` | вход разрешён | вход разрешён |

### Проверка конфигурации

~~~
root@pam:~# getent group admin
admin:x:117:otusadm,root,vagrant
root@pam:~# id otus; id otusadm
uid=1002(otus) gid=1002(otus) groups=1002(otus),120(docker)
uid=1003(otusadm) gid=1003(otusadm) groups=1003(otusadm),117(admin)
root@pam:~# grep -n -B1 -A1 pam_exec /etc/pam.d/sshd
14-@include common-account
15:account    required     pam_exec.so debug /usr/local/bin/login.sh
root@pam:~# sshd -T | grep -E '^(passwordauthentication|usepam)'
usepam yes
passwordauthentication yes
~~~

### Будний день (среда 07.10.2026) — otus входит

~~~
otus@pam:~$ hostname; whoami; date; date +%u
pam
otus
Wed Oct  7 14:44:42 UTC 2026
3
~~~

### Суббота 10.10.2026 — otus запрещён, otusadm разрешён

Меняем дату в ВМ (предварительно отключаем синхронизацию времени):

~~~bash
timedatectl set-ntp false
systemctl stop vboxadd-service
date -s "2026-10-10 12:00:00"
~~~

~~~
root@otus-master:~# ssh otus@192.168.57.10
otus@192.168.57.10's password:
/usr/local/bin/login.sh failed: exit code 1
Connection closed by 192.168.57.10 port 22
~~~

~~~
otusadm@pam:~$ hostname; whoami; id; date
pam
otusadm
uid=1003(otusadm) gid=1003(otusadm) groups=1003(otusadm),117(admin)
Sat Oct 10 12:02:39 UTC 2026
~~~

Лог PAM:

~~~
root@pam:~# grep pam_exec /var/log/auth.log | tail
Oct 10 12:01:08 ... sshd[4131]: pam_exec(sshd:account): /usr/local/bin/login.sh failed: exit code 1
~~~

### Суббота 09.05.2026 (праздник) — otus входит

~~~bash
date -s "2026-05-09 12:00:00"
~~~

~~~
otus@pam:~$ hostname; whoami; date; date +%u
pam
otus
Sat May  9 12:01:08 UTC 2026
6
~~~

Возврат времени:

~~~bash
timedatectl set-ntp true
systemctl start vboxadd-service
~~~

## Задание 2⭐. Доступ к Docker для пользователя otus

1. `otus` добавлен в группу `docker` — работает с Docker без sudo.
2. Право перезапуска сервиса выдано через polkit: [10-docker-restart.pkla](ansible/files/10-docker-restart.pkla).

### otus — доступ есть

~~~
uid=1002(otus) gid=1002(otus) groups=1002(otus),120(docker)
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
Server Version: 29.1.3
ActiveEnterTimestamp=Wed 2026-10-07 14:36:55 UTC
RESTART OK
ActiveEnterTimestamp=Wed 2026-10-07 15:09:09 UTC
active
~~~

### otusadm — доступа нет

~~~
uid=1003(otusadm) gid=1003(otusadm) groups=1003(otusadm),117(admin)
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
Failed to restart docker.service: Interactive authentication required.
~~~

## Особенности реализации и заметки

- **pam_exec вместо pam_time** — `pam_time` не работает с локальными группами, поэтому используется скрипт (как в методичке).
- **Тип account, а не auth** — проверка срабатывает при любом способе входа (пароль и SSH-ключ); по смыслу это авторизация.
- **Членство в группе** проверяется через `id -nG` — без ложных совпадений по подстроке.
- **Праздники** — «за исключением праздничных дней» реализовано буквально: если выходной совпадает с праздником из `/etc/pam_holidays`, ограничение снимается.
- **Ubuntu вместо CentOS:** `passwd --stdin` заменён на `chpasswd`; `PasswordAuthentication` правится также в `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`.
- **Группа admin в Ubuntu** — в `/etc/sudoers` есть строка `%admin ALL=(ALL) ALL`, поэтому члены группы `admin` получают sudo (в CentOS из методички такого нет).
- **Polkit 0.105** в Ubuntu 22.04 не поддерживает JS-правила (`/etc/polkit-1/rules.d/`), поэтому правило со слайда записано в формате `.pkla`. Ограничение формата: право выдаётся на `manage-units` целиком, без фильтра по `docker.service`.
- **Тест с подменой даты** требует остановить `systemd-timesyncd` и `vboxadd-service`, иначе время вернётся.
- **Терминал kitty** — в ВМ неизвестен тип `xterm-kitty`, нужно `export TERM=xterm-256color`.

