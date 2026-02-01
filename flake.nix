{
  description = "Azalea v6 - Home Lab Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "azalea-v6";

          packages = with pkgs; [
            # Kubernetes
            kubectl
            kubernetes-helm
            fluxcd
            kubeconform
            kustomize

            # Infrastructure as Code
            opentofu
            ansible
            ansible-lint

            # Secrets management
            sops
            age

            # CLI utilities
            jq
            yq-go
            curl
            wget

            # Cloud CLI
            cloudflared

            # Development
            shellcheck
            vim 
          ];

          shellHook = ''
            echo ""
            echo "  🦁 Azalea v6 - Home Lab Infrastructure"
            echo "  ────────────────────────────────────────"
            echo ""
            echo "  Bare Metal:"
            echo "    golden-savanna   (primary)"
            echo "    misty-bamboo     (worker)"
            echo "    lush-rainforest  (worker)"
            echo ""
            echo "  Tools available:"
            echo "    kubectl, helm, k9s, flux"
            echo "    tofu (opentofu), ansible"
            echo "    sops, age"
            echo ""
            echo "  Quick commands:"
            echo "    flux check       - Verify FluxCD status"
            echo "    k9s              - Terminal UI for K8s"
            echo "    tofu init        - Initialize Terraform"
            echo ""

            # Set KUBECONFIG if exists
            if [ -f "$HOME/.kube/config" ]; then
              export KUBECONFIG="$HOME/.kube/config"
            fi

            # Set SOPS age key if exists
            if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
              export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
            fi

            # Ansible config
            export ANSIBLE_CONFIG="$PWD/bootstrap/ansible/ansible.cfg"
          '';
        };

        # Formatter
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
