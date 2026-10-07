#!/bin/bash
# Вызывается pam_exec при входе по SSH. PAM_USER — имя входящего пользователя.
HOLIDAYS_FILE=/etc/pam_holidays
TODAY=$(date +%F)     # 2026-10-10
DOW=$(date +%u)       # 1..7, где 6 = суббота, 7 = воскресенье

# Будний день — вход разрешён всем
if [ "$DOW" -lt 6 ]; then
    exit 0
fi

# Выходной, но праздничный — ограничение не действует
if [ -f "$HOLIDAYS_FILE" ] && awk '!/^#/ && NF {print $1}' "$HOLIDAYS_FILE" | grep -qx "$TODAY"; then
    exit 0
fi

# Выходной — пускаем только членов группы admin
if id -nG "$PAM_USER" 2>/dev/null | grep -qw admin; then
    exit 0
fi

exit 1
