#!/usr/bin/env ruby
# frozen_string_literal: true

##
# This class writes Atari DOS file segments into files no larger
# than 8192 bytes while still preserving the object file format.
class OverlayWriter
  MAX_SIZE = 8192

  attr_reader :count

  def initialize(prefix)
    @prefix = prefix
    @count = 0
    @fh = nil
  end

  def self.open(prefix)
    handle = new(prefix)

    begin
      yield handle
    ensure
      begin
        handle.close
      rescue StandardError
        # pass
      end
    end
  end

  def write(start_addr, end_addr, stream)
    while start_addr <= end_addr
      to_write = end_addr - start_addr + 1
      new_overlay unless room_for?(to_write > 4 ? 1 : to_write)
      len = room_for?(to_write) ? to_write : room_for
      write_segment(start_addr, start_addr + len - 1, stream.read(len))
      start_addr += len
    end
  end

  def close
    @fh&.close
  end

  private

  def new_overlay
    close
    filename = "#{@prefix}#{@count}.ovl"
    @count += 1
    @fh = File.open(filename, 'wb')
    @fh.write([0xffff].pack('S<'))
  end

  def room_for?(size)
    size <= room_for
  end

  ##
  # Calculate how much room is left in the file minus a segment header.
  def room_for
    @fh.nil? ? 0 : MAX_SIZE - @fh.pos - 4
  end

  def write_segment(start_addr, end_addr, data)
    @fh.write([start_addr, end_addr].pack('S<S<'))
    @fh.write(data)
  end
end

def usage
  puts "Usage: #{$PROGRAM_NAME} input_file [output_prefix]"
  exit 1
end

usage if ARGV.empty? || ARGV.length > 2

filename = ARGV[0]
prefix = ARGV[1] || filename.chomp(File.extname(filename))

File.open(filename, 'rb') do |f|
  if f.read(2).unpack('S<') != [0xffff]
    puts 'Not an Atari DOS object file!'
    exit 1
  end
  OverlayWriter.open(prefix) do |of|
    count = 0
    loop do
      header = f.read(4)
      break if header.nil?

      start_addr, end_addr = header.unpack('S<S<')
      if start_addr == 0xffff
        start_addr = end_addr
        end_addr = header.unpack('S<')
      end
      count += 1
      puts "Segment #{count}: " \
        "$#{start_addr.to_s(16).rjust(4, '0')}-" \
        "$#{end_addr.to_s(16).rjust(4, '0')}"
      of.write(start_addr, end_addr, f)
    end
    puts "Wrote #{count} segments into #{of.count} overlay files."
  end
end
