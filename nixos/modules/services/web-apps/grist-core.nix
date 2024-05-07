{ config, lib, pkgs, ... }:

let
  inherit (lib)
    literalExpression
    types
    mkOption
    mkDefault
    mkPackageOption
    mkEnableOption
    mkIf
    ;

  cfg = config.services.grist-core;


in
{
  meta.maintainers = with lib.maintainers; [ soyouzpanda ];

  options.services.grist-core = {
    package = mkPackageOption pkgs "grist-core" {
      extraDescription = "Override it to tune the sandbox environment";
      example = ''
        pkgs.grist-core.override {
          sandboxPath = [ pkgs.hello ];
          pythonFun = (ps:
            pkgs.grist-core.defaultPythonFun ps ++
            with ps; [
              numpy
            ]
          );
        }
      '';
    };
    enable = mkEnableOption "Grist core";

    user = mkOption {
      type = types.str;
      default = "grist-core";
      description = "User account under which grist-core runs.";
    };

    group = mkOption {
      type = types.str;
      default = "grist-core";
      description = "Group under which grist-core runs.";
    };

    settings = mkOption {
      type = with types; attrsOf str;
      default = { };
      example = {
        GRIST_DEFAULT_EMAIL = "example@example.com";
      };
      description = ''
        Environment variables used for Grist.
        See [](https://github.com/gristlabs/grist-core/tree/v1.1.13?tab=readme-ov-file#environment-variables)
        for available environment variables.
      '';
    };

    environmentFile = mkOption {
      type = with types; nullOr path;
      default = null;
      description = ''
        Environment file for secrets.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.grist-core.settings = {
      GRIST_DATA_DIR = mkDefault "/var/lib/grist-core/docs";
      GRIST_INST_DIR = mkDefault "/var/lib/grist-core";
      GRIST_USER_ROOT = mkDefault "/var/lib/grist-core";
      TYPEORM_DATABASE = mkDefault "/var/lib/grist-core/db.sqlite";
    };

    systemd.services.grist-core = {
      description = "Grist Core";

      wantedBy = [ "multi-user.target" ];
      after = [ "postgresql.service" "network.target" ];
      path = [
        pkgs.gvisor
      ];

      serviceConfig = {
        RuntimeDirectory = "grist-core";
        WorkingDirectory = cfg.package;
        StateDirectory = "grist-core";
        #Restart = "always";
        ExecStart = "${pkgs.nodejs}/bin/node ${cfg.package}/_build/stubs/app/server/server.js";
        DynamicUser = true;

        Type = "exec";
        #ProtectHome = true;
        #ProtectSystem = "strict";
        #PrivateTmp = true;
        #PrivateDevices = true;
        #ProtectHostname = true;
        #ProtectClock = true;
        #ProtectKernelTunables = true;
        #ProtectKernelModules = true;
        #ProtectKernelLogs = true;
        #ProtectControlGroups = true;
        #NoNewPrivileges = true;
        #RestrictRealtime = true;
        #RestrictSUIDSGID = true;
        #RemoveIPC = true;
        #PrivateMounts = true;

        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
      };

      environment = cfg.settings // {
        NODE_PATH = "${cfg.package}/_build:${cfg.package}/_build/stubs:${cfg.package}/_build/ext";
        # We only support gVisor as a method of sandboxing for now.
        # If you are interested in a different method of sandboxing, feel free
        # to contribute to it.
        GRIST_SANDBOX_FLAVOR = "gvisor";
        GVISOR_FLAGS = "--rootless";
        GVISOR_AVAILABLE = "1";
      };
    };
  };
}


