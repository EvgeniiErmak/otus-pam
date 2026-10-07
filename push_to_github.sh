#!/usr/bin/env bash
# Создаёт публичный репозиторий на GitHub через API и пушит в него текущий каталог.
# Токен: Personal access token (classic) со scope "repo" (или "public_repo").
set -euo pipefail

GH_USER="EvgeniiErmak"
GH_EMAIL="djermak3000@mail.ru"
REPO="otus-pam"
DESC="OTUS Linux Professional: PAM — запрет входа в выходные, доступ к Docker"

cd "$(dirname "$(readlink -f "$0")")"

if [ -z "${GH_TOKEN:-}" ]; then
  read -rsp "Personal access token (classic): " GH_TOKEN; echo
fi

echo ">>> Создаю репозиторий ${GH_USER}/${REPO}"
code=$(curl -s -o /tmp/gh_resp.json -w '%{http_code}' -X POST \
  -H "Authorization: token ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"${REPO}\",\"description\":\"${DESC}\",\"private\":false}")
case "$code" in
  201) echo "    Репозиторий создан" ;;
  422) echo "    Репозиторий уже существует — продолжаю" ;;
  *)   echo "    Ошибка API (HTTP $code):"; cat /tmp/gh_resp.json; exit 1 ;;
esac

[ -d .git ] || git init
git config user.name  "${GH_USER}"
git config user.email "${GH_EMAIL}"
git branch -M main 2>/dev/null || git checkout -b main

git add -A
git commit -m "PAM: запрет входа в выходные + доступ к Docker (Vagrant + Ansible)" || echo "    Нет изменений для коммита"

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${GH_USER}/${REPO}.git"

echo ">>> Пушу в GitHub"
git push "https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${REPO}.git" main
git fetch origin && git branch -u origin/main main

echo ">>> Готово: https://github.com/${GH_USER}/${REPO}"
