require 'yaml'
require 'net/imap'
require 'mail'
require 'nokogiri'

class LocationList < Array
  def filter(title, &block)
    puts "Filter: #{title}"
    select! { |d| block.call(d) }
    puts "Location list: #{length}"
  end
end

creds = YAML.load_file('creds.yaml')

#Net::IMAP::debug = true

imap = Net::IMAP.new('imap.gmail.com', port: 993, ssl: true)
imap.login(creds['username'], creds['password'])
imap.examine('INBOX')

class Location
  attr_reader :dist, :street, :size, :room, :furn, :info, :caut, :price, :phone
  def initialize(dist, street, size, room, furn, info, caut, price, phone)
    @dist = dist
    @street = street
    @size = size
    @room = room
    @furn = furn
    @info = info
    @caut = caut
    @price = price
    @phone = phone
  end

  def quickstat
    "%-25s | %-12s | %-15s | %s" % [
      "#{@dist} #{@street}",
      "Size: #{@size}m2",
      "Rooms: #{@room}",
      "#{@price} with x#{@caut}"
    ]
  end
end

locations = LocationList.new

imap.search(['ALL']).each do |message_id|
  message = imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
  if message.from[0].mailbox == "mb.ingatlan.szabados"
    m = Mail.new(imap.fetch(message_id, "BODY.PEEK[]")[0].attr['BODY[]'])
    doc = Nokogiri::HTML(m.body.parts[1].decoded)
    rows = doc.xpath('//tr')
    rows.each do |row|
      loc = Location.new(
        row.children[1].content,
        row.children[3].content,
        row.children[5].content,
        row.children[7].content,
        row.children[9].content,
        row.children[11].content,
        row.children[13].content,
        row.children[15].content,
        row.children[17].content
      )
      locations << loc
    end
  end
end

imap.logout
imap.disconnect

puts "Full location list: #{locations.length}"

locations.filter('only Budapest')    { |l| l.dist != '' }
locations.filter('only 1< rooms')    { |l| l.room != '1' }
locations.filter('only 50nm<= size') { |l| l.size.to_i >= 50 }

locations.each do |loc|
  puts loc.quickstat
  puts "\t#{loc.info}"
  puts "\t#{loc.phone}"
end
