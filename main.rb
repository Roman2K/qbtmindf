require 'utils'

class Commands
  def initialize(log:)
    @log = log
  end

  def cmd_check_min(mnt, min, block_size, qbt_url)
    min = min.to_f
    qbt = begin
      Utils::QBitTorrent.new URI(qbt_url), log: @log
    rescue => err
      Utils.is_unavail?(err) or raise
      @log.debug "qBitTorrent HTTP API seems unavailable, aborting"
      exit 0
    end

    avail = Utils.df mnt, block_size
    is_lower = avail < min
    @log.info "available (%d%s) %s minimum (%d%s)" \
      % [avail, block_size, is_lower ? "<" : ">=", min, block_size]

    if is_lower
      @log.info "pausing downloading torrents"
      qbt.pause_downloading
    else
      @log.info "resuming downloading torrents"
      qbt.resume_downloading
    end
  end
end

if $0 == __FILE__
  require 'metacli'
  log = Utils::Log.new level: ENV["DEBUG"] == "1" ? :debug : :info
  MetaCLI.new(ARGV).run Commands.new(log: log)
end
