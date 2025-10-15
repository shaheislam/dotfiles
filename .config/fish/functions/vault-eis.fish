function vault-eis --description "Load Vault EIS environment functions into current shell session"
    # Set LDAP username
    set -gx LDAP_USERNAME "mohamed.islam"

    # Create Vault environment functions
    # Farnborough environments
    function vaultnp --description "Connect to Vault Non-Production (Farnborough)"
        set -e VAULT_TOKEN
        set -gx VAULT_ADDR https://vault-elb.service.np.iptho.co.uk:443
        vault login -method=ldap username=$LDAP_USERNAME
    end

    function vaultops --description "Connect to Vault Operations (Farnborough)"
        set -e VAULT_TOKEN
        set -gx VAULT_ADDR https://vault-elb.service.ops.iptho.co.uk:443
        vault login -method=ldap username=$LDAP_USERNAME
    end

    function vaultpr --description "Connect to Vault Production (Farnborough)"
        set -e VAULT_TOKEN
        set -gx VAULT_ADDR https://vault-elb.service.pr.iptho.co.uk:443
        vault login -method=ldap username=$LDAP_USERNAME
    end

    # London environments
    function vaultnpl --description "Connect to Vault Non-Production (London)"
        set -e VAULT_TOKEN
        set -gx VAULT_ADDR https://vault.np.ebsa.homeoffice.gov.uk:443
        vault login -method=ldap username=$LDAP_USERNAME
    end

    function vaultprl --description "Connect to Vault Production (London)"
        set -e VAULT_TOKEN
        set -gx VAULT_ADDR https://vault.pr.ebsa.homeoffice.gov.uk:443
        vault login -method=ldap username=$LDAP_USERNAME
    end

    echo "✓ Vault EIS functions loaded successfully!"
    echo ""
    echo "Available functions:"
    echo "  vaultnp   - Non-Production (Farnborough)"
    echo "  vaultops  - Operations (Farnborough)"
    echo "  vaultpr   - Production (Farnborough)"
    echo "  vaultnpl  - Non-Production (London)"
    echo "  vaultprl  - Production (London)"
    echo ""
    echo "LDAP Username: $LDAP_USERNAME"
end
