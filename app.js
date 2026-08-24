(function () {
  "use strict";

  var modelSelect = document.getElementById("model");
  var consent = document.getElementById("acknowledged");
  var commandNode = document.getElementById("command");
  var copyButton = document.getElementById("copy-button");
  var copyStatus = document.getElementById("copy-status");

  function scriptUrl() {
    if (window.location.protocol === "file:") {
      return "https://oc-rescue.github.io/ocrescue.sh";
    }
    return window.location.origin + "/ocrescue.sh";
  }

  function command() {
    var model = modelSelect.value;
    var prefix = model === "auto" ? "" : "OCRESCUE_MODEL='" + model + "' ";
    return "curl -fsSL '" + scriptUrl() + "' -o /tmp/ocrescue.sh && " + prefix + "sh /tmp/ocrescue.sh";
  }

  function refresh() {
    commandNode.textContent = command();
    copyButton.disabled = !consent.checked;
  }

  function legacyCopy(text) {
    var textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "readonly");
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    var copied = document.execCommand("copy");
    document.body.removeChild(textarea);
    if (!copied) {
      throw new Error("Copie refusée");
    }
  }

  function reportCopy(success) {
    copyButton.textContent = success ? "Copiée ✓" : "Sélectionner";
    copyStatus.textContent = success
      ? "Commande copiée dans le presse-papiers."
      : "Copie automatique impossible. Sélectionnez la commande manuellement.";
    window.setTimeout(function () {
      copyButton.textContent = "Copier";
    }, 1800);
  }

  function copyCommand() {
    var text = command();
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () {
        reportCopy(true);
      }).catch(function () {
        try {
          legacyCopy(text);
          reportCopy(true);
        } catch (error) {
          reportCopy(false);
        }
      });
      return;
    }

    try {
      legacyCopy(text);
      reportCopy(true);
    } catch (error) {
      reportCopy(false);
    }
  }

  modelSelect.addEventListener("change", refresh);
  consent.addEventListener("change", refresh);
  copyButton.addEventListener("click", copyCommand);
  refresh();
}());
