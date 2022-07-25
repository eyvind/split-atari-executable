#!/usr/bin/env ruby
# frozen_string_literal: true

MAX_SIZE = 8176
HEADER_SIZE = 4

##
# This class writes segments from an Atari binary load file into a
# sequence of binary load files, each no larger than MAX_SIZE bytes.
class OverlayWriter
  attr_reader :count

  def initialize(prefix)
    @prefix = prefix
    @count = 0
    @fh = nil
  end

  def self.open(prefix)
    handle = new(prefix)

    return handle unless block_given?

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
      # Avoid a split INITAD by forcing a new overlay file early if the
      # current segment is <= 4 bytes and won't fit in the current file.
      new_overlay unless room_for?(to_write <= 4 ? to_write : 1)
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

  def room_for
    @fh.nil? ? 0 : MAX_SIZE - @fh.pos - HEADER_SIZE
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
    puts "#{filename} is not an Atari DOS binary load file!"
    exit 1
  end
  OverlayWriter.open(prefix) do |of|
    count = 0
    loop do
      header = f.read(HEADER_SIZE)
      break if header.nil?

      start_addr, end_addr = header.unpack('S<S<')
      if start_addr == 0xffff
        start_addr = end_addr
        end_addr = f.read(2).unpack('S<')
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
