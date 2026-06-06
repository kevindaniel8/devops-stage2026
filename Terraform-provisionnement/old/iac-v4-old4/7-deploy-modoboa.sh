#!/usr/bin/env bash

set -euo pipefail

#################################################
# VARIABLES
#################################################

POSTGRES_HOST="192.168.20.20"
POSTGRES_PORT="5432"

POSTGRES_ADMIN_USER="postgres"
POSTGRES_ADMIN_PASSWORD="CHANGE_ME"

MODOBOA_DB_NAME="modoboa"
MODOBOA_DB_USER="modoboa"
MODOBOA_DB_PASSWORD="StrongPassword"

ANSIBLE_PLAYBOOK="playbooks/modoboa.yml"

#################################################
# EXPORT PASSWORD
#################################################

export PGPASSWORD="${POSTGRES_ADMIN_PASSWORD}"

#################################################
# CREATE DATABASE
#################################################

echo "[+] Checking database..."

DB_EXISTS=$(psql \
  -h "${POSTGRES_HOST}" \
  -p "${POSTGRES_PORT}" \
  -U "${POSTGRES_ADMIN_USER}" \
  -tAc "SELECT 1 FROM pg_database WHERE datname='${MODOBOA_DB_NAME}'")

if [[ "${DB_EXISTS}" != "1" ]]; then

  echo "[+] Creating database..."

  psql \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${POSTGRES_ADMIN_USER}" \
    -c "CREATE DATABASE ${MODOBOA_DB_NAME};"

else
  echo "[+] Database already exists"
fi

#################################################
# CREATE USER
#################################################

echo "[+] Checking user..."

USER_EXISTS=$(psql \
  -h "${POSTGRES_HOST}" \
  -p "${POSTGRES_PORT}" \
  -U "${POSTGRES_ADMIN_USER}" \
  -tAc "SELECT 1 FROM pg_roles WHERE rolname='${MODOBOA_DB_USER}'")

if [[ "${USER_EXISTS}" != "1" ]]; then

  echo "[+] Creating user..."

  psql \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${POSTGRES_ADMIN_USER}" \
    -c "CREATE USER ${MODOBOA_DB_USER} WITH ENCRYPTED PASSWORD '${MODOBOA_DB_PASSWORD}';"

else
  echo "[+] User already exists"
fi

#################################################
# GRANTS
#################################################

echo "[+] Granting privileges..."

psql \
  -h "${POSTGRES_HOST}" \
  -p "${POSTGRES_PORT}" \
  -U "${POSTGRES_ADMIN_USER}" \
  -c "GRANT ALL PRIVILEGES ON DATABASE ${MODOBOA_DB_NAME} TO ${MODOBOA_DB_USER};"

#################################################
# RUN ANSIBLE
#################################################

echo "[+] Running Ansible playbook..."

ansible-playbook "${ANSIBLE_PLAYBOOK}"

echo "[+] Deployment finished"