function terraform --description "Terraform with colored output"
    if contains -- "$argv[1]" plan apply destroy
        command terraform $argv | splash
    else
        command terraform $argv
    end
end
