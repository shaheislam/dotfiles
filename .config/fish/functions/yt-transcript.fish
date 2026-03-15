function yt-transcript --description "Fetch YouTube transcript and optionally save to Obsidian"
    # Usage: yt-transcript <youtube-url> [--json] [--timestamps] [--obsidian] [--title TITLE] [--folder FOLDER] [--tags TAGS]
    # Example: yt-transcript https://www.youtube.com/watch?v=dQw4w9WgXcQ
    # Example: yt-transcript https://youtu.be/dQw4w9WgXcQ --obsidian --title "Rick Astley"
    # Example: yt-transcript dQw4w9WgXcQ --timestamps

    if test (count $argv) -lt 1
        echo "Usage: yt-transcript <youtube-url|video-id> [options]"
        echo ""
        echo "Options:"
        echo "  --json         Output structured JSON"
        echo "  --timestamps   Include timestamps in output"
        echo "  --obsidian     Save as Obsidian note to ~/obsidian/Career/Videos/"
        echo "  --title TITLE  Set video title (for --obsidian)"
        echo "  --folder DIR   Subfolder within Videos/ (for --obsidian)"
        echo "  --tags TAGS    Comma-separated tags (for --obsidian)"
        echo ""
        echo "Examples:"
        echo "  yt-transcript https://www.youtube.com/watch?v=VIDEO_ID"
        echo "  yt-transcript VIDEO_ID --obsidian --title 'My Video'"
        echo "  yt-transcript https://youtu.be/VIDEO_ID --json"
        return 1
    end

    set -l script_path ~/dotfiles/scripts/youtube/yt-transcript.py

    if not test -f $script_path
        echo "Error: yt-transcript.py not found at $script_path"
        echo "Run: stow dotfiles (or check ~/dotfiles/scripts/youtube/)"
        return 1
    end

    python3 $script_path $argv
end
