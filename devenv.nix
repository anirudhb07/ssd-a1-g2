{
  pkgs,
  config,
  ...
}:
{
  packages = [ pkgs.git ];

  env = {
    PGUSER = "postgres";
    PGPASSWORD = "postgres";
    PGDATABASE = "app";
  };

  languages.python = {
    enable = true;
    lsp.enable = true;
    venv.enable = true;
    directory = "./data_generation";
    uv = {
      enable = true;
      sync.enable = true;
    };
  };

  languages.javascript = {
    enable = true;
    lsp.enable = true;
    directory = "./mongo";
  };

  services.postgres = {
    enable = true;
    initdbArgs = [
      "--locale=C"
      "--encoding=UTF8"
      "--username=${config.env.PGUSER}"
    ];
    initialDatabases = [
      {
        name = config.env.PGDATABASE;
        user = config.env.PGUSER;
        pass = config.env.PGPASSWORD;
      }
    ];
  };

  services.mongodb.enable = true;
}
