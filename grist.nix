{ pkgs, ... }: {
  services.grist-core = {
    enable = true;
    settings = {
      GRIST_SESSION_SECRET = "thisisasupersecret";
      GRIST_HOST = "127.0.0.1";
      PYTHON_VERSION = "3";
      PYTHON_VERSION_ON_CREATION = "3";
    };
    environmentFile = "${./env}";
    package = pkgs.grist-core;
  };
  services.openssh.enable = true;
}
