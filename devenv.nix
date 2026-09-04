{
  pkgs,
  config,
  ...
}:
{
  packages = [ 
    pkgs.git 
    pkgs.mongosh
    pkgs.postgresql 
  ];

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
}
