let
  defaultPythonFun = ps: with ps; [
    astroid
    asttokens
    chardet
    et-xmlfile
    executing
    friendly-traceback
    iso8601
    lazy-object-proxy
    openpyxl
    phonenumbers
    pure-eval
    python-dateutil
    roman
    six
    sortedcontainers
    stack-data
    typing-extensions
    unittest-xml-reporting
    wrapt
  ];
in
{ lib
, stdenv
, python3
, fetchFromGitHub
, fetchYarnDeps
, yarn
, nodejs
, prefetch-yarn-deps
, fixup-yarn-lock
, nodePackages
, nixosTests
, sandboxPath ? []
, pythonFun ? defaultPythonFun
, pythonEnv ? python3.withPackages pythonFun
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "grist-core";
  version = "1.1.13";

  src = fetchFromGitHub {
    owner = "gristlabs";
    repo = "grist-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-lLXgTVhztFGnfrMxks05T8dfE6CH4p/0j8lPieBRGTY=";
  };

  patches = [ ./run_py.patch ];

  offlineCache = fetchYarnDeps {
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-cbkykydPfIrlCxaLfdIFseBuNVUtIqPpLR2J3LTFQl4=";
  };

  nativeBuildInputs = with nodePackages; [
    yarn
    nodejs
    prefetch-yarn-deps
    fixup-yarn-lock
    node-gyp-build
    node-pre-gyp
  ];

  buildInputs = [
    python3
  ];

  passthru = {
    inherit defaultPythonFun;
    tests = {
      inherit (nixosTests) grist-core;
    };
  };

  postPatch = ''
    rm .yarnrc
  '';

  configurePhase = ''
    runHook preConfigure

    export HOME=$(mktemp -d)
    yarn config --offline set yarn-offline-mirror ${finalAttrs.offlineCache}
    fixup-yarn-lock yarn.lock

    mkdir -p "$HOME/.node-gyp/${nodejs.version}"
    echo 9 >"$HOME/.node-gyp/${nodejs.version}/installVersion"
    ln -sfv "${nodejs}/include" "$HOME/.node-gyp/${nodejs.version}"
    export npm_config_nodedir=${nodejs}

    yarn --offline --frozen-lockfile --ignore-platform --ignore-engines --no-progress --non-interactive install
    patchShebangs node_modules
    patchShebangs buildtools

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    yarn --offline run build:prod

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out

    cp -r _build $out
    cp -r node_modules $out
    cp -r plugins $out
    cp -r sandbox $out
    cp -r static $out
    cp -r bower_components $out

    runHook postInstall
  '';

  sandboxPath = lib.makeSearchPath "bin" (lib.singleton pythonEnv ++ sandboxPath);
  sandboxLibPath = lib.makeLibraryPath (lib.singleton pythonEnv ++ sandboxPath);
  pythonExe = lib.getExe pythonEnv;

  postFixup = ''
    substituteAllInPlace $out/sandbox/gvisor/run.py
  '';

  meta = {
    description = "Grist is the evolution of spreadsheets";
    homepage = "https://github.com/gristlabs/grist-core";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ soyouzpanda ];
    mainProgram = "grist-core";
    platforms = lib.platforms.all;
  };
})
