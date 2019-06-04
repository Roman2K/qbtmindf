require 'qbittorrent'

module Commands
  def self.cmd_check_min(mnt, min, block_size, qbt_url)
    min = min.to_f
    qbt = begin
      Timeout.timeout 2 do
        QBitTorrent.new URI(qbt_url)
      end
    rescue Timeout::Error
      $stderr.puts " WARN qBitTorrent HTTP API seems unavailable, aborting"
      exit 0
    end
    avail = df mnt, block_size

    is_lower = avail < min
    $stderr.puts " INFO available (%d%s) %s minimum (%d%s)" \
      % [avail, block_size, is_lower ? "<" : ">=", min, block_size]

    if is_lower
      $stderr.puts " INFO pausing downloading torrents"
      qbt.download_limit = 1024
      qbt.pause_downloading
    else
      $stderr.puts " INFO resuming downloading torrents"
      qbt.download_limit = 0
      qbt.resume_downloading
    end
  end

  def self.df(path, block_size)
    IO.popen(["df", "-B#{block_size}", path], &:read).
      tap { $?.success? or raise "df failed" }.
      split("\n").
      tap { |ls| ls.size == 2 or raise "unexpected number of lines" }.
      fetch(1).
      split(/\s+/).
      fetch(-3).
      chomp(block_size).to_f
  end
end

if $0 == __FILE__
  require 'metacli'
  MetaCLI.new(ARGV).run Commands
end
