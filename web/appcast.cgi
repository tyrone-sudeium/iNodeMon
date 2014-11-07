#! /usr/bin/env ruby

PACKAGE = "iNodeMon"	# Used for User Agent, DMG

require 'cgi'

print "Content-Type: application/xml\r\n\r\n"

# Common header
puts <<EOH
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>#{PACKAGE} Appcast</title>
    <link>http://www.symonds.id.au/inodemon/appcast.cgi</link>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
EOH

$cgi = CGI.new

# Try to extract user version from User Agent
$user_version = "0.0"
if $cgi.user_agent and $cgi.user_agent =~ /^#{PACKAGE}\/([0-9.]+)/
  $user_version = $1
end

# Determine list of version numbers, in descending order
$versions = Dir["dist/*-desc"].map { |f|
  File.basename(f).sub(/-desc$/, '')
}.sort.reverse
$versions.pop while ($versions.size >= 2) and ($versions.last <= $user_version)

# Always require the latest version to have a release file!
while not $versions.empty?
  break if File.readable? "dist/#{PACKAGE}-#{$versions.first}.dmg"
  $versions.shift
end

# If no versions suitable, bail out
if $versions.empty?
  puts "  </channel>"
  puts "</rss>"
  exit
end

# Dump item header
puts <<EOIH
    <item>
      <title>Version #{$versions.first}</title>
      <description><![CDATA[
<div style="font-size: smaller;">
EOIH

# Dump each version's description
$versions.each do |version|
  puts "<h3>Changes in version #{version}</h3>"
  puts File.read("dist/#{version}-desc")
end

# Dump item footer
dmg = "dist/#{PACKAGE}-#{$versions.first}.dmg"
pubDate = File.mtime(dmg).strftime("%a, %d %b %Y %H:%M:%S %z")
length = File.size(dmg)
puts <<EOIH
</div>
    ]]></description>
    <pubDate>#{pubDate}</pubDate>
    <enclosure
      url="http://www.symonds.id.au/#{PACKAGE.downcase}/#{dmg}"
      sparkle:version="#{$versions.first}"
      sparkle:shortVersionString="#{$versions.first}"
      length="#{length}" type="application/octet-stream" />
    </item>
EOIH

# Common footer
puts <<EOF
  </channel>
</rss>
EOF

