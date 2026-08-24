(function () {
  "use strict";

  var catalog = window.OCRESCUE_CATALOG || { release: { version: "?", package_size: 0 }, models: [] };
  var modelSelect = document.getElementById("model");
  var modelSearch = document.getElementById("model-search");
  var consent = document.getElementById("acknowledged");
  var commandNode = document.getElementById("command");
  var copyButton = document.getElementById("copy-button");
  var copyStatus = document.getElementById("copy-status");
  var currentModel = "auto";
  var copyTimer = null;

  var text = {
    fr: {
      eyebrow: "OUTIL DE RÉCUPÉRATION",
      headline1: "Refaites une clé OpenCore.",
      headline2: "Sans autre Mac.",
      lede: "Depuis Safari de macOS Recovery, préparez une clé EFI de secours avec les composants officiels d’OpenCore Legacy Patcher.",
      securityLabel: "Garanties de sécurité",
      trustDetect: "Modèle détecté",
      trustExternal: "Disques externes seuls",
      trustConfirm: "Double confirmation",
      trustVerified: "Téléchargement vérifié",
      prepareLabel: "PRÉPARER LA COMMANDE",
      cardTitle: "Clé EFI de secours",
      searchLabel: "Rechercher votre Mac",
      searchPlaceholder: "Ex. MacBookPro9,2 ou mi-2012",
      modelLabel: "Modèle cible",
      modelHelp: "En cas de doute, gardez la détection automatique : le script lira directement l’identifiant matériel du Mac.",
      autoModel: "Détection automatique — Recommandé",
      noResults: "Aucun modèle correspondant",
      otherFamily: "Autres",
      notice: "Une <strong>deuxième clé USB de 4 Go minimum</strong> est nécessaire. Son contenu sera effacé et environ {size} Mo seront téléchargés. Ne sélectionnez jamais la clé contenant macOS Recovery.",
      consent: "J’ai identifié la clé USB qui peut être effacée.",
      commandLabel: "Commande Terminal",
      preparing: "Préparation de la commande…",
      copy: "Copier",
      copied: "Copiée ✓",
      select: "Sélectionner",
      copySuccess: "Commande copiée dans le presse-papiers.",
      copyFailure: "Copie automatique impossible. Sélectionnez la commande manuellement.",
      step1: "Ouvrez <b>Utilitaires → Terminal</b>",
      step2: "Collez la commande puis appuyez sur Entrée",
      step3: "Suivez la sélection sécurisée de la clé",
      supportedModels: "modèles Mac pris en charge",
      macFamilies: "familles de Mac",
      autoCatalog: "catalogue synchronisé avec OCLP",
      howEyebrow: "CE QUE FAIT L’OUTIL",
      howTitle: "Un chemin court jusqu’au redémarrage.",
      inspectTitle: "Inspecte",
      inspectText: "Identifie le modèle réel et affiche uniquement les supports externes.",
      buildTitle: "Construit",
      buildText: "Télécharge la dernière version OCLP connue et génère l’EFI adaptée.",
      installTitle: "Installe",
      installText: "Monte la partition système EFI et vérifie la présence du chargeur.",
      restartTitle: "Redémarre",
      restartText: "Maintenez Option, choisissez EFI Boot, puis votre macOS interne.",
      beforeTitle: "À savoir avant de commencer",
      limit1: "Le site crée une EFI de secours, pas un installateur macOS complet.",
      limit2: "Le script ne sélectionne et ne modifie jamais automatiquement le disque interne.",
      limit3: "La liste des Mac et la version OCLP sont actualisées automatiquement depuis le projet officiel.",
      limit4: "Après démarrage, reconstruisez OpenCore sur le disque interne avec OCLP.",
      limit5: "Projet indépendant, non affilié à Apple ni à Dortania.",
      docs: "Documentation officielle Dortania ↗",
      description: "Créez une clé EFI OpenCore de secours depuis macOS Recovery, sans autre Mac."
    },
    en: {
      eyebrow: "RECOVERY TOOL",
      headline1: "Rebuild an OpenCore drive.",
      headline2: "Without another Mac.",
      lede: "From Safari in macOS Recovery, prepare a rescue EFI drive using the official OpenCore Legacy Patcher components.",
      securityLabel: "Safety guarantees",
      trustDetect: "Model detection",
      trustExternal: "External drives only",
      trustConfirm: "Double confirmation",
      trustVerified: "Verified download",
      prepareLabel: "PREPARE THE COMMAND",
      cardTitle: "Rescue EFI drive",
      searchLabel: "Find your Mac",
      searchPlaceholder: "E.g. MacBookPro9,2 or Mid 2012",
      modelLabel: "Target model",
      modelHelp: "If you are unsure, keep automatic detection: the script reads the Mac hardware identifier directly.",
      autoModel: "Automatic detection — Recommended",
      noResults: "No matching model",
      otherFamily: "Other",
      notice: "A <strong>second USB drive of at least 4 GB</strong> is required. Its contents will be erased and about {size} MB will be downloaded. Never select the drive containing macOS Recovery.",
      consent: "I have identified the USB drive that may be erased.",
      commandLabel: "Terminal command",
      preparing: "Preparing command…",
      copy: "Copy",
      copied: "Copied ✓",
      select: "Select",
      copySuccess: "Command copied to the clipboard.",
      copyFailure: "Automatic copy failed. Select the command manually.",
      step1: "Open <b>Utilities → Terminal</b>",
      step2: "Paste the command and press Return",
      step3: "Follow the safe drive selection prompts",
      supportedModels: "supported Mac models",
      macFamilies: "Mac families",
      autoCatalog: "catalog synced with OCLP",
      howEyebrow: "WHAT THE TOOL DOES",
      howTitle: "A short path back to booting.",
      inspectTitle: "Inspect",
      inspectText: "Identifies the actual Mac model and lists external physical drives only.",
      buildTitle: "Build",
      buildText: "Downloads the latest known OCLP release and builds the matching EFI.",
      installTitle: "Install",
      installText: "Mounts the EFI System Partition and verifies the bootloader.",
      restartTitle: "Restart",
      restartText: "Hold Option, choose EFI Boot, then select your internal macOS.",
      beforeTitle: "Before you begin",
      limit1: "The site creates a rescue EFI, not a complete macOS installer.",
      limit2: "The script never selects or modifies the internal drive automatically.",
      limit3: "The Mac list and OCLP release are updated automatically from the official project.",
      limit4: "After booting, rebuild OpenCore on the internal drive with OCLP.",
      limit5: "Independent project, not affiliated with Apple or Dortania.",
      docs: "Official Dortania documentation ↗",
      description: "Create an OpenCore rescue EFI drive from macOS Recovery, without another Mac."
    }
  };

  function initialLanguage() {
    try {
      var saved = window.localStorage.getItem("ocrescue-language");
      if (saved === "fr" || saved === "en") return saved;
    } catch (error) {}
    return String(navigator.language || "en").toLowerCase().indexOf("fr") === 0 ? "fr" : "en";
  }

  var language = initialLanguage();

  function translate(key) {
    var value = text[language][key] || key;
    var size = catalog.release.package_size ? Math.round(catalog.release.package_size / 1000000) : 736;
    return value.replace("{size}", String(size));
  }

  function applyTranslations() {
    var nodes = document.querySelectorAll("[data-i18n]");
    var htmlNodes = document.querySelectorAll("[data-i18n-html]");
    var placeholderNodes = document.querySelectorAll("[data-i18n-placeholder]");
    var ariaNodes = document.querySelectorAll("[data-i18n-aria]");
    var i;
    for (i = 0; i < nodes.length; i += 1) nodes[i].textContent = translate(nodes[i].getAttribute("data-i18n"));
    for (i = 0; i < htmlNodes.length; i += 1) htmlNodes[i].innerHTML = translate(htmlNodes[i].getAttribute("data-i18n-html"));
    for (i = 0; i < placeholderNodes.length; i += 1) placeholderNodes[i].setAttribute("placeholder", translate(placeholderNodes[i].getAttribute("data-i18n-placeholder")));
    for (i = 0; i < ariaNodes.length; i += 1) ariaNodes[i].setAttribute("aria-label", translate(ariaNodes[i].getAttribute("data-i18n-aria")));
    document.documentElement.lang = language;
    document.querySelector('meta[name="description"]').setAttribute("content", translate("description"));

    var languageButtons = document.querySelectorAll("[data-language]");
    for (i = 0; i < languageButtons.length; i += 1) {
      var active = languageButtons[i].getAttribute("data-language") === language;
      languageButtons[i].setAttribute("aria-pressed", active ? "true" : "false");
      languageButtons[i].className = active ? "active" : "";
    }
  }

  function modelName(model) {
    return language === "fr" ? model.name_fr : model.name_en;
  }

  function renderModels() {
    var query = modelSearch.value.toLowerCase().replace(/^\s+|\s+$/g, "");
    var matching = [];
    var i;
    for (i = 0; i < catalog.models.length; i += 1) {
      var model = catalog.models[i];
      var haystack = [model.id, model.family, model.name_en, model.name_fr].join(" ").toLowerCase();
      if (!query || haystack.indexOf(query) !== -1) matching.push(model);
    }

    while (modelSelect.firstChild) modelSelect.removeChild(modelSelect.firstChild);
    var autoOption = document.createElement("option");
    autoOption.value = "auto";
    autoOption.textContent = translate("autoModel");
    modelSelect.appendChild(autoOption);

    var groups = {};
    var order = [];
    for (i = 0; i < matching.length; i += 1) {
      var family = matching[i].family;
      if (!groups[family]) {
        groups[family] = [];
        order.push(family);
      }
      groups[family].push(matching[i]);
    }

    for (i = 0; i < order.length; i += 1) {
      var group = document.createElement("optgroup");
      group.label = order[i] === "Other" ? translate("otherFamily") : order[i];
      var familyModels = groups[order[i]];
      for (var j = 0; j < familyModels.length; j += 1) {
        var option = document.createElement("option");
        option.value = familyModels[j].id;
        option.textContent = modelName(familyModels[j]) + " — " + familyModels[j].id;
        group.appendChild(option);
      }
      modelSelect.appendChild(group);
    }

    if (matching.length === 0) {
      var emptyOption = document.createElement("option");
      emptyOption.disabled = true;
      emptyOption.textContent = translate("noResults");
      modelSelect.appendChild(emptyOption);
    }

    var selectedStillVisible = currentModel === "auto";
    for (i = 0; i < matching.length; i += 1) {
      if (matching[i].id === currentModel) selectedStillVisible = true;
    }
    if (!selectedStillVisible) currentModel = "auto";
    modelSelect.value = currentModel;
  }

  function scriptUrl() {
    if (window.location.protocol === "file:") return "https://oc-rescue.github.io/ocrescue.sh";
    return window.location.origin + "/ocrescue.sh";
  }

  function command() {
    var modelPrefix = currentModel === "auto" ? "" : "OCRESCUE_MODEL='" + currentModel + "' ";
    var languagePrefix = "OCRESCUE_LANG='" + language + "' ";
    return "curl -fsSL '" + scriptUrl() + "' -o /tmp/ocrescue.sh && " + languagePrefix + modelPrefix + "sh /tmp/ocrescue.sh";
  }

  function refresh() {
    commandNode.textContent = command();
    copyButton.disabled = !consent.checked;
  }

  function legacyCopy(value) {
    var textarea = document.createElement("textarea");
    textarea.value = value;
    textarea.setAttribute("readonly", "readonly");
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    var copied = document.execCommand("copy");
    document.body.removeChild(textarea);
    if (!copied) throw new Error("Copy denied");
  }

  function reportCopy(success) {
    copyButton.textContent = success ? translate("copied") : translate("select");
    copyStatus.textContent = success ? translate("copySuccess") : translate("copyFailure");
    if (copyTimer) window.clearTimeout(copyTimer);
    copyTimer = window.setTimeout(function () { copyButton.textContent = translate("copy"); }, 1800);
  }

  function copyCommand() {
    var value = command();
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(value).then(function () { reportCopy(true); }).catch(function () {
        try { legacyCopy(value); reportCopy(true); } catch (error) { reportCopy(false); }
      });
      return;
    }
    try { legacyCopy(value); reportCopy(true); } catch (error) { reportCopy(false); }
  }

  function setLanguage(nextLanguage) {
    language = nextLanguage;
    try { window.localStorage.setItem("ocrescue-language", language); } catch (error) {}
    applyTranslations();
    renderModels();
    refresh();
  }

  var languageButtons = document.querySelectorAll("[data-language]");
  for (var i = 0; i < languageButtons.length; i += 1) {
    languageButtons[i].addEventListener("click", function () { setLanguage(this.getAttribute("data-language")); });
  }
  modelSearch.addEventListener("input", function () { renderModels(); refresh(); });
  modelSelect.addEventListener("change", function () { currentModel = modelSelect.value; refresh(); });
  consent.addEventListener("change", refresh);
  copyButton.addEventListener("click", copyCommand);

  document.getElementById("version-badge").textContent = "OCLP " + catalog.release.version;
  document.getElementById("catalog-status-text").textContent = catalog.models.length + " Mac · OCLP " + catalog.release.version;
  document.getElementById("model-count").textContent = String(catalog.models.length);
  var families = {};
  for (i = 0; i < catalog.models.length; i += 1) families[catalog.models[i].family] = true;
  document.getElementById("family-count").textContent = String(Object.keys(families).length);

  setLanguage(language);
}());
