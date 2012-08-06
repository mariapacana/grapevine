#!/usr/bin/env ruby
require "cgi"
require "sqlite3"
require "uri"
require "json"
require "erb"

=begin
drop table if exists games;
drop table if exists gamestoplayers;
drop table if exists pics;
drop table if exists players;

CREATE TABLE games (gameid integer primary key, turn integer);
CREATE TABLE gamestoplayers (gameid integer, playerid integer, turn integer, token integer);
CREATE TABLE pics (picid integer primary key, data blob, gameid integer, turn integer);
CREATE TABLE sentences (sentenceid integer primary key, sentence blob, gameid integer, turn integer);
CREATE TABLE players (playerid integer primary key, email varchar(255), optedout integer);
=end

$cgi = CGI.new
$params = $cgi.params

def error(message) #broken; sends 200 rather than 400
	$cgi.out({"Status" => "400 Bad Request"}) { message }
	exit
end

def new(data, email)
	db = SQLite3::Database.new("picdata.db")
	turn = 1
	optedout = 0
	
	db.execute("insert into games (turn) values (?)", turn)
	gameid = db.last_insert_row_id().to_i

	db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
	
	for e in email do
		playerid = nil
		r = db.execute("select playerid from players where email = ?",e)
		
		if !r.empty?
			playerid = r[0][0]
		else
			db.execute("insert into players (email, optedout) values (?,?)", [e,optedout])
			playerid = db.last_insert_row_id().to_i
		end
	
		token = rand(10000)
		params = [gameid, playerid, turn, token]
		db.execute("insert into gamestoplayers (gameid, playerid, turn, token) values (?,?,?,?)", params) 
		turn = turn + 1
	end
	
	gameid
end

def show(gameid,turn)
	db = SQLite3::Database.new("picdata.db")
	
	maxturns = db.execute("select count(*) from gamestoplayers where gameid=?",gameid)[0][0]+1
	
	#shows pics
	if turn.odd? && turn < maxturns
		picdata = db.execute("select data from pics where gameid = ? and turn = ?", [gameid,turn])[0][0]
		template_data = IO.read('cgi-bin/templates/picturn.html.erb')
  	template = ERB.new(template_data)
  elsif turn.even? && turn < maxturns
  #shows sentences
		sentence = db.execute("select sentence from sentences where gameid = ? and turn = ?", [gameid,turn])[0][0]
		template_data = IO.read('cgi-bin/templates/senturn.html.erb')
  	template = ERB.new(template_data)
  else
  #show all previous ones
  	allturns = []
  	picture = db.execute("select data from pics where gameid = ?", gameid)
  	sentence = db.execute("select sentence from sentences where gameid = ?", gameid)
  	
  	if maxturns.even? then
  		for i in 0..picture.size-1
  			allturns << picture[i][0]
  			allturns << sentence[i][0]
  		end
  	else
  		for i in 0..picture.size-2
  			allturns << picture[i][0]
  			allturns << sentence[i][0]
  		end
  		allturns << picture[picture.size-1][0]
  	end
  	template_data = IO.read('cgi-bin/templates/displayall.html.erb')
  	template = ERB.new(template_data)
  end

  $cgi.out() { template.result(binding) }
  
end

def send_email(gameid,turn)
	db = SQLite3::Database.new("picdata.db")
	maxturns = db.execute("select count(*) from gamestoplayers where gameid=?",gameid)[0][0]+1
	email_message = ''
	
  # look up game and turn to find next player and turn type
  # load appropriate template and fill in blanks
  # there will be 3 types of template (pic, sentence, final) & text & html versions.
  if turn.odd? && turn < maxturns
		currentplayerid = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]
		nextplayerid = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid,turn+1])[0][0]
		
		currentplayere = db.execute("select email from players where playerid = ?", currentplayerid)[0][0]
		nextplayere = db.execute("select email from players where playerid = ?", nextplayerid)[0][0]

		template_data = IO.read('cgi-bin/templates/picturnemail.txt.erb')
  	template = ERB.new(template_data)
  	email_message = template.result(binding)
  elsif turn.even? && turn < maxturns
  else
  end
  
  File.open('sentemail.txt', 'w') do |file|
  	file.puts email_message
  end
  
  # create tmail message
end

def savesentence(sentence,gameid,turn)
	db = SQLite3::Database.new("picdata.db")
	db.execute("insert into sentences (sentence, gameid, turn) values (?,?,?)", [sentence, gameid, turn]) 
	db.execute("update games set turn=? where gameid=gameid",turn)
end

def savepic(data,gameid,turn)
	db = SQLite3::Database.new("picdata.db")
	db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
	db.execute("update games set turn=? where gameid=gameid",turn)
end

def main
  if ($params["cmd"].empty?)
    error("missing cmd")
  end
	cmd = $params["cmd"][0]
	
	if (cmd == "new") # Creates a new game
		data = URI.unescape($params["data"][0]).to_s # changes &&s for instance
		
		if ($params["email"][0] == "") 
			error("Type a valid email address.")
		else
			email = $params["email"][0].split(",")
		end
		
		email.each {|i| i.strip! }
		gameid = new(data, email)	
		send_email(gameid, 1)
	elsif (cmd == "show") # Shows the current turn
		gameid = $params["gameid"][0]
		turn = $params["turn"][0].to_i
		show(gameid, turn) #INCLUDE TOKENS LATER
	elsif (cmd == "sentence") # Updates database with a sentence
		sentence = URI.unescape($params["sentence"][0]).to_s
		gameid = $params["gameid"][0]
		turn = $params["turn"][0].to_i+1
		savesentence(sentence,gameid,turn)
		send_email(gameid, turn)
	elsif (cmd == "pic") # Updates database with a picture
		data = URI.unescape($params["data"][0]).to_s
		gameid = $params["gameid"][0]
		turn = $params["turn"][0].to_i+1
		savepic(data,gameid,turn)
		send_email(gameid, turn)
	end
end

main


