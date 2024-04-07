{ lib
, rustPlatform
, fetchFromGitHub
, strace
, makeWrapper
}:

rustPlatform.buildRustPackage rec {
  pname = "systemd-hardening-helper";
  version = "2024.4.5";

  src = fetchFromGitHub {
    owner = "synacktiv";
    repo = "shh";
    rev = "v${version}";
    hash = "sha256-9ELu4v7/+vhIR8fT00zJ6vCwiz0W8+4n/C/KMo+on6I=";
  };

  cargoHash = "sha256-cRF13hEmVRtqW8HLAT1nW9qj5/sRJT383nSHoqJ/7xw=";

  cargoTestFlags = [ "--bins" ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/shh --prefix PATH : "${strace}/bin"
    '';

  meta = with lib; {
    description = "Systemd Hardening Helper";
    homepage = "https://github.com/synacktiv/shh";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
    mainProgram = "systemd-hardening-helper";
  };
}
