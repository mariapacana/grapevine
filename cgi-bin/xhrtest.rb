#!/usr/bin/env ruby
require "cgi"
require "sqlite3"
require "uri"
require "json"

=begin
drop table if exists games;
drop table if exists gamestoplayers;
drop table if exists pics;
drop table if exists players;

CREATE TABLE games (gameid integer primary key, turn integer);
CREATE TABLE gamestoplayers (gameid integer, playerid integer, turn integer, token integer);
CREATE TABLE pics (picid integer primary key, data blob, gameid integer, turn integer);
CREATE TABLE players (playerid integer primary key, email varchar(255), optedout integer);
=end

$cgi = CGI.new
$params = $cgi.params

def error(message) #broken; sends 200 rather than 400
	$cgi.out({"Status" => "400 Bad Request"}) { message }
	exit
end

def makenewgame(data, email)
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

def playturn(turn,email,game)
	db = SQLite3::Database.new("picdata.db")
	
	db.execute("insert into games (turn) values (?)", turn)
end

def main
	# cmd is 'new', 'showturn', 'playturn', 'view'
	email=[]
	
  if ($params["cmd"].empty?)
    error("missing cmd")
  end
  
	cmd = $params["cmd"][0]
	if (cmd == "new") 
		data = URI.unescape($params["data"][0]).to_s #changes &&s for instance
		email = $params["email"][0].split(",")
		for i in email do i.strip! end
		makenewgame(data, email)	
	elsif (cmd == "showturn") 
		error("you haven't made this yet")
	elsif (cmd == "playturn") 
		error("you haven't made this yet")
	else 
		error("or this")
	end
end

main

=begin
cgi.out() do 
	{ 'img' => data, 'arg2' => "kittens"}.to_json
end
=end

=begin
create table pics (
	picid integer primary key, 
	data blob);
=end

=begin
aFile = File.new("picdata.txt", "w")
aFile.write(data)
aFile.close
=end
