#!@ruby@/bin/ruby
require 'fileutils'

if ARGV.length != 1
  warn "Usage: $0 <directory>"
  exit(false)
end

dir = ARGV[0]
success = true
now = Time.now.to_i
day_ago = now - 24 * 60 * 60

files = {
  'edge1_prg_vpsfree.gif' => "http://172.16.100.2/graphs/iface/sfp28-12-master/daily.gif",
  'edge2_prg_vpsfree.gif' => "http://172.16.100.3/graphs/iface/sfp28-12-master/daily.gif",
  'rtr1_brq_vpsfree.gif' => "http://172.19.0.2/graphs/iface/sfpplus1-master/daily.gif",
  'rtr2_brq_vpsfree.gif' => "http://172.19.0.3/graphs/iface/sfpplus1-master/daily.gif"
}

FileUtils.mkdir_p(dir)

files.each do |name, url|
  dst = File.join(dir, name)
  dst_tmp = "#{dst}.new"

  if Kernel.system('curl', '-s', '-o', dst_tmp, url)
    File.rename(dst_tmp, dst)
  else
    warn "Unable to fetch graph #{name} from #{url}"
    success = false
  end
end

exit(success)
