#!/usr/bin/env ruby
require "cgi"
require "sqlite3"
require "uri"
require "json"
require "erb"
require "time"

=begin
drop table if exists games;
drop table if exists gamestoplayers;
drop table if exists pics;
drop table if exists players;
drop table if exists sentences;

CREATE TABLE games (gameid integer primary key, turn integer);
CREATE TABLE gamestoplayers (gameid integer, playerid integer, turn integer, token integer, time integer);
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

def new(data, email, sentence, time)
	db = SQLite3::Database.new("picdata.db")
	turn = 1
	optedout = 0
		
	db.execute("insert into games (turn) values (?)", turn)
	gameid = db.last_insert_row_id().to_i

	db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
	db.execute("insert into sentences (sentence, gameid, turn) values (?,?,?)", [sentence, gameid, turn]) 	
	
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
		
		if (turn == 1) then
			params = [gameid, playerid, turn, token, time]
			db.execute("insert into gamestoplayers (gameid, playerid, turn, token, time) values (?,?,?,?,?)", params) 
		else
			params = [gameid, playerid, turn, token]
			db.execute("insert into gamestoplayers (gameid, playerid, turn, token) values (?,?,?,?)", params) 
		end
		turn = turn + 1
	end
	
	gameid
end

def displayall(gameid,turn,token)
	db = SQLite3::Database.new("picdata.db")
	maxturns = db.execute("select count(*) from gamestoplayers where gameid=?",gameid)[0][0]
	correct_token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]
	
	if (turn == maxturns) 
		allturns = []

		picture = db.execute("select data from pics where gameid = ?", gameid)
		sentence = db.execute("select sentence from sentences where gameid = ?", gameid)
		player = db.execute("select email from players as p join gamestoplayers as g on p.playerid = g.playerid where gameid = ?", gameid).flatten
		
		#(0..player.size-1).each do |i|
		#	player[i]=player[i].gsub(/@.*/,'')
		#end
		
		for i in player
			i.gsub!(/@.*/,'')
		end
		
		(0...[picture.size, sentence.size].max).each do |i|
			allturns << picture[i] if i < picture.size
			allturns << sentence[i] if i < sentence.size
		end
		
		template_data = IO.read('cgi-bin/templates/displayall.html.erb')
		template = ERB.new(template_data)
	else
		template_data = IO.read('cgi-bin/templates/wrongtoken.html.erb')
		template = ERB.new(template_data)
	end

  $cgi.out() { template.result(binding) }
end

def show(gameid,turn,token)
	db = SQLite3::Database.new("picdata.db")
	correct_token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]
	
	if (token == correct_token)
		#shows sentences
		if turn.odd? #& turn < maxturns
			sentence = db.execute("select sentence from sentences where gameid = ? and turn = ?", [gameid,turn])[0][0]
			template_data = IO.read('cgi-bin/templates/senturn.html.erb')
			template = ERB.new(template_data)
		#shows pics
		else 
			picdata = db.execute("select data from pics where gameid = ? and turn = ?", [gameid,turn])[0][0]
			template_data = IO.read('cgi-bin/templates/picturn.html.erb')
			template = ERB.new(template_data)
		end
	else
		template_data = IO.read('cgi-bin/templates/wrongtoken.html.erb')
		template = ERB.new(template_data)
	end

  $cgi.out() { template.result(binding) }
  
end

def send_email(gameid,turn)
	db = SQLite3::Database.new("picdata.db")
	maxturns = db.execute("select count(*) from gamestoplayers where gameid=?",gameid)[0][0]
	email_message = ''
	
  # look up game and turn to find next player and turn type
  # load appropriate template and fill in blanks
  # there will be 3 types of template (pic, sentence, final) & text & html versions.
  if (turn == maxturns) 
    player_emails = []
  	player_ids = db.execute("select playerid from gamestoplayers where gameid = ?", gameid)
  	player_ids.each {|i| player_emails << db.execute("select email from players where playerid = ?",i[0])[0][0] }
  	token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,1])[0][0]

  	template_data = IO.read('cgi-bin/templates/displayallemail.txt.erb')
  	template = ERB.new(template_data)
  	email_message = template.result(binding)
  else
		currentplayer_id = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]
		nextplayer_id = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid,turn+1])[0][0]
		currentplayer_e = db.execute("select email from players where playerid = ?", currentplayer_id)[0][0]
		nextplayer_e = db.execute("select email from players where playerid = ?", nextplayer_id)[0][0]
		token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]

		if turn.odd?
			template_data = IO.read('cgi-bin/templates/senturnemail.txt.erb')
    else
			template_data = IO.read('cgi-bin/templates/picturnemail.txt.erb')
    end
    
    template = ERB.new(template_data)
  	email_message = template.result(binding)
  end
  
  File.open('sentemail.txt', 'w') do |file|
  	file.puts email_message
  end
  
  # create tmail message
end

def savesentence(sentence,gameid,turn,time)
	db = SQLite3::Database.new("picdata.db")
	db.execute("insert into sentences (sentence, gameid, turn) values (?,?,?)", [sentence, gameid, turn]) 
	db.execute("update gamestoplayers set time = ? where gameid = ? and turn = ?",[time,gameid,turn])
	db.execute("update games set turn=? where gameid=gameid",turn)
end

def savepic(data,gameid,turn,time)
	db = SQLite3::Database.new("picdata.db")
	db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
	db.execute("update gamestoplayers set time = ? where gameid = ? and turn = ?",[time,gameid,turn])
	db.execute("update games set turn=? where gameid=gameid",turn)
end

def main
  if ($params["cmd"].empty?)
    error("missing cmd")
  end
	cmd = $params["cmd"][0]
	
	if (cmd == "new") # Creates a new game
		data = URI.unescape($params["data"][0]).to_s # changes &&s for instance
		sentence = $params["sentence"][0]
		time = Time.now.to_i
		
		if ($params["email"][0] == "") 
			error("Type a valid email address.")
		else
			if ($params["email"][0].include? ",") 
				email = $params["email"][0].split(",")
			else
				email = $params["email"][0].split(" ")
			end
		end
		
		email.each {|i| i.strip! }
		gameid = new(data, email, sentence,time)	
		send_email(gameid, 1)
	elsif (cmd == "show") # Shows the current turn, but only to someone who has the token!
		gameid = $params["gameid"][0]
		turn = $params["turn"][0].to_i
		token = $params["token"][0].to_i
		show(gameid,turn,token) 
	elsif (cmd == "displayall") # Shows all turns
		gameid = $params["gameid"][0]
		turn = $params["turn"][0].to_i
		token = $params["token"][0].to_i
		displayall(gameid, turn, token) 
	elsif (cmd == "sentence") # Updates database with a sentence
		sentence = URI.unescape($params["sentence"][0]).to_s
		gameid = $params["gameid"][0]
		turn = $params["turn"][0].to_i+1
		time = Time.now.to_i
		savesentence(sentence,gameid,turn,time)
		send_email(gameid,turn)
	elsif (cmd == "pic") # Updates database with a picture
		data = URI.unescape($params["data"][0]).to_s
		gameid = $params["gameid"][0]
		turn = $params["turn"][0].to_i+1
		time = Time.now.to_i
		savepic(data,gameid,turn,time)
		send_email(gameid,turn)
	end
end

main


