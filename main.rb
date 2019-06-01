require 'net/http'
require 'json'

def df(path, block_size)
  IO.popen(["df", "-B#{block_size}", path], &:read).
    tap { $?.success? or raise "df failed" }.
    split("\n").
    tap { |ls| ls.size == 2 or raise "unexpected number of lines" }.
    fetch(1).
    split(/\s+/).
    fetch(-3).
    chomp(block_size).to_f
end

class QbtClient
  def initialize(uri)
    user, password = uri.user, uri.password
    @uri = uri.dup.tap { |u| u.user = u.password = nil }.freeze
    set_cookie! user, password
  end

  def download_limit=(n)
    $stderr.puts "setting download limit to: %d bytes" % n
    post! "/command/setGlobalDlLimit", {'limit' => n.to_s}
  end

  def pause_downloading
    downloading.each { |t| pause t unless t.fetch("state") == "pausedDL" }
  end

  def resume_downloading
    downloading.each { |t| resume t if t.fetch("state") == "pausedDL" }
  end

  private def downloading
    JSON.parse get! "/query/torrents?filter=downloading"
  end

  private def pause(t)
    $stderr.puts "pausing torrent: %s" % t.fetch("name")
    hash_request! "/command/pause", t
  end

  private def resume(t)
    $stderr.puts "resuming torrent: %s" % t.fetch("name")
    hash_request! "/command/resume", t
  end

  private def hash_request!(path, t)
    post! path, 'hash' => t.fetch("hash")
  end

  private def get!(path)
    request!(new_req :Get, path).body
  end

  private def post!(path, data)
    req = new_req :Post, path
    req.form_data = data
    request! req
  end

  private def set_cookie!(user, password)
    req = new_req :Post, "/login"
    req.form_data = {'username' => user, 'password' => password}

    @cookie = request!(req)['set-cookie'].
      tap { |s| s or raise "failed login: %s" % res.body }.
      split(";", 2).
      fetch(0)
  end

  private def new_req(type, path, *args, &block)
    Net::HTTP.const_get(type).new(add_uri(path), *args, &block).tap do |req|
      req['Referer'] = @uri.to_s
      req['Cookie'] = @cookie
    end
  end

  private def add_uri(path)
    b = URI path
    build_uri do |a|
      a.path += b.path
      a.query = [a.query, b.query].compact * "&"
    end
  end

  private def build_uri(&block)
    @uri.dup.tap &block
  end

  private def request(*args, &block)
    Net::HTTP.
      start(@uri.host, @uri.port, use_ssl: @uri.scheme == 'https') do |http|
        http.request *args, &block
      end
  end

  private def request!(*args, &block)
    request(*args, &block).tap do |res|
      res.kind_of? Net::HTTPSuccess or raise "unpexpected response: %p" % res
    end
  end
end

module Commands
  def self.cmd_check_min(mnt, min, block_size, qbt_url)
    min = min.to_f
    avail = df mnt, block_size
    qbt = QbtClient.new URI(qbt_url)
    is_lower = avail < min
    $stderr.puts "available (%d%s) %s minimum (%d%s)" \
      % [avail, block_size, is_lower ? "<" : ">=", min, block_size]
    if is_lower
      $stderr.puts "pausing downloading torrents"
      qbt.download_limit = 1024
      qbt.pause_downloading
    else
      $stderr.puts "resuming downloading torrents"
      qbt.download_limit = 0
      qbt.resume_downloading
    end
  end
end

if $0 == __FILE__
  require 'metacli'
  MetaCLI.new(ARGV).run Commands
end
