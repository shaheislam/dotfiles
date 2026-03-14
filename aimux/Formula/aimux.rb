class Aimux < Formula
  desc "AI Agent Multiplexer - terminal-agnostic agent orchestration for tmux"
  homepage "https://github.com/shaheislam/aimux"
  url "https://github.com/shaheislam/aimux/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"
  head "https://github.com/shaheislam/aimux.git", branch: "main"

  depends_on "tmux"
  depends_on "fzf" => :recommended
  depends_on "jq" => :recommended

  def install
    bin.install "bin/aimux"
    (lib/"aimux").install Dir["lib/aimux/*.sh"]
    (share/"aimux").install "config/aimux.tmux.conf"
    fish_completion.install "completions/aimux.fish"
    bash_completion.install "completions/aimux.bash"
    zsh_completion.install "completions/_aimux"
  end

  def post_install
    ohai "Run 'aimux doctor' to verify your setup"
    ohai "Add to .tmux.conf: source-file #{share}/aimux/aimux.tmux.conf"
  end

  test do
    assert_match "aimux", shell_output("#{bin}/aimux version")
  end
end
