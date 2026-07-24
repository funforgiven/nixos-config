_: {
  nixos.modules.firefox.imports = [
    (
      let
        firefoxToolbarState = builtins.toJSON {
          placements = {
            widget-overflow-fixed-list = [ ];
            unified-extensions-area = [ ];
            nav-bar = [
              "back-button"
              "forward-button"
              "stop-reload-button"
              "customizableui-special-spring1"
              "vertical-spacer"
              "urlbar-container"
              "customizableui-special-spring2"
              "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
              "ublock0_raymondhill_net-browser-action"
              "fxa-toolbar-menu-button"
              "PanelUI-menu-button"
            ];
            toolbar-menubar = [ "menubar-items" ];
            TabsToolbar = [
              "tabbrowser-tabs"
              "new-tab-button"
              "alltabs-button"
            ];
            vertical-tabs = [ ];
            PersonalToolbar = [
              "import-button"
              "personal-bookmarks"
            ];
          };
          seen = [
            "reset-pbm-toolbar-button"
            "developer-button"
            "screenshot-button"
            "ublock0_raymondhill_net-browser-action"
            "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
          ];
          dirtyAreaCache = [
            "nav-bar"
            "vertical-tabs"
            "PersonalToolbar"
            "toolbar-menubar"
            "TabsToolbar"
            "unified-extensions-area"
          ];
          currentVersion = 24;
          newElementCount = 2;
        };
      in
      {
        programs.firefox = {
          enable = true;
          policies = {
            DisableProfileRefresh = true;
            DNSOverHTTPS = {
              Enabled = false;
              Locked = true;
            };
            ExtensionSettings = {
              "uBlock0@raymondhill.net" = {
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
                installation_mode = "force_installed";
              };
              "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
                installation_mode = "force_installed";
              };
            };
            Homepage = {
              URL = "about:blank";
              Locked = true;
              StartPage = "homepage";
            };
            NewTabPage = false;
            Permissions.Notifications = {
              BlockNewRequests = true;
              Locked = true;
            };
            SearchEngines = {
              Default = "Google";
              PreventInstalls = true;
              Remove = [
                "Amazon.com"
                "Bing"
                "DuckDuckGo"
                "eBay"
                "Ecosia"
                "GitHub"
                "Qwant"
                "Startpage"
                "Wikipedia"
                "Wikipedia (en)"
                "Wikipedia (en-US)"
                "Yahoo"
                "Yandex"
                "YouTube"
              ];
            };
            Preferences = {
              "browser.ai.window.enabled" = {
                Value = false;
                Status = "locked";
              };
              "browser.ai.window.prompt.enabled" = {
                Value = false;
                Status = "locked";
              };
              "browser.contentblocking.category" = {
                Value = "strict";
                Status = "locked";
              };
              "browser.ml.chat.enabled" = {
                Value = false;
                Status = "locked";
              };
              "browser.ml.chat.page" = {
                Value = false;
                Status = "locked";
              };
              "browser.ml.chat.page.footerBadge" = {
                Value = false;
                Status = "locked";
              };
              "browser.ml.chat.provider" = {
                Value = "";
                Status = "locked";
              };
              "browser.ml.chat.shortcuts" = {
                Value = false;
                Status = "locked";
              };
              "browser.ml.linkPreview.enabled" = {
                Value = false;
                Status = "locked";
              };
              "browser.ml.linkPreview.longPress" = {
                Value = false;
                Status = "locked";
              };
              "browser.ml.linkPreview.optin" = {
                Value = false;
                Status = "locked";
              };
              "browser.ml.pageAssist.enabled" = {
                Value = false;
                Status = "locked";
              };
              "browser.search.suggest.enabled" = {
                Value = true;
                Status = "locked";
              };
              "browser.tabs.closeWindowWithLastTab" = {
                Value = false;
                Status = "locked";
              };
              "browser.translations.enable" = {
                Value = true;
                Status = "locked";
              };
              "browser.translations.select.enable" = {
                Value = true;
                Status = "locked";
              };
              "browser.uiCustomization.state" = {
                Value = firefoxToolbarState;
                Status = "locked";
              };
              "browser.urlbar.showSearchSuggestionsFirst" = {
                Value = false;
                Status = "locked";
              };
              "browser.urlbar.suggest.history" = {
                Value = true;
                Status = "locked";
              };
              "browser.urlbar.suggest.searches" = {
                Value = true;
                Status = "locked";
              };
              "full-screen-api.transition-duration.enter" = {
                Value = "0 0";
                Status = "locked";
              };
              "full-screen-api.transition-duration.leave" = {
                Value = "0 0";
                Status = "locked";
              };
              "network.cookie.cookieBehavior" = {
                Value = 5;
                Status = "locked";
              };
              "network.cookie.cookieBehavior.pbmode" = {
                Value = 5;
                Status = "locked";
              };
              "permissions.default.desktop-notification" = {
                Value = 2;
                Status = "locked";
              };
              "privacy.fingerprintingProtection" = {
                Value = true;
                Status = "locked";
              };
              "privacy.fingerprintingProtection.pbmode" = {
                Value = true;
                Status = "locked";
              };
              "privacy.trackingprotection.allow_list.baseline.enabled" = {
                Value = true;
                Status = "locked";
              };
              "privacy.trackingprotection.allow_list.convenience.enabled" = {
                Value = true;
                Status = "locked";
              };
              "privacy.trackingprotection.cryptomining.enabled" = {
                Value = true;
                Status = "locked";
              };
              "privacy.trackingprotection.emailtracking.enabled" = {
                Value = true;
                Status = "locked";
              };
              "privacy.trackingprotection.enabled" = {
                Value = true;
                Status = "locked";
              };
              "privacy.trackingprotection.pbmode.enabled" = {
                Value = true;
                Status = "locked";
              };
              "privacy.trackingprotection.socialtracking.enabled" = {
                Value = true;
                Status = "locked";
              };
              "sidebar.notification.badge.aichat" = {
                Value = false;
                Status = "locked";
              };
              "sidebar.revamp" = {
                Value = false;
                Status = "locked";
              };
              "sidebar.verticalTabs" = {
                Value = false;
                Status = "locked";
              };
              "sidebar.visibility" = {
                Value = "hide-sidebar";
                Status = "locked";
              };
            };
          };
        };
      }

    )
  ];
  home.gui.imports = [
    (_: {
      home.sessionVariables.BROWSER = "firefox";

      programs.firefox = {
        enable = true;
        package = null;
        configPath = ".mozilla/firefox";
        profiles.default = {
          extensions.settings."FirefoxColor@mozilla.com".force = true;
          settings = {
            "extensions.autoDisableScopes" = 0;
            "layout.css.prefers-color-scheme.content-override" = 0;
            "services.sync.prefs.sync.browser.uiCustomization.state" = false;
          };
        };
      };

    }

    )
  ];
}
