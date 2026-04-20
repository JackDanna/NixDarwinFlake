{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-openclaw.url = "github:openclaw/nix-openclaw";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      nix-openclaw,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
    }:
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#developers-Mac-mini
      darwinConfigurations."developers-Mac-mini" = nix-darwin.lib.darwinSystem {
        modules = [
          # Expose openclaw packages via the nixpkgs overlay.
          { nixpkgs.overlays = [ nix-openclaw.overlays.default ]; }

          # Home Manager as a nix-darwin module.
          home-manager.darwinModules.home-manager

          # Injects the openclaw Home Manager module via home-manager.sharedModules.
          nix-openclaw.darwinModules.openclaw

          # OpenClaw Home Manager configuration for the primary user.
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.developer = {
              home.stateVersion = "24.05";
              programs.openclaw = {
                documents = ./documents;
                config = {
                  gateway.mode = "local";
                  # Generate with: openssl rand -hex 32
                  gateway.auth.token = "REPLACE_WITH_LONG_RANDOM_TOKEN";
                  channels.telegram = {
                    tokenFile = "/Users/developer/.secrets/telegram-token";
                    allowFrom = [ /* your Telegram user ID integer */ ];
                  };
                };
                instances.default.enable = true;
              };
            };
          }
          # Configuration for system packages and settings
          (
            { pkgs, ... }:
            {
              # List packages installed in system profile. To search by name, run:
              # $ nix-env -qaP | grep wget
              environment.systemPackages = with pkgs; [
                git
                nixfmt
                nixd
                vscode
              ];

              # Determinate Nix manages the Nix installation, so disable nix-darwin's management.
              nix.enable = false;

              # Not necessary when using Determinate Nix (flakes are enabled by default).
              # nix.settings.experimental-features = "nix-command flakes";

              # Enable alternative shell support in nix-darwin.
              # programs.fish.enable = true;

              # Set Git commit hash for darwin-version.
              system.configurationRevision = self.rev or self.dirtyRev or null;

              # Used for backwards compatibility, please read the changelog before changing.
              # $ darwin-rebuild changelog
              system.stateVersion = 6;

              # Required for options like homebrew.enable that apply to a specific user.
              system.primaryUser = "developer";

              # The platform the configuration will be used on.
              nixpkgs.hostPlatform = "aarch64-darwin";

              # Install Rosetta 2 for Intel app compatibility..
              system.activationScripts.installRosetta.text = ''
                softwareupdate --install-rosetta --agree-to-license
              '';

              # Allow unfree packages (e.g. vscode).
              nixpkgs.config.allowUnfree = true;

              homebrew = {
                enable = true;
                brews = [
                  "mas"
                ];
                # casks = [
                #   "visual-studio-code"
                # ];
                masApps = {
                  Xcode = 497799835;
                };
                onActivation.cleanup = "zap";
                onActivation.autoUpdate = true;
                onActivation.upgrade = true;
              };
            }
          )

          # Loads the nix-homebrew feature, adding the nix-homebrew option namespace into nix-darwin.
          nix-homebrew.darwinModules.nix-homebrew

          # Configures nix-homebrew: enables it, sets the user, and pins tap versions via flake.lock.
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "developer";
              taps = {
                "homebrew/homebrew-core" = homebrew-core;
                "homebrew/homebrew-cask" = homebrew-cask;
              };
              mutableTaps = false;
            };
          }

          # Wires nix-homebrew's pinned taps into nix-darwin's homebrew.taps so they are activated.
          (
            { config, ... }:
            {
              homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
            }
          )
        ];
      };
    };
}
