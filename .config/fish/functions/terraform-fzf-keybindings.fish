function terraform_fzf_keybindings --description "Setup terraform FZF keybindings"
    # Alt-t p = terraform plan
    bind -M default \etp '_terraform_fzf_command plan'
    bind -M insert \etp '_terraform_fzf_command plan'

    # Alt-t a = terraform apply
    bind -M default \eta '_terraform_fzf_command apply'
    bind -M insert \eta '_terraform_fzf_command apply'

    # Alt-t d = terraform destroy
    bind -M default \etd '_terraform_fzf_command destroy'
    bind -M insert \etd '_terraform_fzf_command destroy'

    # Alt-t i = terraform init
    bind -M default \eti '_terraform_fzf_command init'
    bind -M insert \eti '_terraform_fzf_command init'

    # Alt-t v = terraform validate
    bind -M default \etv '_terraform_fzf_command validate'
    bind -M insert \etv '_terraform_fzf_command validate'
end

# Auto-run on shell startup
terraform_fzf_keybindings
