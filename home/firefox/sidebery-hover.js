// Loaded by Firefox AutoConfig, independently of web pages and extensions.
(() => {
  if (Services.appinfo.inSafeMode) return;

  const SIDEBERY = "_3c078156-979c-498b-8990-85f7987dd929_-sidebar-action";

  function install(win) {
    if (!Services.prefs.getBoolPref("userchrome.sidebery.hover", false) ||
        win.document.getElementById("sidebery-hover-edge")) return;

    const { document, SidebarController: sidebar } = win;
    const area = document.getElementById("browser");
    const box = document.getElementById("sidebar-box");
    if (!sidebar || !area || !box || sidebar.sidebarRevampEnabled ||
        sidebar.inSingleTabWindow) return;

    const edge = document.createXULElement("box");
    edge.id = "sidebery-hover-edge";
    edge.setAttribute("aria-hidden", "true");
    area.appendChild(edge);

    let peeking = false;
    let openTimer;
    let closeTimer;
    let closeAnimation;

    function cancelOpen() {
      win.clearTimeout(openTimer);
    }

    function cancelClose() {
      win.clearTimeout(closeTimer);
      if (closeAnimation) {
        const animation = closeAnimation;
        closeAnimation = null;
        animation.cancel();
      }
    }

    function sync() {
      const active = sidebar.currentID === SIDEBERY;
      box.toggleAttribute("sidebery-active", active);
      if (!active) {
        peeking = false;
        box.removeAttribute("sidebery-peek");
        cancelClose();
      }
      // Keep the sensor in place even while open. Hiding/recreating it would
      // generate a fresh mouseenter when Ctrl+E closes a panel under the pointer.
      edge.hidden = !sidebar.sidebars.has(SIDEBERY) ||
        document.documentElement.hasAttribute("inDOMFullscreen");
      if (edge.hidden) cancelOpen();
    }

    function closePeek() {
      cancelOpen();
      cancelClose();
      if (!peeking) return;
      peeking = false;
      if (sidebar.currentID === SIDEBERY) {
        // hide() focuses the web page. Preserve an address-bar/toolbar focus
        // that was present before a hover preview instead.
        const focused = Services.focus.focusedElement;
        sidebar.hide();
        if (focused?.ownerDocument === document && !box.contains(focused)) {
          focused.focus();
        }
      }
      box.removeAttribute("sidebery-peek");
      sync();
    }

    function scheduleClose() {
      cancelClose();
      if (!peeking) return;
      closeTimer = win.setTimeout(() => {
        if (box.matches(":hover") || edge.matches(":hover")) return;
        // Keep Sidebery context menus usable while the pointer is over them.
        if (document.querySelector('menupopup[open="true"], panel[panelopen="true"]')) {
          scheduleClose();
          return;
        }
        if (win.matchMedia("(prefers-reduced-motion: reduce)").matches) {
          closePeek();
          return;
        }
        // Firefox unloads the panel in hide(), so finish the slide before
        // calling it. Start at the current position if entry is still running.
        const animation = box.animate([
          { transform: win.getComputedStyle(box).transform },
          { transform: "translateX(-100%)" },
        ], {
          duration: 160,
          easing: "cubic-bezier(0.7, 0, 0.84, 0)",
          fill: "forwards",
        });
        closeAnimation = animation;
        animation.finished.then(() => {
          if (closeAnimation === animation) closePeek();
        }, () => {
          // Re-entering the panel or a native toggle cancels this animation.
        });
      }, 30);
    }

    edge.addEventListener("mouseenter", () => {
      cancelClose();
      cancelOpen();
      openTimer = win.setTimeout(async () => {
        if (edge.hidden || !edge.matches(":hover") || sidebar.isOpen ||
            !sidebar.sidebars.has(SIDEBERY)) return;
        peeking = true;
        box.setAttribute("sidebery-peek", "true");
        try {
          // Unlike show(), this does not move keyboard focus into Sidebery.
          await sidebar.showInitially(SIDEBERY);
          sync();
          scheduleClose();
        } catch (error) {
          closePeek();
          Components.utils.reportError(error);
        }
      }, 50);
    });
    edge.addEventListener("mouseleave", () => {
      cancelOpen();
      scheduleClose();
    });
    box.addEventListener("mouseenter", cancelClose);
    box.addEventListener("mouseleave", scheduleClose);

    // Observe native state instead of replacing toggle(), show(), or hide().
    // Ctrl+E and the extension toolbar button retain their normal behavior.
    const observer = new win.MutationObserver(sync);
    observer.observe(box, { attributes: true, attributeFilter: ["hidden", "checked"] });
    const fullscreenObserver = new win.MutationObserver(() => {
      if (document.documentElement.hasAttribute("inDOMFullscreen")) closePeek();
      sync();
    });
    fullscreenObserver.observe(document.documentElement, {
      attributes: true, attributeFilter: ["inDOMFullscreen"],
    });
    win.addEventListener("SidebarShown", sync);
    win.addEventListener("SidebarItemAdded", sync);
    win.addEventListener("SidebarItemRemoved", sync);
    // A window blur also occurs when focus moves into the sidebar's browser.
    // "deactivate" only fires when the browser window itself loses activation.
    win.addEventListener("deactivate", closePeek);
    win.addEventListener("unload", () => {
      cancelOpen();
      cancelClose();
      observer.disconnect();
      fullscreenObserver.disconnect();
    }, { once: true });
    sync();
  }

  Services.obs.addObserver((win) => {
    try {
      install(win);
    } catch (error) {
      Components.utils.reportError(error);
    }
  }, "browser-delayed-startup-finished");
})();
