class Pyroscope < Formula
  desc "Open source continuous profiling software"
  homepage "https://pyroscope.io"
  url "https://dl.pyroscope.io/release/pyroscope-0.0.10-source.tar.gz"
  sha256 "3925e70d26d9072cc7edddbaf20a196f6d749eaedcdd1f764995d422212c69e5"
  license "Apache-2.0"
  head "https://github.com/pyroscope-io/pyroscope.git", :branch => "main"

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "yarn" => :build
  depends_on "rust" => :build
  depends_on "zstd" => :build

  bottle do
    cellar :any_skip_relocation
    root_url "https://dl.pyroscope.io/homebrew"

    sha256 "906df309b11061cefe8b40a43f2dcadf7047fa1ede2e32ead84761def58785eb" => :catalina
    sha256 "5ae8f5a1380741cdd1d50e50fc9d8ce04f3727247a73eec595d4c7d35e9015d4" => :mojave
  end

  def install
    system "make build-rust-dependencies"
    system "make build-release"

    on_macos do
      bin.install "bin/pyroscope"
    end

    (etc/"pyroscope").mkpath
    etc.install "scripts/packages/server.yml" => "pyroscope/server.yml"
  end

  def post_install
    (var/"log/pyroscope").mkpath
    (var/"lib/pyroscope").mkpath
  end

  plist_options manual: "pyroscope server --config=#{HOMEBREW_PREFIX}/etc/pyroscope/server.yml"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <dict>
            <key>SuccessfulExit</key>
            <false/>
          </dict>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_bin}/pyroscope</string>
            <string>server</string>
            <string>--config</string>
            <string>#{etc}/pyroscope/server.yml</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}/lib/pyroscope</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/pyroscope/server-stderr.log</string>
          <key>StandardOutPath</key>
          <string>#{var}/log/pyroscope/server-stdout.log</string>
          <key>SoftResourceLimits</key>
          <dict>
            <key>NumberOfFiles</key>
            <integer>10240</integer>
          </dict>
        </dict>
      </plist>
    EOS
  end

  test do
    require "pty"
    require "timeout"

    # first test
    system bin/"pyroscope", "-v"

    # avoid stepping on anything that may be present in this directory
    tdir = File.join(Dir.pwd, "pyroscope-test")
    Dir.mkdir(tdir)

    r, w, pid = PTY.spawn(bin/"pyroscope", "-api-bind-addr :50100")

    listening = Timeout.timeout(10) do
      r.each.find { |l| l.match?(/starting HTTP server/) }
    end

    Process.kill("TERM", pid)
    w.close
    r.close
    listening
  end
end
