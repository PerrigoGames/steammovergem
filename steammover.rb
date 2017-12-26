require 'trollop'

#################################################################
# Define command line arguments
#################################################################
@opts = Trollop::options do
	opt :unmoved, "List the files that exist in local, but not remote", :short => 'm'
	opt :unlinked, "List the files that exist in remote, but not local", :short => 'l'
	opt :linked, "List the files that exist in both remote and local"
	opt :all_to_remote, "Moves all directories from local to remote"
	opt :all_to_local, "Moves all directories from remote to local"
	opt :relink, "Creates links in local for games that exist only in remote", :short => 'r'
	opt :fuzzy, "Games will be moved if they contain (not only match) the supplied game names", :short => 'f'
end
@sourcedir = "c:\\program files (x86)\\steam\\steamapps\\common"
@destdir = "D:\\Steam\\steamapps\\common"

#################################################################
# Generate lists of games at local and remote for later use
#################################################################
def games_at(location, validate=false)
	return Dir.entries(location).select do |entry| 
		valid?("#{location}\\#{entry}")
	end if validate
	Dir.entries(location)
end

def valid?(path)
	File.directory?(path)
end

# games that exist in local but not remote
@unmoved = games_at(@sourcedir) - games_at(@destdir)
# games that exist in remote but not local
@unlinked = games_at(@destdir) - games_at(@sourcedir)
# games that exist in both local and remote
@linked = games_at(@sourcedir, true) & games_at(@destdir)

#################################################################
# Movement Methods
#################################################################
def move_to_remote(game)
	if game.class == Array
		game.each { |entry| move_to_remote entry }
	end
	puts "Moving #{game} to remote..."
	`xcopy /E /V /I /F /Y "#{@sourcedir}\\#{game}" "#{@destdir}\\#{game}"`
	`cmd /C rd /S /Q "#{@sourcedir}\\#{game}"`
	relink game
end

def move_to_local(game)
	if (game.class == Array)
		game.each { |entry| move_to_local entry }
	end
	puts "Moving #{game} to local..."
	`cmd /C rd "#{@sourcedir}\\#{game}"`
	`xcopy /E /V /I /F /Y "#{@destdir}\\#{game}" "#{@sourcedir}\\#{game}"`
	`cmd /C rd /S /Q "#{@destdir}\\#{game}"`
end

def relink(game)
	puts "Linking #{game}..."
	`cmd /C mklink /J "#{@sourcedir}\\#{game}" "#{@destdir}\\#{game}"`
end

def smarter_move(game) # smarter than nothing
	if @unmoved.include?(game)
		move_to_remote game
	elsif @linked.include?(game)
		move_to_local game
	end
end

#################################################################
# Command Line Argument Parser
#################################################################
def parse_opts
	if @opts[:unmoved]
		puts "Unmoved directories: (#{@unmoved.count})"
		@unmoved.each { |file| puts "    #{file}" }
	end
	if @opts[:unlinked]
		puts "Unlinked directories: (#{@unlinked.count})"
		@unlinked.each { |file| puts "    #{file}" }
	end
	if @opts[:linked]
		puts "Linked directories: (#{@linked.count})"
		@linked.each { |file| puts "    #{file}" }
	end
	if @opts[:all_to_remote]
		if @unmoved.count > 50
			puts "WARNING: moving more than 50 games (#{@unmoved.count}), continue?"
			return unless gets.chomp.include? 'y'
		end
		puts "Moving all local games to remote (#{@unmoved.count})"
		@unmoved.each do |file|
			move_to_remote file
		end
	end
	if @opts[:all_to_local]
		if @linked.count > 50
			puts "WARNING: moving more than 50 games (#{@linked.count}), continue?"
			return unless gets.chomp.include? 'y'
		end
		puts "Moving all remote games to local (#{@linked.count})"
		@linked.each do |file|
			move_to_local file
		end
	end
	if @opts[:relink]
		puts "Relinking..."
		@linked.each do |file|
			path = "#{@sourcedir}\\#{file}"
			unless valid?(path)
				puts "Removing invalid link at #{path}"
				`cmd /C rd "#{path}"`
			end
			relink file unless File.exist? path
		end
	end
end

#################################################################
# Main Script
#################################################################
parse_opts
games = ARGV
if @opts[:fuzzy]
	games.each do |game|
		@unlinked.each do |srcgame|
			smarter_move srcgame if srcgame.include?(game)
		end
	end
else
	games.each do |game|
		smarter_move game
	end
end