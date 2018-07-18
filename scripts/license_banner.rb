# Goes through each .h, .m, .swift and .js file and replaces the license banner with the correct version

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: license_banner.rb [options]'

  opts.on('-s', '--skip-write', 'Skips actually writing the files to disk') do |v|
    options[:skip_write] = v
  end

  opts.on('-p', '--print', 'Print all of the files that will be modified') do |v|
    options[:print] = v
  end
end.parse!

# The folders which to recursively check for source files
folders = %w[CanvasCore Frameworks Canvas Parent Teacher rn]
files = []

# Returns the correct banner based on the file
# Tests and Frameworks are Apache;
# App code and everything else is GPL.
# CanvasCore is considered app code and not framework.
def appropriate_banner(file, year)

    gpl_header = %q(//
// Copyright (C) %d-present Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//)

    apache_header = %q(//
// Copyright (C) %d-present Instructure, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//)

    gpl_header = gpl_header % year
    apache_header = apache_header % year

    return apache_header if file.start_with? "Frameworks"
    return apache_header if file.include? "Tests"
    return apache_header if file.include? 'test'
    return apache_header if file.include? '__tests__'
    return apache_header if file.include? 'modules/instructure-canvas-api'
    gpl_header
end

# If this test passes the file shouldn't be included in the search of files
def file_test(file)
    exceptions = [
      '.framework/Headers/',
      '.framework/Versions/',
      'CanvasKit1/External Sources/',
      'node_modules',
      'jquery'
    ]
    return false if exceptions.any? { |exception| file.include? exception}
    true
end

def gpl_banner_test(banner_text)
    banner_text.include? "GPL"
end

# Used to make sure there is the work "copyright" somewhere in the Header
# Doing this to be safe, so we don't replace other comments
copyright_regex = /(^|\r\n|\n|\r)[\/*#|\s]*Copyright\s+[^\s\r\n]+/i

# This regex is used to find and/or replace the first block comment in a file
license_banner_regex = /(^|\r\n|\n|\r)(?:\/\/[^\n\r]*(?:\r\n|\n|\r))*\/\/[^\n\r]*($|\r\n|\n|\r)/i

# Used to test whether the Instructure appears in a file
instructure_regex = /(^|\r\n|\n|\r)*Instructure/i

folders.each do |folder|
    Dir.glob("#{folder}/**/*.{swift,h,m,js}") do |file|
        files.push(file) if file_test(file)
    end
end

puts "Checking #{files.count} files..."
files_replaced = []
files_skipped = []
files_with_incompatible_license = []

files.each do |file|

    text = File.read(file)
    copyright_matches = text.match(copyright_regex)
    banner_matches = text.match(license_banner_regex)
    instructure_matches = text.match(instructure_regex)
    
    # Call git log for a file and only return when the commit was an Add (--diff-filter=A) and take the oldest one
    git_authored_year_command = "git log --diff-filter=A --follow --format=%ad --date=format:'%Y' -- \"" + file + "\" | tail -1"
    authored_year = `#{git_authored_year_command}`
    
    banner = appropriate_banner(file, authored_year)

    unless copyright_matches
        text.prepend("#{banner}\n\n")
        File.write(file, text) unless options[:skip_write]
        files_replaced.push(file)
        next
    end

    unless banner_matches
        files_skipped.push(file)
        next
    end

    unless instructure_matches
        is_gpl = gpl_banner_test(banner_matches[0])
        files_with_incompatible_license.push(file) if is_gpl
        files_skipped.push(file) unless is_gpl
        next
    end

    new_contents = text.sub(license_banner_regex, banner)
    if new_contents == text
        files_skipped.push(file)
        next
    end
    File.write(file, new_contents) unless options[:skip_write]
    files_replaced.push(file)
end

if options[:skip_write]
    puts "Files to be modified: #{files_replaced.count}"
    if options[:print]
        puts files_replaced.sort
    end
    puts "Files to be skipped: #{files_skipped.count}"
    if options[:print]
      puts files_skipped.sort
    end
    puts "\n\nFiles with incompatible liceneses: #{files_with_incompatible_license.count}"
    puts files_with_incompatible_license
else
    puts "Files modified: #{files_replaced.count}"
    if options[:print]
        puts files_replaced.sort
    end
    puts "Files skipped: #{files_skipped.count}"
    if options[:print]
      puts files_skipped.sort
    end
    puts "\n\nFiles with incompatible liceneses that were not replaced: #{files_with_incompatible_license.count}"
    puts files_with_incompatible_license
end
