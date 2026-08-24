# OpenCore Rescue

[Français](#français) · [English](#english)

## Français

Site statique GitHub Pages pour préparer une clé EFI OpenCore de secours depuis Safari dans macOS Recovery.

### Publication

1. Envoyez **tout le contenu** de ce dossier à la racine de `oc-rescue/oc-rescue.github.io`.
2. Dans **Settings → Pages**, choisissez **Deploy from a branch**, branche **main**, dossier **/(root)**.
3. Le site sera publié sur <https://oc-rescue.github.io/>.

### Mise à jour automatique d’OCLP

Le workflow `.github/workflows/update-oclp-catalog.yml` vérifie chaque jour la dernière publication officielle d’OCLP. Lorsqu’une version change, il actualise automatiquement :

- la version et l’adresse du paquet officiel ;
- son empreinte SHA-256 publiée par GitHub ;
- tous les modèles de `SupportedSMBIOS` ;
- les noms commerciaux issus de `smbios_data.py`.

Dans **Settings → Actions → General → Workflow permissions**, sélectionnez **Read and write permissions**, puis enregistrez. Le workflow peut aussi être lancé manuellement dans l’onglet **Actions**.

Le script de récupération télécharge ce petit catalogue avant de travailler. Si le catalogue est momentanément indisponible ou invalide, il revient aux données sûres intégrées et n’exécute jamais un paquet sans empreinte SHA-256 valide.

## English

Static GitHub Pages site for preparing an OpenCore rescue EFI drive from Safari in macOS Recovery.

### Publishing

1. Upload **all contents** of this folder to the root of `oc-rescue/oc-rescue.github.io`.
2. Under **Settings → Pages**, choose **Deploy from a branch**, branch **main**, folder **/(root)**.
3. The site will be published at <https://oc-rescue.github.io/>.

### Automatic OCLP updates

The `.github/workflows/update-oclp-catalog.yml` workflow checks the latest official OCLP release every day. It automatically updates the official package URL, its GitHub-published SHA-256 digest, every `SupportedSMBIOS` model and the marketing names from `smbios_data.py`.

Under **Settings → Actions → General → Workflow permissions**, select **Read and write permissions** and save. The workflow can also be started manually from the **Actions** tab.

The rescue script reads this small catalog before doing any work. If it is unavailable or invalid, the script safely falls back to its bundled release data and never runs a package without a valid SHA-256 digest.

## Safety

- External physical drives only.
- Explicit drive identifier plus a second erase confirmation.
- Official OCLP package and SHA-256 verification.
- OpenCore is written to the USB EFI System Partition.
- The internal drive is never selected automatically.

Independent project, not affiliated with Apple or Dortania. GPL-3.0.
