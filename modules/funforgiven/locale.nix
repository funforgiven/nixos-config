_:
let
  defaultLocale = "en_US.UTF-8";
  regionalLocale = "tr_TR.UTF-8";
in
{
  nixos.modules.funforgiven-locale = {
    i18n = {
      inherit defaultLocale;
      supportedLocales = [
        "${defaultLocale}/UTF-8"
        "${regionalLocale}/UTF-8"
      ];
      extraLocaleSettings = {
        LC_ADDRESS = regionalLocale;
        LC_IDENTIFICATION = regionalLocale;
        LC_MEASUREMENT = regionalLocale;
        LC_MONETARY = regionalLocale;
        LC_NAME = regionalLocale;
        LC_NUMERIC = regionalLocale;
        LC_PAPER = regionalLocale;
        LC_TELEPHONE = regionalLocale;
        LC_TIME = regionalLocale;
      };
    };
  };
}
