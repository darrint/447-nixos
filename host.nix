{config, ...}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  sops.defaultSopsFile = ./secrets/slack-assistant.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  sops.secrets = {
    slack_bot_token = {mode = "0400";};
    slack_report_channel = {mode = "0400";};
    database_url = {mode = "0400";};
    llm_provider = {mode = "0400";};
    xai_api_key = {mode = "0400";};
    xai_model = {mode = "0400";};
    tz = {mode = "0400";};
  };
  sops.templates."slack-assistant.env" = {
    content = ''
      SLACK_BOT_TOKEN=${config.sops.placeholder.slack_bot_token}
      SLACK_REPORT_CHANNEL=${config.sops.placeholder.slack_report_channel}
      DATABASE_URL=${config.sops.placeholder.database_url}
      LLM_PROVIDER=${config.sops.placeholder.llm_provider}
      XAI_API_KEY=${config.sops.placeholder.xai_api_key}
      XAI_MODEL=${config.sops.placeholder.xai_model}
      TZ=${config.sops.placeholder.tz}
    '';
    mode = "0400";
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = ["slack_assistant"];
    ensureUsers = [
      {
        name = "slack_assistant";
        ensureDBOwnership = true;
      }
    ];
    identMap = ''
      slackmap dthompson slack_assistant
    '';
    authentication = ''
      local slack_assistant slack_assistant peer map=slackmap
    '';
  };

  services.slack-assistant = {
    enable = true;
    user = "dthompson";
    environmentFile = config.sops.templates."slack-assistant.env".path;
    onCalendar = "22:00:00";
    timeZone = "America/Indiana/Indianapolis";
  };

  systemd.services.slack-assistant = {
    after = ["sssd.service"];
    wants = ["sssd.service"];
  };
}
