function fish_prompt
    # Set a custom color for the directory path
    set_color cyan
    echo -n (prompt_pwd)

    set_color normal
    echo -n (fish_git_prompt)

    # Reset color and add your custom prompt symbol
    set_color normal
    echo
    echo -n '> '
end
