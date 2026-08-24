#!/bin/sh
set -eu

# Safe bundled fallback. A validated catalog from oc-rescue.github.io replaces
# these values automatically when a newer official OCLP release is published.
OCLP_VERSION="2.4.1"
OCLP_URL="https://github.com/dortania/OpenCore-Legacy-Patcher/releases/download/2.4.1/OpenCore-Patcher.pkg"
OCLP_SHA256="a8c0732c197b49337d2b8b970ce57f5151495a2dac300e1f93e802a0261e188d"
OCLP_SIZE="735976622"
SUPPORTED_MODELS="MacBook5,1;MacBook5,2;MacBook6,1;MacBook7,1;MacBook8,1;MacBook9,1;MacBook10,1;MacBookAir2,1;MacBookAir3,1;MacBookAir3,2;MacBookAir4,1;MacBookAir4,2;MacBookAir5,1;MacBookAir5,2;MacBookAir6,1;MacBookAir6,2;MacBookAir7,1;MacBookAir7,2;MacBookPro4,1;MacBookPro5,1;MacBookPro5,2;MacBookPro5,3;MacBookPro5,4;MacBookPro5,5;MacBookPro6,1;MacBookPro6,2;MacBookPro7,1;MacBookPro8,1;MacBookPro8,2;MacBookPro8,3;MacBookPro9,1;MacBookPro9,2;MacBookPro10,1;MacBookPro10,2;MacBookPro11,1;MacBookPro11,2;MacBookPro11,3;MacBookPro11,4;MacBookPro11,5;MacBookPro12,1;MacBookPro13,1;MacBookPro13,2;MacBookPro13,3;MacBookPro14,1;MacBookPro14,2;MacBookPro14,3;Macmini3,1;Macmini4,1;Macmini5,1;Macmini5,2;Macmini5,3;Macmini6,1;Macmini6,2;Macmini7,1;iMac7,1;iMac8,1;iMac9,1;iMac10,1;iMac11,1;iMac11,2;iMac11,3;iMac12,1;iMac12,2;iMac13,1;iMac13,2;iMac13,3;iMac14,1;iMac14,2;iMac14,3;iMac14,4;iMac15,1;iMac16,1;iMac16,2;iMac17,1;iMac18,1;iMac18,2;iMac18,3;MacPro3,1;MacPro4,1;MacPro5,1;MacPro6,1;Xserve2,1;Xserve3,1"

LANGUAGE="${OCRESCUE_LANG:-fr}"
case "$LANGUAGE" in en) ;; *) LANGUAGE="fr" ;; esac

say() { printf '%s\n' "$*"; }
tr_text() { if [ "$LANGUAGE" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
fail() { say ""; say "$(tr_text "ERREUR" "ERROR"): $*"; exit 1; }
ask() { printf '%s' "$*" > /dev/tty; IFS= read -r REPLY < /dev/tty || exit 1; }
config_field() { sed -n "s/^$1=//p" "$2" | sed -n '1p'; }

say ""
say "  OpenCore Rescue"
say "  ----------------"
say ""

[ "$(uname -s)" = "Darwin" ] || fail "$(tr_text "Ce script doit être exécuté depuis macOS Recovery." "This script must be run from macOS Recovery.")"
command -v diskutil >/dev/null 2>&1 || fail "diskutil $(tr_text "est introuvable." "was not found.")"
command -v pkgutil >/dev/null 2>&1 || fail "pkgutil $(tr_text "est introuvable." "was not found.")"
command -v curl >/dev/null 2>&1 || fail "curl $(tr_text "est introuvable." "was not found.")"

# Read the small, automatically maintained release file. Never eval or source it.
CONFIG_BASE="${OCRESCUE_BASE_URL:-https://oc-rescue.github.io}"
CONFIG_URL="${OCRESCUE_CONFIG_URL:-$CONFIG_BASE/data/oclp-release.txt}"
CONFIG_FILE="/tmp/ocrescue-release.txt"
CATALOG_UPDATED="no"
if curl -fsSL --retry 2 --connect-timeout 15 "$CONFIG_URL" -o "$CONFIG_FILE" 2>/dev/null; then
  NEW_VERSION="$(config_field OCLP_VERSION "$CONFIG_FILE")"
  NEW_URL="$(config_field OCLP_URL "$CONFIG_FILE")"
  NEW_SHA256="$(config_field OCLP_SHA256 "$CONFIG_FILE")"
  NEW_SIZE="$(config_field OCLP_SIZE "$CONFIG_FILE")"
  NEW_MODELS="$(config_field SUPPORTED_MODELS "$CONFIG_FILE")"
  CONFIG_VALID="yes"
  case "$NEW_VERSION" in ""|*[!A-Za-z0-9._-]*) CONFIG_VALID="no" ;; esac
  case "$NEW_URL" in https://github.com/dortania/OpenCore-Legacy-Patcher/releases/download/*/OpenCore-Patcher.pkg) ;; *) CONFIG_VALID="no" ;; esac
  case "$NEW_SHA256" in ""|*[!0-9a-f]*) CONFIG_VALID="no" ;; esac
  [ "${#NEW_SHA256}" -eq 64 ] || CONFIG_VALID="no"
  case "$NEW_SIZE" in ""|*[!0-9]*) CONFIG_VALID="no" ;; esac
  case "$NEW_MODELS" in ""|*[!A-Za-z0-9,\;]*) CONFIG_VALID="no" ;; esac
  if [ "$CONFIG_VALID" = "yes" ]; then
    OCLP_VERSION="$NEW_VERSION"
    OCLP_URL="$NEW_URL"
    OCLP_SHA256="$NEW_SHA256"
    OCLP_SIZE="$NEW_SIZE"
    SUPPORTED_MODELS="$NEW_MODELS"
    CATALOG_UPDATED="yes"
  fi
fi
rm -f "$CONFIG_FILE"

OCLP_MEGABYTES=$((OCLP_SIZE / 1000000))
say "$(tr_text "Construction d'une EFI de secours avec OCLP $OCLP_VERSION" "Building a rescue EFI with OCLP $OCLP_VERSION")"
if [ "$CATALOG_UPDATED" != "yes" ]; then
  say "$(tr_text "Information : catalogue en ligne indisponible, utilisation de la version sûre intégrée." "Note: online catalog unavailable; using the bundled safe release information.")"
fi
say ""

DETECTED_MODEL="$(sysctl -n hw.model 2>/dev/null || true)"
MODEL="${OCRESCUE_MODEL:-$DETECTED_MODEL}"

case ";$SUPPORTED_MODELS;" in
  *";$MODEL;"*) ;;
  *)
    say "$(tr_text "Modèle détecté" "Detected model"): ${DETECTED_MODEL:-unknown}"
    fail "$(tr_text "Ce modèle ne figure pas dans le catalogue OCLP pris en charge. Ne forcez jamais l'EFI d'un autre modèle." "This model is not in the supported OCLP catalog. Never force an EFI built for another model.")"
    ;;
esac

say "$(tr_text "Modèle cible" "Target model"): $MODEL"
say "$(tr_text "Téléchargement prévu" "Expected download"): ${OCLP_MEGABYTES} MB"
say ""
say "$(tr_text "Disques USB externes détectés :" "Detected external USB drives:")"
EXTERNAL_DISKS="$(diskutil list external physical 2>/dev/null | awk '/^\/dev\/disk[0-9]+ \(external, physical\):/{gsub("/dev/", "", $1); print $1}')"
[ -n "$EXTERNAL_DISKS" ] || fail "$(tr_text "Aucun disque externe physique détecté. Branchez une seconde clé USB." "No external physical drive was found. Connect a second USB drive.")"

for disk in $EXTERNAL_DISKS; do
  say ""
  diskutil info "/dev/$disk" | awk -F: '
    /Device Node|Media Name|Disk Size|Protocol/ {
      key=$1; value=$2;
      gsub(/^[ \t]+|[ \t]+$/, "", key);
      gsub(/^[ \t]+|[ \t]+$/, "", value);
      printf "  %-16s %s\n", key ":", value
    }'
done

say ""
say "$(tr_text "ATTENTION : ne sélectionnez pas la clé contenant l'installateur macOS Recovery." "WARNING: do not select the drive containing the macOS Recovery installer.")"
ask "$(tr_text "Identifiant de la clé à EFFACER (exemple disk3) : " "Drive identifier to ERASE (example disk3): ")"
TARGET_DISK="$REPLY"
case " $EXTERNAL_DISKS " in
  *" $TARGET_DISK "*) ;;
  *) fail "$(tr_text "$TARGET_DISK n'est pas un disque externe proposé." "$TARGET_DISK is not one of the listed external drives.")" ;;
esac

if [ "$LANGUAGE" = "en" ]; then CONFIRM_WORD="ERASE"; else CONFIRM_WORD="EFFACER"; fi
ask "$(tr_text "Pour confirmer, saisissez exactement $CONFIRM_WORD $TARGET_DISK : " "To confirm, enter exactly $CONFIRM_WORD $TARGET_DISK: ")"
[ "$REPLY" = "$CONFIRM_WORD $TARGET_DISK" ] || fail "$(tr_text "Confirmation incorrecte. Aucun disque n'a été modifié." "Incorrect confirmation. No drive was modified.")"

say ""
say "$(tr_text "Effacement de" "Erasing") /dev/$TARGET_DISK…"
diskutil eraseDisk MS-DOS OCWORK GPT "/dev/$TARGET_DISK" >/dev/null || fail "$(tr_text "Échec de l'effacement de la clé." "The USB drive could not be erased.")"
WORK_VOLUME="/Volumes/OCWORK"
[ -d "$WORK_VOLUME" ] || fail "$(tr_text "Le volume de travail OCWORK n'a pas été monté." "The OCWORK volume was not mounted.")"

WORK="$WORK_VOLUME/.ocrescue-work"
mkdir -p "$WORK"
PKG="$WORK/OpenCore-Patcher.pkg"
EXPANDED="$WORK/expanded"

say "$(tr_text "Téléchargement du paquet officiel OpenCore Legacy Patcher…" "Downloading the official OpenCore Legacy Patcher package…")"
curl -fL --retry 2 --connect-timeout 20 "$OCLP_URL" -o "$PKG" || fail "$(tr_text "Téléchargement OCLP impossible. Vérifiez la connexion réseau." "OCLP download failed. Check the network connection.")"

say "$(tr_text "Vérification SHA-256 du paquet…" "Verifying the package SHA-256 digest…")"
if command -v shasum >/dev/null 2>&1; then
  DOWNLOADED_SHA256="$(shasum -a 256 "$PKG" | awk '{print $1}')"
elif command -v openssl >/dev/null 2>&1; then
  DOWNLOADED_SHA256="$(openssl dgst -sha256 "$PKG" | awk '{print $NF}')"
else
  fail "$(tr_text "Aucun outil SHA-256 disponible ; le paquet ne sera pas exécuté sans vérification." "No SHA-256 tool is available; the package will not run without verification.")"
fi
[ "$DOWNLOADED_SHA256" = "$OCLP_SHA256" ] || fail "$(tr_text "Le paquet téléchargé ne correspond pas à la version officielle attendue." "The downloaded package does not match the expected official release.")"

say "$(tr_text "Extraction du paquet officiel…" "Extracting the official package…")"
pkgutil --expand-full "$PKG" "$EXPANDED" >/dev/null 2>&1 || fail "$(tr_text "Impossible d'extraire le paquet OCLP dans cet environnement Recovery." "The OCLP package could not be extracted in this Recovery environment.")"
PATCHER="$(find "$EXPANDED" -type f -path '*/OpenCore-Patcher.app/Contents/MacOS/OpenCore-Patcher' -print | head -n 1)"
[ -n "$PATCHER" ] && [ -f "$PATCHER" ] || fail "$(tr_text "Exécutable OCLP introuvable après extraction." "The OCLP executable was not found after extraction.")"
chmod +x "$PATCHER"

say "$(tr_text "Construction de l'EFI pour" "Building the EFI for") $MODEL…"
cd "$WORK"
"$PATCHER" --build --model "$MODEL" --disable_sip --disable_smb || fail "$(tr_text "La construction OCLP a échoué." "The OCLP build failed.")"
BUILD="$WORK/Build-Folder/OpenCore-Build"
[ -f "$BUILD/EFI/BOOT/BOOTx64.efi" ] || fail "$(tr_text "Le chargeur OpenCore généré est introuvable." "The generated OpenCore bootloader was not found.")"

EFI_PARTITION="${TARGET_DISK}s1"
diskutil info "/dev/$EFI_PARTITION" 2>/dev/null | grep -q 'EFI' || fail "$(tr_text "La partition système EFI attendue est introuvable." "The expected EFI System Partition was not found.")"
say "$(tr_text "Montage de la partition système EFI…" "Mounting the EFI System Partition…")"
diskutil mount "/dev/$EFI_PARTITION" >/dev/null || fail "$(tr_text "Impossible de monter la partition EFI." "The EFI partition could not be mounted.")"
EFI_VOLUME="$(diskutil info "/dev/$EFI_PARTITION" | awk -F: '/Mount Point/{sub(/^[ \t]+/, "", $2); print $2; exit}')"
[ -n "$EFI_VOLUME" ] && [ -d "$EFI_VOLUME" ] || fail "$(tr_text "Le point de montage EFI est introuvable." "The EFI mount point was not found.")"

say "$(tr_text "Installation d'OpenCore dans" "Installing OpenCore in") $EFI_VOLUME…"
/usr/bin/ditto "$BUILD/EFI" "$EFI_VOLUME/EFI"
if [ -d "$BUILD/System" ]; then /usr/bin/ditto "$BUILD/System" "$EFI_VOLUME/System"; fi
sync

[ -f "$EFI_VOLUME/EFI/BOOT/BOOTx64.efi" ] || fail "$(tr_text "La vérification finale de la clé a échoué." "Final USB drive verification failed.")"
rm -rf "$WORK"

if [ "$LANGUAGE" = "en" ]; then
  GUIDE_FILE="$WORK_VOLUME/README.txt"
else
  GUIDE_FILE="$WORK_VOLUME/LISEZ-MOI.txt"
fi
{
  say "OpenCore Rescue — $MODEL — OCLP $OCLP_VERSION"
  say ""
  say "$(tr_text "1. Éteignez le Mac." "1. Shut down the Mac.")"
  say "$(tr_text "2. Maintenez Option au démarrage." "2. Hold Option while starting it.")"
  say "$(tr_text "3. Choisissez EFI Boot, puis votre macOS interne." "3. Choose EFI Boot, then your internal macOS.")"
  say "$(tr_text "4. Dans macOS, reconstruisez OpenCore sur le disque interne avec OCLP." "4. In macOS, rebuild OpenCore on the internal drive with OCLP.")"
} > "$GUIDE_FILE"

say ""
say "$(tr_text "SUCCÈS : la clé OpenCore est prête." "SUCCESS: the OpenCore drive is ready.")"
say "$(tr_text "1. Éteignez le Mac." "1. Shut down the Mac.")"
say "$(tr_text "2. Maintenez Option au démarrage." "2. Hold Option while starting it.")"
say "$(tr_text "3. Choisissez EFI Boot, puis votre macOS interne." "3. Choose EFI Boot, then your internal macOS.")"
say "$(tr_text "4. Une fois macOS lancé, reconstruisez OpenCore sur le disque interne avec OCLP." "4. Once macOS starts, rebuild OpenCore on the internal drive with OCLP.")"
say ""
