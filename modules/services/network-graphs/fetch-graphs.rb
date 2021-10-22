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
  'edge2_prg_vpsfree.png' => "http://172.16.4.4/graph.php?to=#{now}&id=62&type=port_bits&from=#{day_ago}&height=250&width=550",
  'rtr1_brq_vpsfree.gif' => "http://172.19.0.2/graphs/iface/sfpplus1-master/daily.gif",
}

FileUtils.mkdir_p(dir)

files.each do |name, url|
  dst = File.join(dir, name)
  dst_tmp = "#{dst}.new"

  unless Kernel.system('curl', '-s', '-o', dst_tmp, url)
    success = false
  end

  File.rename(dst_tmp, dst)
end

exit(success)
