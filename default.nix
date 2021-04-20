{ stdenv, lib, nix-gitignore, gnumake, pkgconfig, wget, unzip, gawk
, sqlite, which, luaPackages, installShellFiles, makeWrapper
}:
let
  luaLibs = with luaPackages; [ lua luasql-sqlite3 luautf8 ];
in
stdenv.mkDerivation rec {
  pname   = "openrussian-cli";
  version = "1.0.0";

  src = nix-gitignore.gitignoreSource [] ./.;

  nativeBuildInputs = [
    gnumake pkgconfig wget unzip gawk sqlite which installShellFiles
  ];

  buildInputs = [ makeWrapper ] ++ luaLibs;

  makeFlags = [
    "LUA=${luaPackages.lua}/bin/lua"
    "LUAC=${luaPackages.lua}/bin/luac"
  ];

  dontConfigure = true;

  # Disable check as it's too slow.
  # doCheck = true;

  #This is needed even though it's the default for some reason.
  checkTarget = "check";

  # Can't use "make install" here
  installPhase = ''
    mkdir -p $out/bin $out/share/openrussian
    cp openrussian-sqlite3.db $out/share/openrussian
    cp openrussian $out/bin

    wrapProgram $out/bin/openrussian \
      --prefix LUA_PATH ';' "$LUA_PATH" \
      --prefix LUA_CPATH ';' "$LUA_CPATH"

    runHook postInstall
  '';

  postInstall = ''
    installShellCompletion --bash --name openrussian ./openrussian-completion.bash
    installManPage ./openrussian.1
  '';

  meta = with lib; {
    homepage    = "https://github.com/rhaberkorn/openrussian-cli";
    description = "Offline Console Russian Dictionary (based on openrussian.org)";
    license     = with licenses; [ gpl3 mit cc-by-sa-40 ];
    platforms   = platforms.unix;
  };
}

