#!/bin/bash
# ============================================================
# 10_configure_tftp.sh — Serveur TFTP + Sauvegardes automatiques Cisco
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# Cible   : srv-linux (192.168.50.20)
#
# Ce script :
#   1. Installe et configure tftpd-hpa (serveur TFTP)
#   2. Configure les droits et le répertoire de dépôt
#   3. Crée le script de sauvegarde TFTP des équipements Cisco
#   4. Programme les sauvegardes automatiques via cron
#   5. Crée un script de restauration en cas de besoin
#
# ÉQUIPEMENTS SAUVEGARDÉS :
#   - SW2-IRIS  : 192.168.50.2 (Catalyst 2960-X)
#   - AP2-IRIS  : 192.168.50.5 (Catalyst 9120AX)
#   - RT2-IRIS  : 192.168.50.1 (Cisco ISR — si présent)
#
# Sauvegarde toutes les nuits à 02h00
# Rotation : 30 jours de rétention
# ============================================================

set -euo pipefail

TFTP_ROOT="/srv/tftp"
BACKUP_DIR="${TFTP_ROOT}/cisco-backups"
LOG_FILE="/var/log/tftp-backup.log"
BACKUP_SCRIPT="/usr/local/bin/cisco-tftp-backup.sh"
RESTORE_SCRIPT="/usr/local/bin/cisco-tftp-restore.sh"

TFTP_SERVER_IP="192.168.50.20"   # IP de srv-linux

# Équipements à sauvegarder
SW2_IP="192.168.50.2"
AP2_IP="192.168.50.5"
RT2_IP="192.168.50.1"
DC_IP="192.168.50.10"

# ══════════════════════════════════════════════════════════════
# 1. Installation tftpd-hpa
# ══════════════════════════════════════════════════════════════
echo "[STEP] Installation de tftpd-hpa..."
apt-get update -qq
apt-get install -y tftpd-hpa tftp-hpa snmp 2>&1

# ══════════════════════════════════════════════════════════════
# 2. Configuration du serveur TFTP
# ══════════════════════════════════════════════════════════════
echo "[STEP] Configuration tftpd-hpa..."

mkdir -p "${BACKUP_DIR}/SW2-IRIS"
mkdir -p "${BACKUP_DIR}/AP2-IRIS"
mkdir -p "${BACKUP_DIR}/RT2-IRIS"
mkdir -p "${BACKUP_DIR}/archives"

# Droits : tftp doit pouvoir écrire (--create)
chown -R tftp:tftp "${TFTP_ROOT}"
chmod -R 777 "${TFTP_ROOT}"

cat > /etc/default/tftpd-hpa << 'TFTPCFG'
# Configuration tftpd-hpa — Projet IRIS-RP01
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --create --verbose --ipv4"
RUN_DAEMON="yes"
OPTIONS="--secure --create --verbose --ipv4"
TFTPCFG

systemctl enable tftpd-hpa
systemctl restart tftpd-hpa
sleep 2

if systemctl is-active --quiet tftpd-hpa; then
    echo "[OK]  tftpd-hpa actif sur ${TFTP_SERVER_IP}:69"
else
    echo "[FAIL] tftpd-hpa ne démarre pas — vérifier les logs :"
    journalctl -u tftpd-hpa --no-pager -n 20
    exit 1
fi

# ══════════════════════════════════════════════════════════════
# 3. Script de sauvegarde TFTP Cisco
# ══════════════════════════════════════════════════════════════
echo "[STEP] Création du script de sauvegarde cisco-tftp-backup.sh..."

cat > "${BACKUP_SCRIPT}" << 'BACKUPSCRIPT'
#!/bin/bash
# cisco-tftp-backup.sh — Sauvegarde TFTP des équipements Cisco
# Appelé par cron toutes les nuits à 02h00
# Usage : cisco-tftp-backup.sh [--force] [--device SW2|AP2|RT2]

set -uo pipefail

TFTP_SERVER="192.168.50.20"
BACKUP_DIR="/srv/tftp/cisco-backups"
LOG_FILE="/var/log/tftp-backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }

# Fonction de sauvegarde SNMP (méthode principale)
backup_via_snmp() {
    local DEVICE_NAME="$1"
    local DEVICE_IP="$2"
    local SNMP_COMMUNITY="iris-ro"
    local FILENAME="${DEVICE_NAME}_${DATE}.cfg"
    local DEST_PATH="${BACKUP_DIR}/${DEVICE_NAME}"

    log "INFO  Sauvegarde SNMP de ${DEVICE_NAME} (${DEVICE_IP})..."

    # OID CISCO-CONFIG-MAN-MIB : ccmHistoryEventCommandSource
    # Méthode : SNMP SET pour déclencher une copie vers TFTP
    # OID : 1.3.6.1.4.1.9.9.96.1.1.1.1 (ciscoFlashCopyTable)

    # Option 1 : Via SNMP SET (ccCopyProtocol=1:TFTP, ccCopySourceFileType=4:runningConfig)
    snmpset -v2c -c "${SNMP_COMMUNITY}" "${DEVICE_IP}" \
        1.3.6.1.4.1.9.9.96.1.1.1.1.2.100  i 1 \
        1.3.6.1.4.1.9.9.96.1.1.1.1.3.100  i 4 \
        1.3.6.1.4.1.9.9.96.1.1.1.1.4.100  i 1 \
        1.3.6.1.4.1.9.9.96.1.1.1.1.5.100  a "${TFTP_SERVER}" \
        1.3.6.1.4.1.9.9.96.1.1.1.1.6.100  s "cisco-backups/${DEVICE_NAME}/${FILENAME}" \
        1.3.6.1.4.1.9.9.96.1.1.1.1.14.100 i 1 2>&1 >> "${LOG_FILE}" || true

    sleep 5

    # Vérifier que le fichier est arrivé
    if [ -f "${DEST_PATH}/${FILENAME}" ] && [ -s "${DEST_PATH}/${FILENAME}" ]; then
        log "OK    ${DEVICE_NAME} sauvegardé : ${FILENAME} ($(stat -c%s "${DEST_PATH}/${FILENAME}") bytes)"
        # Créer un lien symbolique "latest"
        ln -sf "${DEST_PATH}/${FILENAME}" "${DEST_PATH}/${DEVICE_NAME}_latest.cfg"
        return 0
    else
        log "WARN  SNMP échoué pour ${DEVICE_NAME} — tentative SSH..."
        return 1
    fi
}

# Fonction de sauvegarde SSH (fallback)
backup_via_ssh() {
    local DEVICE_NAME="$1"
    local DEVICE_IP="$2"
    local SSH_USER="admin"
    local SSH_KEY="/root/.ssh/cisco_backup_key"
    local FILENAME="${DEVICE_NAME}_${DATE}.cfg"
    local DEST_PATH="${BACKUP_DIR}/${DEVICE_NAME}"

    log "INFO  Sauvegarde SSH de ${DEVICE_NAME} (${DEVICE_IP})..."

    # Méthode SSH : récupérer la running-config
    if ssh -o StrictHostKeyChecking=no \
           -o ConnectTimeout=15 \
           -o BatchMode=yes \
           -i "${SSH_KEY}" \
           "${SSH_USER}@${DEVICE_IP}" \
           "show running-config" > "${DEST_PATH}/${FILENAME}" 2>/dev/null; then

        if [ -s "${DEST_PATH}/${FILENAME}" ]; then
            log "OK    ${DEVICE_NAME} sauvegardé SSH : ${FILENAME} ($(stat -c%s "${DEST_PATH}/${FILENAME}") bytes)"
            ln -sf "${DEST_PATH}/${FILENAME}" "${DEST_PATH}/${DEVICE_NAME}_latest.cfg"
            return 0
        fi
    fi

    log "WARN  SSH échoué pour ${DEVICE_NAME} — tentative TFTP direct (copy run tftp)..."

    # Dernière option : commande TFTP depuis l'équipement
    # Nécessite que l'équipement ait une route vers le serveur TFTP
    # La commande "copy running-config tftp" doit être configurée sur le Cisco
    log "ACTION REQUISE : Exécuter manuellement sur ${DEVICE_NAME} :"
    log "  copy running-config tftp"
    log "  Address or name of remote host: ${TFTP_SERVER}"
    log "  Destination filename: cisco-backups/${DEVICE_NAME}/${FILENAME}"
    return 1
}

# Archivage et rotation
archive_and_rotate() {
    local DEVICE_NAME="$1"
    local DEST_PATH="${BACKUP_DIR}/${DEVICE_NAME}"
    local ARCHIVE_PATH="${BACKUP_DIR}/archives"

    # Archiver les fichiers de plus de 7 jours dans le dossier archives
    find "${DEST_PATH}" -name "*.cfg" -mtime +7 -not -name "*latest*" \
        -exec mv {} "${ARCHIVE_PATH}/" \; 2>/dev/null || true

    # Supprimer les archives de plus de RETENTION_DAYS jours
    local deleted
    deleted=$(find "${ARCHIVE_PATH}" -name "*.cfg" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
    if [ "$deleted" -gt 0 ]; then
        log "INFO  Rotation : ${deleted} fichier(s) supprimé(s) (>${RETENTION_DAYS} jours)"
    fi
}

# ── MAIN ──────────────────────────────────────────────────────
log "═══ DEBUT SAUVEGARDE TFTP CISCO ════════════════════════"

SUCCESS=0
FAIL=0

declare -A DEVICES
DEVICES["SW2-IRIS"]="192.168.50.2"
DEVICES["AP2-IRIS"]="192.168.50.5"
DEVICES["RT2-IRIS"]="192.168.50.1"

for DEVICE in "${!DEVICES[@]}"; do
    IP="${DEVICES[$DEVICE]}"

    # Test de connectivité
    if ! ping -c 2 -W 3 "${IP}" &>/dev/null; then
        log "SKIP  ${DEVICE} (${IP}) injoignable — skip"
        ((FAIL++)) || true
        continue
    fi

    # Tentative sauvegarde SNMP puis SSH
    if backup_via_snmp "${DEVICE}" "${IP}" || backup_via_ssh "${DEVICE}" "${IP}"; then
        ((SUCCESS++)) || true
        archive_and_rotate "${DEVICE}"
    else
        ((FAIL++)) || true
        log "FAIL  ${DEVICE} — Toutes les méthodes ont échoué"
    fi
done

log "═══ FIN SAUVEGARDE : ${SUCCESS} OK / ${FAIL} ECHEC ════"

# Envoyer une alerte si des échecs (via syslog)
if [ "$FAIL" -gt 0 ]; then
    logger -p local0.warning -t cisco-backup "ALERTE: ${FAIL} équipement(s) non sauvegardé(s)"
fi

exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
BACKUPSCRIPT

chmod +x "${BACKUP_SCRIPT}"
echo "[OK]  Script créé : ${BACKUP_SCRIPT}"

# ══════════════════════════════════════════════════════════════
# 4. Script de restauration
# ══════════════════════════════════════════════════════════════
echo "[STEP] Création du script de restauration cisco-tftp-restore.sh..."

cat > "${RESTORE_SCRIPT}" << 'RESTORESCRIPT'
#!/bin/bash
# cisco-tftp-restore.sh — Restauration config Cisco depuis TFTP
# Usage : cisco-tftp-restore.sh <DEVICE_NAME> [DATE_YYYYMMDD]
# Exemple : cisco-tftp-restore.sh SW2-IRIS 20250101

DEVICE="${1:-}"
DATE_FILTER="${2:-latest}"
BACKUP_DIR="/srv/tftp/cisco-backups"
TFTP_SERVER="192.168.50.20"

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 <SW2-IRIS|AP2-IRIS|RT2-IRIS> [DATE_YYYYMMDD]"
    echo ""
    echo "Fichiers disponibles :"
    for d in "${BACKUP_DIR}"/*/; do
        echo "  $(basename "$d") :"
        ls "${d}"*.cfg 2>/dev/null | head -5 || echo "    (aucun)"
    done
    exit 1
fi

DEVICE_DIR="${BACKUP_DIR}/${DEVICE}"

if [ "$DATE_FILTER" = "latest" ]; then
    CONFIG_FILE=$(readlink -f "${DEVICE_DIR}/${DEVICE}_latest.cfg" 2>/dev/null || \
                  ls -t "${DEVICE_DIR}"/*.cfg 2>/dev/null | head -1)
else
    CONFIG_FILE=$(ls "${DEVICE_DIR}"/*${DATE_FILTER}*.cfg 2>/dev/null | head -1)
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "[FAIL] Aucun fichier de configuration trouvé pour ${DEVICE} (filtre: ${DATE_FILTER})"
    exit 1
fi

RELATIVE_PATH="${CONFIG_FILE#/srv/tftp/}"
echo "[INFO] Fichier à restaurer : ${CONFIG_FILE}"
echo "[INFO] Commande à exécuter SUR L'ÉQUIPEMENT ${DEVICE} :"
echo ""
echo "  copy tftp running-config"
echo "  Address or name of remote host: ${TFTP_SERVER}"
echo "  Source filename: ${RELATIVE_PATH}"
echo ""
echo "[INFO] Ou via TFTP direct :"
echo "  copy tftp://${TFTP_SERVER}/${RELATIVE_PATH} running-config"
RESTORESCRIPT

chmod +x "${RESTORE_SCRIPT}"
echo "[OK]  Script créé : ${RESTORE_SCRIPT}"

# ══════════════════════════════════════════════════════════════
# 5. Cron — Sauvegarde toutes les nuits à 02h00
# ══════════════════════════════════════════════════════════════
echo "[STEP] Configuration du cron de sauvegarde..."

CRON_LINE="0 2 * * * root ${BACKUP_SCRIPT} >> /var/log/tftp-backup.log 2>&1"
CRON_FILE="/etc/cron.d/cisco-tftp-backup"

cat > "${CRON_FILE}" << CRONCFG
# Sauvegarde TFTP quotidienne des équipements Cisco — Projet IRIS-RP01
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Sauvegarde chaque nuit à 02h00
0 2 * * * root ${BACKUP_SCRIPT} >> /var/log/tftp-backup.log 2>&1

# Sauvegarde hebdomadaire archivée (dimanche 03h00)
0 3 * * 0 root ${BACKUP_SCRIPT} && cp -r ${BACKUP_DIR} ${BACKUP_DIR}/archives/weekly_\$(date +\%Y\%W) >> /var/log/tftp-backup.log 2>&1
CRONCFG

chmod 644 "${CRON_FILE}"
echo "[OK]  Cron configuré : /etc/cron.d/cisco-tftp-backup"

# ══════════════════════════════════════════════════════════════
# 6. Fichiers vides pré-créés pour TFTP push depuis Cisco
# ══════════════════════════════════════════════════════════════
echo "[STEP] Pré-création des fichiers de destination TFTP..."

for DEVICE in SW2-IRIS AP2-IRIS RT2-IRIS; do
    TOUCH_FILE="${BACKUP_DIR}/${DEVICE}/${DEVICE}_manual.cfg"
    touch "${TOUCH_FILE}"
    chown tftp:tftp "${TOUCH_FILE}"
    chmod 666 "${TOUCH_FILE}"
    echo "[OK]  Fichier cible créé : ${TOUCH_FILE}"
done

# ══════════════════════════════════════════════════════════════
# 7. Configuration SNMP sur les Cisco (commandes à appliquer)
# ══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════════"
echo " COMMANDES A APPLIQUER SUR LES EQUIPEMENTS CISCO"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "SW2-IRIS (192.168.50.2) — Connexion SSH puis :"
echo "  conf t"
echo "  snmp-server community iris-ro RO 99"
echo "  snmp-server community iris-rw RW 99"
echo "  snmp-server host 192.168.50.20 version 2c iris-ro"
echo "  ip tftp source-interface Vlan50"
echo "  end"
echo "  copy running-config tftp://192.168.50.20/cisco-backups/SW2-IRIS/SW2-IRIS_manual.cfg"
echo ""
echo "AP2-IRIS (192.168.50.5) — Connexion SSH puis :"
echo "  conf t"
echo "  snmp-server community iris-ro RO"
echo "  snmp-server host 192.168.50.20 version 2c iris-ro"
echo "  end"
echo "  copy running-config tftp://192.168.50.20/cisco-backups/AP2-IRIS/AP2-IRIS_manual.cfg"
echo ""
echo "══════════════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════
# 8. Lancement de la première sauvegarde
# ══════════════════════════════════════════════════════════════
echo "[STEP] Exécution de la première sauvegarde (test)..."
"${BACKUP_SCRIPT}" || true

echo ""
echo "══════════════════════════════════════════════════════════"
echo " TFTP CONFIGURE"
echo "══════════════════════════════════════════════════════════"
echo "  [OK] Serveur TFTP       : ${TFTP_SERVER_IP}:69"
echo "  [OK] Répertoire dépôt   : ${BACKUP_DIR}"
echo "  [OK] Script backup      : ${BACKUP_SCRIPT}"
echo "  [OK] Script restore     : ${RESTORE_SCRIPT}"
echo "  [OK] Cron               : Chaque nuit à 02h00"
echo "  [OK] Rétention          : 30 jours"
echo "  [LOG] Logs              : ${LOG_FILE}"
echo "══════════════════════════════════════════════════════════"
