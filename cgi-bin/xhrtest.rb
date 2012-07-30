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
	turn= 1
	optedout = 0
	
	db.execute("insert into games (turn) values (?)", turn)
	gameid = db.last_insert_row_id().to_i

	db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
	
	for e in email do
		if db.execute("select * from players where email = ?",e).empty?
			db.execute("insert into players (email, optedout) values (?,?)", [e,optedout])
		end
	
		playerid = db.last_insert_row_id().to_i
		token = rand(10000)
		params = [gameid, playerid, turn, token]
		db.execute("insert into gamestoplayers (gameid, playerid, turn, token) values (?,?,?,?)", params) 
	end
end

def show(gameid,turn)
	db = SQLite3::Database.new("picdata.db")
	
	maxturns = db.execute("select count(*) from gamestoplayers where gameid=?",gameid)[0][0]
	
	#shows pics
	if (turn.odd?) && (turn < maxturns)
		picdata = db.execute("select data from pics where gameid = ? and turn = ?", [gameid,turn])[0][0]
		template_data = IO.read('cgi-bin/templates/picturn.html.erb')
  	template = ERB.new(template_data)
  elsif (turn.even?) && (turn < maxturns)
  #shows sentences
		sentence = db.execute("select sentence from sentences where gameid = ? and turn = ?", [gameid,turn])[0][0]
		template_data = IO.read('cgi-bin/templates/senturn.html.erb')
  	template = ERB.new(template_data)
  else
  	error("You need to write a function that shows all of the previous turns!")
  #show all previous ones
  end
  
  #need to actually show the template. : /
  $cgi.out() { template.result(binding) }
  
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
	
	if (cmd == "new") #Creates a new game
		data = URI.unescape($params["data"][0]).to_s #changes &&s for instance
		email = $params["email"][0].split(",")
		for i in email do i.strip! end
		new(data, email)	
	elsif (cmd == "show") #Shows the current turn
		gameid = URI.unescape($params["gameid"][0])
		turn = URI.unescape($params["turn"][0]).to_i
		show(gameid, turn) #include token later
	elsif (cmd == "sentence") #Updates database with a sentence
		sentence = URI.unescape($params["sentence"][0]).to_s
		gameid = URI.unescape($params["gameid"][0])
		turn = URI.unescape($params["turn"][0]).to_i+1
		savesentence(sentence,gameid,turn)
	elsif (cmd == "pic") #Updates database with a picture
		data = URI.unescape($params["data"][0]).to_s
		gameid = URI.unescape($params["gameid"][0])
		turn = URI.unescape($params["turn"][0]).to_i+1
		savepic(data,gameid,turn)
	end
end

main


