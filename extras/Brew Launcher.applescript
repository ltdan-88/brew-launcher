on run {input, parameters}

    tell application "Ghostty"

        activate

        if (count of windows) = 0 then
            set win to new window
            set t to selected tab of win
        else
            set win to front window
            set t to selected tab of win
        end if

        set term to focused terminal of t

        input text "exec \"$(brew --prefix)/bin/brew-launcher\"" to term
        send key "enter" to term

        focus term

    end tell

    return input

end run
