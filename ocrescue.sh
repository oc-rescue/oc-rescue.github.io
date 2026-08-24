#!/bin/sh
set -eu

OCLP_VERSION="2.4.1"
OCLP_URL="https://github.com/dortania/OpenCore-Legacy-Patcher/releases/download/2.4.1/OpenCore-Patcher.pkg"
OCLP_SHA256="a8c0732c197b49337d2b8b970ce57f5151495a2dac300e1f93e802a0261e188d"
SUPPORTED_MODELS="MacBookPro9,1 MacBookPro9,2 MacBookPro10,1 MacBookPro10,2"

say() { printf '%s\n' "$*"; }
fail() { say ""; say "ERREUR: $*"; exit 1; }
ask() { printf '%s' "$*" > /dev/tty; IFS= read -r REPLY < /dev/tty || exit 1; }

say ""
say "  OpenCore Rescue"
say "  ----------------"
say "  Construction d'une EFI de secours avec OCLP ${OCLP_VERSION}"
say ""

[ "$(uname -s)" = "Darwin" ] || fail "Ce script doit être exécuté depuis macOS Recovery."
command -v diskutil >/dev/null 2>&1 || fail "diskutil est introuvable."
command -v pkgutil >/dev/null 2>&1 || fail "pkgutil est introuvable."
command -v curl >/dev/null 2>&1 || fail "curl est introuvable."

DETECTED_MODEL="$(sysctl -n hw.model 2>/dev/null || true)"
MODEL="${OCRESCUE_MODEL:-$DETECTED_MODEL}"

case " $SUPPORTED_MODELS " in
  *" $MODEL "*) ;;
  *)
    say "Modèle détecté: ${DETECTED_MODEL:-inconnu}"
    say "Modèles pris en charge: $SUPPORTED_MODELS"
    fail "Modèle non pris en charge. Ne forcez jamais l'EFI d'un autre modèle."
    ;;
esac

say "Modèle cible: $MODEL"
say ""
say "Disques USB externes détectés:"
EXTERNAL_DISKS="$(diskutil list external physical 2>/dev/null | awk '/^\/dev\/disk[0-9]+ \(external, physical\):/{gsub("/dev/", "", $1); print $1}')"
[ -n "$EXTERNAL_DISKS" ] || fail "Aucun disque externe physique détecté. Branchez une seconde clé USB."

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
say "ATTENTION: ne sélectionnez pas la clé qui contient l'installateur macOS Recovery."
ask "Identifiant de la clé à EFFACER (exemple disk3): "
TARGET_DISK="$REPLY"
case " $EXTERNAL_DISKS " in
  *" $TARGET_DISK "*) ;;
  *) fail "$TARGET_DISK n'est pas un disque externe proposé." ;;
esac

ask "Pour confirmer, saisissez exactement EFFACER $TARGET_DISK : "
[ "$REPLY" = "EFFACER $TARGET_DISK" ] || fail "Confirmation incorrecte. Aucun disque n'a été modifié."

say ""
say "Effacement de /dev/$TARGET_DISK…"
diskutil eraseDisk MS-DOS OCWORK GPT "/dev/$TARGET_DISK" >/dev/null || fail "Échec de l'effacement de la clé."
WORK_VOLUME="/Volumes/OCWORK"
[ -d "$WORK_VOLUME" ] || fail "Le volume de travail OCWORK n'a pas été monté."

WORK="$WORK_VOLUME/.ocrescue-work"
mkdir -p "$WORK"
PKG="$WORK/OpenCore-Patcher.pkg"
EXPANDED="$WORK/expanded"

say "Téléchargement du paquet officiel OpenCore Legacy Patcher…"
curl -fL --retry 2 --connect-timeout 20 "$OCLP_URL" -o "$PKG" || fail "Téléchargement OCLP impossible. Vérifiez la connexion réseau."

say "Vérification SHA-256 du paquet…"
if command -v shasum >/dev/null 2>&1; then
  DOWNLOADED_SHA256="$(shasum -a 256 "$PKG" | awk '{print $1}')"
elif command -v openssl >/dev/null 2>&1; then
  DOWNLOADED_SHA256="$(openssl dgst -sha256 "$PKG" | awk '{print $NF}')"
else
  fail "Aucun outil SHA-256 disponible; le paquet ne sera pas exécuté sans vérification."
fi
[ "$DOWNLOADED_SHA256" = "$OCLP_SHA256" ] || fail "Le paquet téléchargé ne correspond pas à la version officielle attendue."

say "Extraction du paquet officiel…"
pkgutil --expand-full "$PKG" "$EXPANDED" >/dev/null 2>&1 || fail "Impossible d'extraire le paquet OCLP dans cet environnement Recovery."
PATCHER="$(find "$EXPANDED" -type f -path '*/OpenCore-Patcher.app/Contents/MacOS/OpenCore-Patcher' -print | head -n 1)"
[ -n "$PATCHER" ] && [ -f "$PATCHER" ] || fail "Exécutable OCLP introuvable après extraction."
chmod +x "$PATCHER"

say "Construction de l'EFI pour $MODEL…"
cd "$WORK"
"$PATCHER" --build --model "$MODEL" --disable_sip --disable_smb || fail "La construction OCLP a échoué."
BUILD="$WORK/Build-Folder/OpenCore-Build"
[ -f "$BUILD/EFI/BOOT/BOOTx64.efi" ] || fail "Le chargeur OpenCore généré est introuvable."

EFI_PARTITION="${TARGET_DISK}s1"
diskutil info "/dev/$EFI_PARTITION" 2>/dev/null | grep -q 'EFI' || fail "La partition système EFI attendue est introuvable."
say "Montage de la partition système EFI…"
diskutil mount "/dev/$EFI_PARTITION" >/dev/null || fail "Impossible de monter la partition EFI."
EFI_VOLUME="$(diskutil info "/dev/$EFI_PARTITION" | awk -F: '/Mount Point/{sub(/^[ \t]+/, "", $2); print $2; exit}')"
[ -n "$EFI_VOLUME" ] && [ -d "$EFI_VOLUME" ] || fail "Le point de montage EFI est introuvable."

say "Installation d'OpenCore dans $EFI_VOLUME…"
/usr/bin/ditto "$BUILD/EFI" "$EFI_VOLUME/EFI"
if [ -d "$BUILD/System" ]; then
  /usr/bin/ditto "$BUILD/System" "$EFI_VOLUME/System"
fi
sync

[ -f "$EFI_VOLUME/EFI/BOOT/BOOTx64.efi" ] || fail "La vérification finale de la clé a échoué."
rm -rf "$WORK"

cat > "$WORK_VOLUME/LISEZ-MOI.txt" <<EOF
OpenCore Rescue — clé prête pour $MODEL

1. Éteignez le Mac.
2. Maintenez Option au démarrage.
3. Choisissez EFI Boot, puis votre macOS interne.
4. Dans macOS, reconstruisez OpenCore sur le disque interne avec OCLP.
EOF

say ""
say "SUCCÈS: la clé OpenCore est prête."
say "1. Éteignez le Mac."
say "2. Maintenez Option au démarrage."
say "3. Choisissez EFI Boot, puis votre macOS interne."
say "4. Une fois macOS lancé, reconstruisez OpenCore sur le disque interne avec OCLP."
say ""
