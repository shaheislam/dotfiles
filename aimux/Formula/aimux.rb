class Aimux < Formula
  desc "AI Agent Multiplexer - terminal-agnostic agent orchestration for tmux"
  homepage "https://github.com/shaheislam/aimux"
  url "https://github.com/shaheislam/aimux/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"
  head "https://github.com/shaheislam/aimux.git", branch: "main"

  depends_on "go" => :build
  depends_on "tmux"
  depends_on "fzf" => :recommended
  depends_on "jq" => :recommended

  def install
    # Build Go daemon
    system "go", "build", *std_go_args(ldflags: "-s -w", output: bin/"aimuxd"), "./cmd/aimuxd/"

    # Install CLI dispatcher
    bin.install "bin/aimux"

    # Install shell libraries
    (lib/"aimux").install Dir["lib/aimux/*.sh"]
    (lib/"aimux/providers").install Dir["lib/aimux/providers/*.sh"]

    # Install config and templates
    (share/"aimux").install "config/aimux.tmux.conf"
    (share/"aimux").install "config/default.toml"
    (share/"aimux/templates/launch").install Dir["templates/launch/*.tmpl"]

    # Install completions
    fish_completion.install "completions/aimux.fish"
    bash_completion.install "completions/aimux.bash"
    zsh_completion.install "completions/_aimux"
  end

  def post_install
    ohai "Run 'aimux doctor' to verify your setup"
    ohai "Add to .tmux.conf: source-file #{share}/aimux/aimux.tmux.conf"
  end

  test do
    assert_match "aimux 0.2.0", shell_output("#{bin}/aimux version")
    assert_predicate bin/"aimuxd", :executable?
  end
end
