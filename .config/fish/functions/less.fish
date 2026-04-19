function less --description "Less with automatic log colorization"
    if string match -q -- "*.log" "$argv"; or string match -q -- "*.json" "$argv"
        command cat $argv | splash | command less -R
    else
        command less $argv
    end
end
