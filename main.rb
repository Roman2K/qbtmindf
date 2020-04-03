require 'utils'

module Commands
  def self.cmd_check_min(mnt, min, block_size, qbt_url)
    log = Utils::Log.new
    min = min.to_f
    qbt = begin
      Utils::QBitTorrent.new URI(qbt_url)
    rescue => err
      Utils.is_unavail?(err) or raise
      log.debug "qBitTorrent HTTP API seems unavailable, aborting"
      exit 0
    end

    avail = Utils.df mnt, block_size
    is_lower = avail < min
    log.info "available (%d%s) %s minimum (%d%s)" \
      % [avail, block_size, is_lower ? "<" : ">=", min, block_size]

    if is_lower
      log.info "pausing downloading torrents"
      qbt.download_limit = 1024
      qbt.pause_downloading
    else
      log.info "resuming downloading torrents"
      qbt.download_limit = 0
      qbt.resume_downloading
    end
  end
end

if $0 == __FILE__
  require 'metacli'
  MetaCLI.new(ARGV).run Commands
end
