# OpenCore Rescue

Site statique GitHub Pages permettant de préparer une clé EFI OpenCore de secours depuis Safari dans macOS Recovery.

## Publication

1. Envoyer tous les fichiers de ce dossier à la racine du dépôt `oc-rescue/oc-rescue.github.io`.
2. Ouvrir **Settings → Pages**.
3. Choisir **Deploy from a branch**, branche **main**, dossier **/(root)**.
4. Le site sera publié sur <https://oc-rescue.github.io/>.

## Sécurité

- `ocrescue.sh` ne propose que les disques externes physiques.
- Le disque choisi n'est effacé qu'après une confirmation contenant son identifiant.
- Le paquet officiel OCLP 2.4.1 est vérifié avec son empreinte SHA-256 avant exécution.
- Le script ne sélectionne et ne modifie jamais automatiquement le disque interne.

## Modèles pris en charge

- MacBookPro9,1
- MacBookPro9,2
- MacBookPro10,1
- MacBookPro10,2

Projet indépendant, non affilié à Apple ni à Dortania. Licence GPL-3.0.
